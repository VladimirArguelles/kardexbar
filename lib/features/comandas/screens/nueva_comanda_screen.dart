import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/export_print_widget.dart';
import '../models/comanda_model.dart';
import '../services/comandas_service.dart';

/// Pantalla táctil para registrar una nueva comanda con total auto-calculado
class NuevaComandaScreen extends StatefulWidget {
  const NuevaComandaScreen({super.key});

  @override
  State<NuevaComandaScreen> createState() => _NuevaComandaScreenState();
}

class _NuevaComandaScreenState extends State<NuevaComandaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ComandasService();

  DateTime _fecha = DateTime.now();
  final _clienteController = TextEditingController();
  final _notasController = TextEditingController();

  List<ProductoBarra> _productos = [];
  bool _cargandoProductos = true;
  String _categoriaSeleccionada = 'Todas';

  // Carrito de compras: productoId -> { 'producto': ProductoBarra, 'cantidad': double }
  final Map<String, Map<String, dynamic>> _carrito = {};
  bool _enviando = false;

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
  }

  @override
  void dispose() {
    _clienteController.dispose();
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
            content: Text('Error al cargar productos: $e'),
            backgroundColor: AppTheme.errorCoral,
          ),
        );
      }
    }
  }

  double get _totalCalculado {
    double total = 0.0;
    for (final item in _carrito.values) {
      final ProductoBarra prod = item['producto'] as ProductoBarra;
      final double cant = (item['cantidad'] as num).toDouble();
      total += (cant * prod.precioVenta);
    }
    return total;
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

  void _limpiarFormulario() {
    setState(() {
      _clienteController.clear();
      _notasController.clear();
      _fecha = DateTime.now();
      _carrito.clear();
    });
  }

  Future<void> _enviarComanda() async {
    if (!_formKey.currentState!.validate()) return;

    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe agregar al menos un producto a la comanda'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      final clienteNombre = _clienteController.text.trim();
      final notasComanda = _notasController.text.trim();
      final fechaComanda = _fecha;
      final filasTicket = _carrito.values.map((it) {
        final ProductoBarra p = it['producto'] as ProductoBarra;
        final double cant = (it['cantidad'] as num).toDouble();
        return [
          p.nombre,
          cant.toStringAsFixed(0),
          '\$${p.precioVenta.toStringAsFixed(2)}',
          '\$${(cant * p.precioVenta).toStringAsFixed(2)}',
        ];
      }).toList();
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

      final resultado = await _service.registrarComandaCompleta(
        fecha: _fecha,
        nombreCliente: clienteNombre,
        sedeId: sedeId,
        items: itemsPayload,
        notas: notasComanda.isEmpty ? null : notasComanda,
      );

      if (mounted) {
        final totalFinal = resultado['precio_total'] ?? _totalCalculado;
        final comandaId = resultado['comanda_id'];

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Comanda registrada con éxito! Total: \$${(totalFinal as num).toStringAsFixed(2)}',
            ),
            backgroundColor: AppTheme.successMint,
            action: SnackBarAction(
              label: 'IMPRIMIR TICKET',
              textColor: AppTheme.background,
              onPressed: () {
                _imprimirTicketReciente(
                  comandaId?.toString() ?? '',
                  totalFinal.toDouble(),
                  clienteNombre,
                  fechaComanda,
                  filasTicket,
                );
              },
            ),
          ),
        );

        _limpiarFormulario();
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

  void _imprimirTicketReciente(
    String id,
    double total,
    String clienteNombre,
    DateTime fechaComanda,
    List<List<String>> filas,
  ) {
    ExportPrintWidget.ejecutarImpresionPdf(
      ReporteExportData(
        titulo: 'Ticket de Comanda #$id',
        subtitulo: 'Cliente: $clienteNombre',
        fecha: fechaComanda,
        resumenKpis: {
          'Total a Pagar': '\$${total.toStringAsFixed(2)}',
          'Sede': SupabaseConfig.sedePrincipalNombre,
        },
        columnasTabla: ['Producto', 'Cant', 'P. Unit', 'Subtotal'],
        filasTabla: filas,
      ),
    );
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
        title: const Text('Nueva Comanda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar productos',
            onPressed: _cargarProductos,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Limpiar comanda',
            onPressed: _carrito.isNotEmpty ? _limpiarFormulario : null,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna izquierda: Formulario y Catálogo
                Expanded(
                  flex: 6,
                  child: _buildCatalogoYFormulario(productosFiltrados),
                ),
                const VerticalDivider(width: 1),
                // Columna derecha: Carrito y Resumen
                Expanded(flex: 4, child: _buildResumenCarrito()),
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
        padding: const EdgeInsets.all(16.0),
        children: [
          // Datos Principales: Cliente y Fecha
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DATOS DE LA COMANDA',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryAmber,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _clienteController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Cliente *',
                      hintText: 'Ej. Mesa 4 / Carlos Pérez',
                      prefixIcon: Icon(
                        Icons.person,
                        color: AppTheme.primaryAmber,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Ingrese el nombre del cliente o mesa';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: _fecha,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2030),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                _fecha = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  _fecha.hour,
                                  _fecha.minute,
                                );
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                  color: AppTheme.secondaryCyan,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('dd/MM/yyyy HH:mm').format(_fecha),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _notasController,
                          decoration: const InputDecoration(
                            labelText: 'Notas',
                            hintText: 'Opcional (sin hielo, etc.)',
                            prefixIcon: Icon(
                              Icons.note,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Selector Horizontal de Categorías
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categorias.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categorias[index];
                final isSelected = cat == _categoriaSeleccionada;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryAmber,
                  backgroundColor: AppTheme.surfaceVariant,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppTheme.background
                        : AppTheme.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _categoriaSeleccionada = cat);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Grilla de Productos
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
                maxCrossAxisExtent: 220,
                mainAxisExtent: 110,
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
                                  fontSize: 13,
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
                                    color: AppTheme.background,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
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
                                color: AppTheme.primaryAmber,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              p.esReceta ? 'RECETA' : 'DIRECTO',
                              style: TextStyle(
                                fontSize: 9,
                                color: p.esReceta
                                    ? AppTheme.secondaryCyan
                                    : AppTheme.textMuted,
                                fontWeight: FontWeight.w600,
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

  Widget _buildResumenCarrito() {
    return Container(
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.shopping_cart,
                      color: AppTheme.primaryAmber,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'CARRITO DE COMANDA',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_carrito.length} ítems',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _carrito.isEmpty
                ? const Center(
                    child: Text(
                      'No hay productos agregados.\nToca los productos del catálogo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _carrito.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _carrito.values.elementAt(index);
                      final ProductoBarra prod =
                          item['producto'] as ProductoBarra;
                      final double cant = (item['cantidad'] as num).toDouble();
                      final subtotal = cant * prod.precioVenta;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
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
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '\$${prod.precioVenta.toStringAsFixed(2)} c/u',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Botones de Cantidad
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 22,
                                  ),
                                  color: AppTheme.errorCoral,
                                  onPressed: () => _decrementar(prod.id),
                                ),
                                Text(
                                  cant.toStringAsFixed(0),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 22,
                                  ),
                                  color: AppTheme.successMint,
                                  onPressed: () => _agregarOIncrementar(prod),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 68,
                              child: Text(
                                '\$${subtotal.toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.primaryAmber,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // Total Auto-calculado y Botón de Envío
          Container(
            padding: const EdgeInsets.all(16),
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
                      'TOTAL A COBRAR:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '\$${_totalCalculado.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryAmber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _enviando ? null : _enviarComanda,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAmber,
                      foregroundColor: AppTheme.background,
                    ),
                    child: _enviando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.background,
                            ),
                          )
                        : const Text(
                            'REGISTRAR COMANDA',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarraInferiorMovil() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.borderLight)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_carrito.length} ítems en comanda',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              Text(
                '\$${_totalCalculado.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryAmber,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _enviando ? null : _enviarComanda,
            child: _enviando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('REGISTRAR'),
          ),
        ],
      ),
    );
  }
}
