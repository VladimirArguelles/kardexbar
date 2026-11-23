import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ticket_pos_barra.dart';
import '../models/comanda_model.dart';
import '../services/comandas_service.dart';

/// Pantalla de Mesas / Cuentas Abiertas inspirada en la arquitectura POS de barra
/// Permite visualizar todas las órdenes abiertas, ver su detalle en tiempo real,
/// reimprimir ticket/precuenta, agregar nuevos productos por ronda y registrar/cobrar la comanda.
class MesasAbiertasScreen extends StatefulWidget {
  final ValueChanged<Comanda>? onAgregarProductos;
  final VoidCallback? onNuevaComanda;

  const MesasAbiertasScreen({
    super.key,
    this.onAgregarProductos,
    this.onNuevaComanda,
  });

  @override
  State<MesasAbiertasScreen> createState() => _MesasAbiertasScreenState();
}

class _MesasAbiertasScreenState extends State<MesasAbiertasScreen> {
  final _service = ComandasService();
  final _filtroController = TextEditingController();

  List<Comanda> _mesas = [];
  bool _isLoading = true;
  String _orden = 'Recientes'; // 'Recientes' | 'Alfabético'

  @override
  void initState() {
    super.initState();
    _cargarMesas();
  }

  @override
  void dispose() {
    _filtroController.dispose();
    super.dispose();
  }

  Future<void> _cargarMesas() async {
    setState(() => _isLoading = true);
    try {
      final sedeId = await SupabaseConfig.getSedePrincipalId();
      final list = await _service.getComandasAbiertas(sedeId: sedeId);
      if (mounted) {
        setState(() {
          _mesas = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar mesas abiertas: $e'),
            backgroundColor: AppTheme.errorCoral,
          ),
        );
      }
    }
  }

  double get _totalGeneral => _mesas.fold(0.0, (acc, m) => acc + m.precioTotal);

  List<Comanda> get _mesasFiltradas {
    final query = _filtroController.text.trim().toLowerCase();
    List<Comanda> list = _mesas.where((m) {
      if (query.isEmpty) return true;
      final matchCliente = m.nombreCliente.toLowerCase().contains(query);
      final matchMesa = m.mesa.toLowerCase().contains(query);
      final matchMesero = m.mesero.toLowerCase().contains(query);
      final matchTicket = (m.numeroTicket ?? '').toLowerCase().contains(query);
      return matchCliente || matchMesa || matchMesero || matchTicket;
    }).toList();

    if (_orden == 'Alfabético') {
      list.sort(
        (a, b) => a.nombreCliente.toLowerCase().compareTo(
          b.nombreCliente.toLowerCase(),
        ),
      );
    } else {
      list.sort((a, b) => b.fecha.compareTo(a.fecha));
    }

    return list;
  }

  String _tiempoTranscurrido(DateTime fecha) {
    final diff = DateTime.now().difference(fecha);
    if (diff.inMinutes < 1) {
      return 'hace un momento';
    }
    if (diff.inMinutes < 60) {
      return 'hace ${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      return 'hace ${diff.inHours} h';
    }
    return DateFormat('dd/MM hh:mm a').format(fecha);
  }

  String _iniciales(String nombre) {
    final parts = nombre.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) {
      return 'MB';
    }
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _imprimirTicketPrecuenta(Comanda cmd) async {
    final todosLosItems = cmd.detalles.map((d) {
      return TicketItemData(
        cantidad: d.cantidad,
        nombreProducto: d.nombreProducto,
        precioUnitario: d.precioUnitario,
      );
    }).toList();

    final ticketData = TicketPosData(
      ordenArea: cmd.mesa,
      cliente: cmd.nombreCliente,
      mesero: cmd.mesero,
      fecha: cmd.fecha,
      ronda: cmd.ronda,
      numeroOrden:
          cmd.numeroTicket ??
          (cmd.id.length >= 8 ? cmd.id.substring(0, 8).toUpperCase() : 'BARRA'),
      items: todosLosItems,
      notasCoordinacion: cmd.notas,
      total: cmd.precioTotal,
    );

    await TicketPosBarra.imprimirTicket(ticketData);
  }

