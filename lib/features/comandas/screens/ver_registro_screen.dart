import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/export_print_widget.dart';
import '../../../core/widgets/ticket_pos_barra.dart';
import '../models/comanda_model.dart';
import '../services/comandas_service.dart';

/// Widget y Pantalla "Ver Registro":
/// Cuenta con un buscador Calendario interactivo para consultar cualquier fecha,
/// ver el registro completo de comandas y ventas, y descargar o imprimir reportes.
class VerRegistroScreen extends StatefulWidget {
  final DateTime? fechaInicial;

  const VerRegistroScreen({super.key, this.fechaInicial});

  @override
  State<VerRegistroScreen> createState() => _VerRegistroScreenState();
}

class _VerRegistroScreenState extends State<VerRegistroScreen> {
  final _service = ComandasService();
  final _filtroClienteController = TextEditingController();
  final _filtroProductoController = TextEditingController();

  late DateTime _fechaSeleccionada;
  List<Comanda> _comandas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fechaSeleccionada = widget.fechaInicial ?? DateTime.now();
    _cargarRegistro();
  }

  @override
  void dispose() {
    _filtroClienteController.dispose();
    _filtroProductoController.dispose();
    super.dispose();
  }

  Future<void> _cargarRegistro() async {
    setState(() => _isLoading = true);
    try {
      final list = await _service.getHistorialComandas(
        fecha: _fechaSeleccionada,
        filtroCliente: _filtroClienteController.text,
        filtroProducto: _filtroProductoController.text,
      );
      if (mounted) {
        setState(() {
          _comandas = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar registro: $e'),
            backgroundColor: AppTheme.errorCoral,
          ),
        );
      }
    }
  }

  void _seleccionarFecha(DateTime nuevaFecha) {
    setState(() => _fechaSeleccionada = nuevaFecha);
    _cargarRegistro();
  }

  Future<void> _abrirSelectorCalendario() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryAmber,
              onPrimary: AppTheme.background,
              surface: AppTheme.surface,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _seleccionarFecha(picked);
    }
  }

  double get _totalRecaudado =>
      _comandas.fold(0.0, (sum, c) => sum + c.precioTotal);

  void _descargarOImprimirRegistro() {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final List<List<String>> filas = [];

    for (final cmd in _comandas) {
      final ticketId = cmd.numeroTicket ?? cmd.id.substring(0, 8);
      if (cmd.detalles.isEmpty) {
        filas.add([
          ticketId,
          dateFormat.format(cmd.fecha),
          cmd.nombreCliente,
          'Sin detalles',
          '0',
          '\$${cmd.precioTotal.toStringAsFixed(2)}',
        ]);
      } else {
        for (final d in cmd.detalles) {
          filas.add([
            ticketId,
            dateFormat.format(cmd.fecha),
            cmd.nombreCliente,
            d.nombreProducto,
            d.cantidad.toStringAsFixed(0),
            '\$${d.subtotal.toStringAsFixed(2)}',
          ]);
        }
      }
    }

    final fechaStr = DateFormat('dd/MM/yyyy').format(_fechaSeleccionada);

    ExportPrintWidget.showModal(
      context,
      data: ReporteExportData(
        titulo: 'Registro de Barra e Inventario',
        subtitulo: 'Fecha consultada: $fechaStr',
        fecha: DateTime.now(),
        resumenKpis: {
          'Fecha': fechaStr,
          'Total Comandas': '${_comandas.length}',
          'Total Recaudado': '\$${_totalRecaudado.toStringAsFixed(2)}',
        },
        columnasTabla: [
          'Ticket #',
          'Fecha / Hora',
          'Cliente',
          'Producto',
          'Cant',
          'Total',
        ],
        filasTabla: filas,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fechaFormat = DateFormat('dd/MM/yyyy').format(_fechaSeleccionada);
    final esHoy =
        DateFormat('yyyy-MM-dd').format(_fechaSeleccionada) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Ver Registro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar registro',
            onPressed: _cargarRegistro,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Descargar o Imprimir registro',
            onPressed: _comandas.isEmpty ? null : _descargarOImprimirRegistro,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. BUSCADOR CALENDARIO INTERACTIVO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AppTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Botón día anterior
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 24),
                      tooltip: 'Día anterior',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _seleccionarFecha(
                        _fechaSeleccionada.subtract(const Duration(days: 1)),
                      ),
                    ),
                    // Selector principal de calendario
                    Expanded(
                      child: InkWell(
                        onTap: _abrirSelectorCalendario,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.primaryAmber.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.calendar_month,
                                color: AppTheme.primaryAmber,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Fecha: $fechaFormat',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryAmber,
                                ),
                              ),
                              if (esHoy) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successMint.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'HOY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.successMint,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Botón día siguiente
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 24),
                      tooltip: 'Día siguiente',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _seleccionarFecha(
                        _fechaSeleccionada.add(const Duration(days: 1)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Botones rápidos de fecha y acción Descargar / Imprimir
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: esHoy
                                ? AppTheme.primaryAmber
                                : AppTheme.textSecondary,
                            side: BorderSide(
                              color: esHoy
                                  ? AppTheme.primaryAmber
                                  : AppTheme.borderLight,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: () => _seleccionarFecha(DateTime.now()),
                          child: const Text(
                            'Hoy',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppTheme.textSecondary,
                            side: const BorderSide(color: AppTheme.borderLight),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: () => _seleccionarFecha(
                            DateTime.now().subtract(const Duration(days: 1)),
                          ),
                          child: const Text(
                            'Ayer',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAmber,
                        foregroundColor: AppTheme.background,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text(
                        'Descargar / Imprimir',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _comandas.isEmpty
                          ? null
                          : _descargarOImprimirRegistro,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. RESUMEN DE TOTALES Y RECAUDACIÓN DEL REGISTRO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceVariant,
              border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      size: 16,
                      color: AppTheme.secondaryCyan,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_comandas.length} Comandas',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text(
                      'Total Recaudado: ',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    Text(
                      '\$${_totalRecaudado.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryAmber,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. LISTADO DE COMANDAS DEL REGISTRO
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comandas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 48,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No se encontraron comandas registradas el $fechaFormat',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.today, size: 16),
                          label: const Text('Ver Registro de Hoy'),
                          onPressed: () => _seleccionarFecha(DateTime.now()),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _comandas.length,
                    itemBuilder: (context, index) {
                      final cmd = _comandas[index];
                      final ticketNum =
                          cmd.numeroTicket ??
                          cmd.id.substring(0, 8).toUpperCase();
                      final horaStr = DateFormat('hh:mm a').format(cmd.fecha);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        color: AppTheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppTheme.borderLight),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.receipt,
                              color: AppTheme.primaryAmber,
                              size: 20,
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  cmd.nombreCliente,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '\$${cmd.precioTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: AppTheme.primaryAmber,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                ticketNum,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.secondaryCyan,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• $horaStr',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• ${cmd.detalles.length} productos',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                          children: [
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...cmd.detalles.map(
                                    (d) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 3,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${d.cantidad.toStringAsFixed(0)}x  ${d.nombreProducto}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '\$${d.subtotal.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (cmd.metodoPago != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceVariant,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'Pago: ${cmd.metodoPago}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textMuted,
                                            ),
                                          ),
                                        )
                                      else
                                        const SizedBox(),
                                      TextButton.icon(
                                        icon: const Icon(
                                          Icons.print_outlined,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Imprimir Ticket',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        onPressed: () {
                                          final items = cmd.detalles
                                              .map(
                                                (d) => TicketItemData(
                                                  cantidad: d.cantidad,
                                                  nombreProducto:
                                                      d.nombreProducto,
                                                  precioUnitario:
                                                      d.precioUnitario,
                                                ),
                                              )
                                              .toList();
                                          final data = TicketPosData(
                                            ordenArea: cmd.mesa,
                                            cliente: cmd.nombreCliente,
                                            mesero: cmd.mesero,
                                            fecha: cmd.fecha,
                                            ronda: cmd.ronda,
                                            numeroOrden: ticketNum,
                                            items: items,
                                            notasCoordinacion: cmd.notas,
                                            total: cmd.precioTotal,
                                          );
                                          TicketPosBarra.imprimirTicket(data);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
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
    );
  }
}
