import 'package:flutter/material.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ticket_pos_barra.dart';
import '../models/comanda_model.dart';
import '../services/comandas_service.dart';
import '../widgets/mesas_abiertas_widget.dart';

/// Pantalla táctil de gestión de comandas de barra:
/// - Despacho por rondas a cuenta abierta (botón DESPACHAR con ticket térmico POS)
/// - Widget de Mesas / Cuentas Abiertas para seguimiento continuo
/// - Botón REGISTRAR para cobrar y liquidar la comanda al finalizar el cliente
class NuevaComandaScreen extends StatefulWidget {
  final Comanda? comandaInicial;
  final VoidCallback? onComandaDespachada;

  const NuevaComandaScreen({
    super.key,
    this.comandaInicial,
    this.onComandaDespachada,
  });

  @override
  State<NuevaComandaScreen> createState() => _NuevaComandaScreenState();
}

class _NuevaComandaScreenState extends State<NuevaComandaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ComandasService();

  // Controladores de formulario
  final _clienteController = TextEditingController();
  final _mesaController = TextEditingController(text: 'BARRA');
  final _meseroController = TextEditingController(text: 'ILARIO MEDINA');
  final _notasController = TextEditingController();

  // Estado del catálogo y carrito
  List<ProductoBarra> _productos = [];
  bool _cargandoProductos = true;
  String _categoriaSeleccionada = 'Todas';

  // Carrito de compras de la ronda actual: productoId -> { 'producto': ProductoBarra, 'cantidad': double }
  final Map<String, Map<String, dynamic>> _carrito = {};
  bool _enviando = false;

  // Estado de Cuentas / Mesas Abiertas
  List<Comanda> _mesasAbiertas = [];
  Comanda? _comandaAbiertaSeleccionada;
  bool _cargandoMesas = false;

  final List<String> _categorias = [
    'Todas',
    'Cocteles',
    'Sin Alcohol & Jugos',
    'Licores & Destilados',
    'Cervezas',
    'Ofertas & Servicios',
  ];

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _cargarMesasAbiertas();
    if (widget.comandaInicial != null) {
      _seleccionarMesaAbierta(widget.comandaInicial!);
    }
  }

  @override
  void didUpdateWidget(NuevaComandaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.comandaInicial != oldWidget.comandaInicial &&
        widget.comandaInicial != null) {
      _seleccionarMesaAbierta(widget.comandaInicial!);
    }
  }

  @override
  void dispose() {
    _clienteController.dispose();
    _mesaController.dispose();
    _meseroController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _cargarProductos() async {
    setState(() => _cargandoProductos = true);
    try {
      final list = await _service.getProductosBarra();
      if (mounted) {
        setState(() {
          _productos = list;
          _cargandoProductos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoProductos = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar catálogo de productos: $e'),
            backgroundColor: AppTheme.errorCoral,
          ),
        );
      }
    }
  }

  Future<void> _cargarMesasAbiertas() async {
    setState(() => _cargandoMesas = true);
    try {
      final sedeId = await SupabaseConfig.getSedePrincipalId();
      final list = await _service.getComandasAbiertas(sedeId: sedeId);
      if (mounted) {
        setState(() {
          _mesasAbiertas = list;
          _cargandoMesas = false;
          // Si había una comanda seleccionada, actualizar sus datos del servidor
          if (_comandaAbiertaSeleccionada != null) {
            final match = list
                .where((c) => c.id == _comandaAbiertaSeleccionada!.id)
                .firstOrNull;
            _comandaAbiertaSeleccionada = match;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoMesas = false);
      }
    }
  }

  void _seleccionarMesaAbierta(Comanda cmd) {
    setState(() {
      _comandaAbiertaSeleccionada = cmd;
      _clienteController.text = cmd.nombreCliente;
      _mesaController.text = cmd.mesa;
      _meseroController.text = cmd.mesero;
      _notasController.clear();
      _carrito.clear();
    });
  }

  void _iniciarNuevaCuenta() {
    setState(() {
      _comandaAbiertaSeleccionada = null;
      _clienteController.clear();
      _mesaController.text = 'BARRA';
      _meseroController.text = 'ILARIO MEDINA';
      _notasController.clear();
      _carrito.clear();
    });
  }

  double get _totalRondaActual {
    double total = 0.0;
    for (final item in _carrito.values) {
      final ProductoBarra prod = item['producto'] as ProductoBarra;
      final double cant = (item['cantidad'] as num).toDouble();
      total += (cant * prod.precioVenta);
    }
    return total;
  }

  double get _totalAcumuladoCuenta {
    final base = _comandaAbiertaSeleccionada?.precioTotal ?? 0.0;
    return base + _totalRondaActual;
  }

  int get _proximaRonda {
    if (_comandaAbiertaSeleccionada != null) {
      return _comandaAbiertaSeleccionada!.ronda + 1;
    }
    return 1;
  }

  void _agregarOIncrementar(ProductoBarra prod) {
    setState(() {
      if (_carrito.containsKey(prod.id)) {
        _carrito[prod.id]!['cantidad'] =
            (_carrito[prod.id]!['cantidad'] as double) + 1.0;
      } else {
        _carrito[prod.id] = {'producto': prod, 'cantidad': 1.0};
      }
    });
  }

  void _decrementar(String prodId) {
    setState(() {
      if (_carrito.containsKey(prodId)) {
        final cantActual = _carrito[prodId]!['cantidad'] as double;
        if (cantActual > 1.0) {
          _carrito[prodId]!['cantidad'] = cantActual - 1.0;
        } else {
          _carrito.remove(prodId);
        }
      }
    });
  }

  /// Acción principal: DESPACHAR RONDA A CUENTA ABIERTA
  /// Descuenta de inmediato insumos de la ronda e imprime ticket térmico con QR.
  Future<void> _despacharRonda() async {
    if (!_formKey.currentState!.validate()) return;

    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debe agregar al menos un producto a la ronda para despachar',
          ),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      final clienteNombre = _clienteController.text.trim();
      final mesaNombre = _mesaController.text.trim().isEmpty
          ? 'BARRA'
          : _mesaController.text.trim();
      final meseroNombre = _meseroController.text.trim().isEmpty
          ? 'ILARIO MEDINA'
          : _meseroController.text.trim();
      final notasComanda = _notasController.text.trim();
      final sedeId = await SupabaseConfig.getSedePrincipalId();

      final List<Map<String, dynamic>> itemsPayload = _carrito.values.map((it) {
        final ProductoBarra p = it['producto'] as ProductoBarra;
        final double cant = (it['cantidad'] as num).toDouble();
        return {
          'producto_barra_id': p.id,
          'cantidad': cant,
          'precio_unitario': p.precioVenta,
        };
      }).toList();

      final List<TicketItemData> itemsTicket = _carrito.values.map((it) {
        final ProductoBarra p = it['producto'] as ProductoBarra;
        final double cant = (it['cantidad'] as num).toDouble();
        return TicketItemData(
          cantidad: cant,
          nombreProducto: p.nombre,
          precioUnitario: p.precioVenta,
        );
      }).toList();

      final resultado = await _service.despacharRonda(
        comandaId: _comandaAbiertaSeleccionada?.id,
        nombreCliente: clienteNombre,
        mesa: mesaNombre,
        mesero: meseroNombre,
        sedeId: sedeId,
        items: itemsPayload,
        notas: notasComanda.isEmpty ? null : notasComanda,
      );

      final comandaId = resultado['comanda_id']?.toString() ?? '';
      final numeroTicket =
          resultado['numero_ticket']?.toString() ??
          (comandaId.length >= 8
              ? comandaId.substring(0, 8).toUpperCase()
              : 'BARRA');
      final rondaNumero =
          (resultado['ronda'] as num?)?.toInt() ?? _proximaRonda;

      // Imprimir el ticket térmico con el formato de la imagen adjunta
      final ticketData = TicketPosData(
        ordenArea: mesaNombre,
        cliente: clienteNombre,
        mesero: meseroNombre,
        fecha: DateTime.now(),
        ronda: rondaNumero,
        numeroOrden: numeroTicket,
        items: itemsTicket,
        notasCoordinacion: notasComanda.isEmpty ? null : notasComanda,
      );

      await TicketPosBarra.imprimirTicket(ticketData);

      // Recargar mesas abiertas y actualizar comanda activa
      await _cargarMesasAbiertas();

      if (mounted) {
        setState(() {
          _carrito.clear();
          _notasController.clear();
          // Mantener la mesa abierta seleccionada para siguientes rondas
          _comandaAbiertaSeleccionada = _mesasAbiertas
              .where((c) => c.id == comandaId)
              .firstOrNull;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Ronda $rondaNumero despachada a cuenta de $clienteNombre! Ticket: $numeroTicket',
            ),
            backgroundColor: AppTheme.successMint,
            action: SnackBarAction(
              label: 'REIMPRIMIR',
              textColor: AppTheme.background,
              onPressed: () => TicketPosBarra.imprimirTicket(ticketData),
            ),
          ),
        );

        if (widget.onComandaDespachada != null) {
          widget.onComandaDespachada!();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al despachar ronda: $e'),
            backgroundColor: AppTheme.errorCoral,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  /// Acción secundaria: REGISTRAR Y CERRAR CUENTA ABIERTA
  /// Se ejecuta cuando el cliente solicita la cuenta final para pagar antes de retirarse.
  Future<void> _cerrarComandaFinal() async {
    if (_comandaAbiertaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione una mesa abierta para registrar su cierre'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
      return;
    }

    final cmd = _comandaAbiertaSeleccionada!;
    String metodoSeleccionado = 'EFECTIVO_USD';

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppTheme.primaryAmber,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text('Registrar Comanda de ${cmd.nombreCliente}'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mesa: ${cmd.mesa.toUpperCase()} • Rondas servidas: ${cmd.ronda}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL A CANCELAR:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '\$${cmd.precioTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryAmber,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Método de Pago:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: metodoSeleccionado,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'EFECTIVO_USD',
                    child: Text('Efectivo USD (\$)'),
                  ),
                  DropdownMenuItem(
                    value: 'PAGO_MOVIL_BS',
                    child: Text('Pago Móvil (Bs.)'),
                  ),
                  DropdownMenuItem(
                    value: 'PUNTO_VENTA',
                    child: Text('Punto de Venta'),
                  ),
                  DropdownMenuItem(
                    value: 'TRANSFERENCIA',
                    child: Text('Transferencia'),
                  ),
                  DropdownMenuItem(value: 'MIXTO', child: Text('Pago Mixto')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() => metodoSeleccionado = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Volver'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successMint,
                foregroundColor: AppTheme.background,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text(
                'REGISTRAR Y CERRAR',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true) return;

    setState(() => _enviando = true);

    try {
      await _service.cerrarComandaAbierta(
        comandaId: cmd.id,
        metodoPago: metodoSeleccionado,
      );

      // Imprimir ticket de cuenta final consolidada
      final todosLosItems = cmd.detalles.map((d) {
        return TicketItemData(
          cantidad: d.cantidad,
          nombreProducto: d.nombreProducto,
          precioUnitario: d.precioUnitario,
        );
      }).toList();

      final ticketFinal = TicketPosData(
        ordenArea: cmd.mesa,
        cliente: cmd.nombreCliente,
        mesero: cmd.mesero,
        fecha: DateTime.now(),
        ronda: cmd.ronda,
        numeroOrden: cmd.numeroTicket ?? cmd.id.substring(0, 8).toUpperCase(),
        items: todosLosItems,
        notasCoordinacion: 'CUENTA CANCELADA EN $metodoSeleccionado',
        total: cmd.precioTotal,
      );

      await TicketPosBarra.imprimirTicket(ticketFinal);

      await _cargarMesasAbiertas();

      if (mounted) {
        _iniciarNuevaCuenta();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Comanda de ${cmd.nombreCliente} registrada y liquidada con éxito por \$${cmd.precioTotal.toStringAsFixed(2)}!',
            ),
            backgroundColor: AppTheme.successMint,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar comanda: $e'),
            backgroundColor: AppTheme.errorCoral,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productosFiltrados = _categoriaSeleccionada == 'Todas'
        ? _productos
        : _productos
              .where((p) => p.categoria == _categoriaSeleccionada)
              .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _comandaAbiertaSeleccionada != null
              ? 'Mesa: ${_comandaAbiertaSeleccionada!.mesa.toUpperCase()} [Ronda $_proximaRonda]'
              : 'Nueva Comanda',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar catálogo y mesas',
            onPressed: () {
              _cargarProductos();
              _cargarMesasAbiertas();
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Iniciar nueva cuenta',
            onPressed: _iniciarNuevaCuenta,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 850;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna izquierda: Mesas Abiertas + Formulario + Catálogo
                Expanded(
                  flex: 6,
                  child: _buildCatalogoYFormulario(productosFiltrados),
                ),
                const VerticalDivider(width: 1),
                // Columna derecha: Resumen de Rondas Anteriores + Carrito Actual + Botones
                Expanded(flex: 4, child: _buildResumenCarrito(isWide: true)),
              ],
            );
          } else {
            return Column(
              children: [
                Expanded(child: _buildCatalogoYFormulario(productosFiltrados)),
                _buildBarraInferiorMovil(),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildCatalogoYFormulario(List<ProductoBarra> productos) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(14.0),
        children: [
          // 1. WIDGET DE MESAS ABIERTAS
          MesasAbiertasWidget(
            comandasAbiertas: _mesasAbiertas,
            comandaSeleccionada: _comandaAbiertaSeleccionada,
            isLoading: _cargandoMesas,
            onSelectComanda: _seleccionarMesaAbierta,
            onNuevaComanda: _iniciarNuevaCuenta,
            onRecargar: _cargarMesasAbiertas,
          ),

          // 2. INDICADOR DE CUENTA ACTIVA SI EXISTE
          if (_comandaAbiertaSeleccionada != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryAmber),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_note,
                    color: AppTheme.primaryAmber,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CUENTA ABIERTA: ${_comandaAbiertaSeleccionada!.nombreCliente.toUpperCase()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.primaryAmber,
                          ),
                        ),
                        Text(
                          'Mesa: ${_comandaAbiertaSeleccionada!.mesa} • Despachadas: ${_comandaAbiertaSeleccionada!.ronda} rondas • Total Acumulado: \$${_comandaAbiertaSeleccionada!.precioTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppTheme.textMuted,
                    ),
                    tooltip: 'Deseleccionar mesa',
                    onPressed: _iniciarNuevaCuenta,
                  ),
                ],
              ),
            ),

          // 3. DATOS DE LA COMANDA (CLIENTE, MESA, MESERO)
          Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DATOS DE LA ORDEN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryAmber,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryCyan.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Ronda a Despachar: $_proximaRonda',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryCyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _clienteController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Cliente *',
                      hintText: 'Ej. Jesus Ríos',
                      prefixIcon: Icon(
                        Icons.person,
                        color: AppTheme.primaryAmber,
                        size: 20,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Ingrese el nombre del cliente';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _mesaController,
                          decoration: const InputDecoration(
                            labelText: 'Mesa / Área',
                            hintText: 'BARRA / Mesa 1',
                            prefixIcon: Icon(
                              Icons.table_bar,
                              color: AppTheme.secondaryCyan,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _meseroController,
                          decoration: const InputDecoration(
                            labelText: 'Mesero / Bartender',
                            hintText: 'ILARIO MEDINA',
                            prefixIcon: Icon(
                              Icons.badge_outlined,
                              color: AppTheme.secondaryCyan,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _notasController,
                    decoration: const InputDecoration(
                      labelText: 'Coordinación con otras áreas / Notas',
                      hintText: 'Ej. 2X PIZZA TRADICIONAL >> Para llevar',
                      prefixIcon: Icon(
                        Icons.notes,
                        color: AppTheme.textMuted,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. SELECTOR DE CATEGORÍA
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categorias.map((cat) {
                final isSelected = _categoriaSeleccionada == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryAmber,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppTheme.background
                          : AppTheme.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _categoriaSeleccionada = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // 5. GRILLA DE PRODUCTOS TÁCTILES
          if (_cargandoProductos)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (productos.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text(
                'No hay productos registrados en esta categoría',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisExtent: 100,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: productos.length,
              itemBuilder: (context, index) {
                final p = productos[index];
                final cantEnCarrito =
                    _carrito[p.id]?['cantidad'] as double? ?? 0.0;

                return InkWell(
                  onTap: () => _agregarOIncrementar(p),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cantEnCarrito > 0
                          ? AppTheme.surfaceHighlight
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cantEnCarrito > 0
                            ? AppTheme.primaryAmber
                            : AppTheme.borderLight,
                        width: cantEnCarrito > 0 ? 1.8 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                p.nombre,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (cantEnCarrito > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryAmber,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  cantEnCarrito.toStringAsFixed(0),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.background,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '\$${p.precioVenta.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryAmber,
                              ),
                            ),
                            Text(
                              p.esReceta ? 'PREPARADO' : 'DIRECTO',
                              style: TextStyle(
                                fontSize: 9,
                                color: p.esReceta
                                    ? AppTheme.secondaryCyan
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildResumenCarrito({bool isWide = false}) {
    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          // Cabecera del panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceVariant,
              border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RONDA ACTUAL (RONDA $_proximaRonda)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryAmber,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (_comandaAbiertaSeleccionada != null)
                      Text(
                        'Cliente: ${_comandaAbiertaSeleccionada!.nombreCliente}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
                if (_carrito.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: AppTheme.errorCoral,
                    ),
                    label: const Text(
                      'Vaciar',
                      style: TextStyle(
                        color: AppTheme.errorCoral,
                        fontSize: 11,
                      ),
                    ),
                    onPressed: () => setState(() => _carrito.clear()),
                  ),
              ],
            ),
          ),

          // Lista de Rondas Anteriores si existen
          if (_comandaAbiertaSeleccionada != null &&
              _comandaAbiertaSeleccionada!.detalles.isNotEmpty)
            ExpansionTile(
              dense: true,
              initiallyExpanded: false,
              leading: const Icon(
                Icons.history,
                color: AppTheme.secondaryCyan,
                size: 18,
              ),
              title: Text(
                'Consumo Despachado Previo (${_comandaAbiertaSeleccionada!.detalles.length} ítems)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryCyan,
                ),
              ),
              subtitle: Text(
                'Subtotal anterior: \$${_comandaAbiertaSeleccionada!.precioTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _comandaAbiertaSeleccionada!.detalles.length,
                    itemBuilder: (context, index) {
                      final det = _comandaAbiertaSeleccionada!.detalles[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '[R${det.ronda}] ${det.cantidad.toStringAsFixed(0)}x ${det.nombreProducto}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              '\$${det.subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

          // Lista de productos de la ronda actual
          Expanded(
            child: _carrito.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sports_bar_outlined,
                          size: 40,
                          color: AppTheme.textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Selecciona productos para despachar en esta ronda',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _carrito.length,
                    separatorBuilder: (_, _) => const Divider(height: 8),
                    itemBuilder: (context, index) {
                      final item = _carrito.values.elementAt(index);
                      final ProductoBarra prod =
                          item['producto'] as ProductoBarra;
                      final double cant = (item['cantidad'] as num).toDouble();
                      final subtotal = cant * prod.precioVenta;

                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prod.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '\$${prod.precioVenta.toStringAsFixed(2)} c/u',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 20,
                                ),
                                color: AppTheme.errorCoral,
                                onPressed: () => _decrementar(prod.id),
                              ),
                              Text(
                                cant.toStringAsFixed(0),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 20,
                                ),
                                color: AppTheme.successMint,
                                onPressed: () => _agregarOIncrementar(prod),
                              ),
                            ],
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                              '\$${subtotal.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.primaryAmber,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Total y Botones de Acción (DESPACHAR y REGISTRAR)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceVariant,
              border: Border(top: BorderSide(color: AppTheme.borderLight)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ronda actual:',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    Text(
                      '\$${_totalRondaActual.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL CUENTA:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '\$${_totalAcumuladoCuenta.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryAmber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // BOTÓN 1: DESPACHAR
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _enviando ? null : _despacharRonda,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAmber,
                      foregroundColor: AppTheme.background,
                    ),
                    icon: _enviando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.background,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _comandaAbiertaSeleccionada != null
                          ? 'DESPACHAR RONDA $_proximaRonda'
                          : 'DESPACHAR (ABRIR CUENTA)',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // BOTÓN 2: REGISTRAR (Cierre de comanda)
                if (_comandaAbiertaSeleccionada != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: _enviando ? null : _cerrarComandaFinal,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.successMint,
                        side: const BorderSide(
                          color: AppTheme.successMint,
                          width: 1.5,
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(
                        'REGISTRAR Y CERRAR CUENTA (\$${_comandaAbiertaSeleccionada!.precioTotal.toStringAsFixed(2)})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarraInferiorMovil() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _comandaAbiertaSeleccionada != null
                          ? 'Cuenta: ${_comandaAbiertaSeleccionada!.nombreCliente}'
                          : '${_carrito.length} ítems en ronda',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Total: \$${_totalAcumuladoCuenta.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryAmber,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_comandaAbiertaSeleccionada != null) ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.successMint,
                          side: const BorderSide(color: AppTheme.successMint),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: _enviando ? null : _cerrarComandaFinal,
                        child: const Text(
                          'REGISTRAR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAmber,
                        foregroundColor: AppTheme.background,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onPressed: _enviando ? null : _despacharRonda,
                      child: _enviando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.background,
                              ),
                            )
                          : Text(
                              _comandaAbiertaSeleccionada != null
                                  ? 'DESPACHAR R$_proximaRonda'
                                  : 'DESPACHAR',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