  Future<void> _cobrarYRegistrar(Comanda cmd) async {
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
              Expanded(
                child: Text(
                  'Cobrar Mesa: ${cmd.nombreCliente}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                      'TOTAL A COBRAR:',
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
              child: const Text('Cancelar'),
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

    try {
      await _service.cerrarComandaAbierta(
        comandaId: cmd.id,
        metodoPago: metodoSeleccionado,
      );

      // Imprimir ticket de cuenta final
      await _imprimirTicketPrecuenta(cmd);

      await _cargarMesas();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Comanda de ${cmd.nombreCliente} registrada y cerrada con éxito por \$${cmd.precioTotal.toStringAsFixed(2)}!',
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final mesas = _mesasFiltradas;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _cargarMesas,
        child: Column(
          children: [
            // PANEL SUPERIOR: Resumen de mesas, total acumulado y botón actualizar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_mesas.length} mesas',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryAmber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '\$${_totalGeneral.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryAmber,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.secondaryCyan,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text(
                      'Actualizar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _cargarMesas,
                  ),
                  if (widget.onNuevaComanda != null) ...[
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAmber,
                        foregroundColor: AppTheme.background,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'NUEVA MESA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: widget.onNuevaComanda,
                    ),
                  ],
                ],
              ),
            ),

            // BUSCADOR Y ORDENAMIENTO
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.surface,
              child: Column(
                children: [
                  TextField(
                    controller: _filtroController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Filtrar por mesa, cliente o mesero',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: AppTheme.textMuted,
                      ),
                      suffixIcon: _filtroController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _filtroController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'ORDENAR:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time, size: 14),
                            SizedBox(width: 4),
                            Text('Recientes', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                        selected: _orden == 'Recientes',
                        selectedColor: AppTheme.surfaceVariant,
                        onSelected: (val) {
                          if (val) setState(() => _orden = 'Recientes');
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sort_by_alpha, size: 14),
                            SizedBox(width: 4),
                            Text('Alfabético', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                        selected: _orden == 'Alfabético',
                        selectedColor: AppTheme.surfaceVariant,
                        onSelected: (val) {
                          if (val) setState(() => _orden = 'Alfabético');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // LISTA DE TARJETAS DE MESAS ABIERTAS (IDÉNTICAS AL DISEÑO DE IMAGEN 3)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : mesas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.table_bar_outlined,
                            size: 56,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No hay mesas o cuentas abiertas en este momento',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (widget.onNuevaComanda != null)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryAmber,
                                foregroundColor: AppTheme.background,
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('ABRIR PRIMERA COMANDA'),
                              onPressed: widget.onNuevaComanda,
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: mesas.length,
                      itemBuilder: (context, index) {
                        final cmd = mesas[index];
                        return _buildTarjetaMesa(cmd);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta de comanda abierta con layout idéntico a la imagen 3:
  /// - Avatar circular con iniciales
  /// - Badge ● RECIBIDA / ● ABIERTA
  /// - Botón impresora de ticket
  /// - Total $ en grande
  /// - Nombre del cliente en negrita grande
  /// - Mesero y tiempo transcurrido
  /// - Lista de productos desplegados
  /// - Botones inferiores: "+ Agregar", "Precuenta", "Cobrar"
  Widget _buildTarjetaMesa(Comanda cmd) {
    final iniciales = _iniciales(cmd.nombreCliente);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabecera de la tarjeta: Avatar, Badge estado, botón imprimir, Total $
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar con iniciales
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.surfaceVariant,
                  child: Text(
                    iniciales,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryCyan,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Badge ● ABIERTA / RECIBIDA
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successMint.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.successMint.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.successMint,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'ABIERTA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successMint,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Botón rápido de impresión de ticket térmico
                IconButton(
                  icon: const Icon(
                    Icons.print_outlined,
                    size: 20,
                    color: AppTheme.secondaryCyan,
                  ),
                  tooltip: 'Imprimir ticket de orden POS',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _imprimirTicketPrecuenta(cmd),
                ),

                const Spacer(),

                // Total grande
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${cmd.precioTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryAmber,
                      ),
                    ),
                    Text(
                      'Ronda ${cmd.ronda}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Nombre del Cliente y Mesero
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cmd.nombreCliente,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      size: 14,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cmd.mesero,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _tiempoTranscurrido(cmd.fecha),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        cmd.mesa.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryCyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3. Desglose de ítems servidos en la comanda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: cmd.detalles.map((d) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '${d.cantidad.toStringAsFixed(0)}x ',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          d.nombreProducto.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '\$${d.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Notas de coordinación si existen (burbuja)
          if (cmd.notas != null && cmd.notas!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryAmber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 14,
                      color: AppTheme.primaryAmber,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cmd.notas!.trim(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryAmber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          const Divider(height: 1),

          // 4. BOTONES INFERIORES: "+ Agregar", "Precuenta", "Cobrar" (como en imagen 3)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Botón + Agregar
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.secondaryCyan,
                      side: const BorderSide(
                        color: AppTheme.secondaryCyan,
                        width: 1.2,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text(
                      'Agregar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () {
                      if (widget.onAgregarProductos != null) {
                        widget.onAgregarProductos!(cmd);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Botón Precuenta (Imprimir Ticket)
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.borderLight),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_outlined, size: 16),
                    label: const Text(
                      'Precuenta',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _imprimirTicketPrecuenta(cmd),
                  ),
                ),
                const SizedBox(width: 8),

                // Botón Cobrar / Registrar
                Expanded(
                  flex: 4,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successMint,
                      foregroundColor: AppTheme.background,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.payments_outlined, size: 16),
                    label: const Text(
                      'Cobrar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: () => _cobrarYRegistrar(cmd),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
