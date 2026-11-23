import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/export_print_widget.dart';
import '../../../core/widgets/ticket_pos_barra.dart';
import '../models/comanda_model.dart';
import '../services/comandas_service.dart';

/// Pantalla de Historial de Comandas con Doble Buscador (Cliente y Producto)
class HistorialComandasScreen extends StatefulWidget {
  const HistorialComandasScreen({super.key});

  @override
  State<HistorialComandasScreen> createState() =>
      _HistorialComandasScreenState();
}

class _HistorialComandasScreenState extends State<HistorialComandasScreen> {
  final _service = ComandasService();

  final _filtroClienteController = TextEditingController();
  final _filtroProductoController = TextEditingController();

  DateTime? _fechaSeleccionada;
  List<Comanda> _comandas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Por defecto hoy
    _fechaSeleccionada = DateTime.now();
    _cargarComandas();
  }

  @override
  void dispose() {
    _filtroClienteController.dispose();
    _filtroProductoController.dispose();
    super.dispose();
  }

  Future<void> _cargarComandas() async {
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
            content: Text('Error al cargar historial: $e'),
            backgroundColor: AppTheme.errorCoral,
          ),
        );
      }
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _filtroClienteController.clear();
      _filtroProductoController.clear();
      _fechaSeleccionada = DateTime.now();
    });
    _cargarComandas();
  }

  double get _totalRecaudado =>
      _comandas.fold(0.0, (sum, c) => sum + c.precioTotal);

  void _exportarHistorial() {
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

    final fechaTitulo = _fechaSeleccionada != null
        ? DateFormat('dd/MM/yyyy').format(_fechaSeleccionada!)
        : 'Todas las fechas';

    ExportPrintWidget.showModal(
      context,
      data: ReporteExportData(
        titulo: 'Historial de Comandas de Barra',
        subtitulo: 'Filtro: $fechaTitulo',
        fecha: DateTime.now(),
        resumenKpis: {
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Historial de Comandas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar historial',
            onPressed: _cargarComandas,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Exportar o Imprimir historial',
            onPressed: _comandas.isEmpty ? null : _exportarHistorial,
          ),
        ],
      ),
      body: Column(
        children: [
          // PANEL DE DOBLE BUSCADOR Y FILTROS
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DOBLE BUSCADOR DE COMANDAS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryAmber,
                          letterSpacing: 0.8,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(
                          Icons.clear_all,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                        label: const Text(
                          'Limpiar',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        onPressed: _limpiarFiltros,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Fila 1: Buscador por Cliente y Producto (adaptativo responsive)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 460;
                      if (isNarrow) {
                        return Column(
                          children: [
                            TextField(
                              controller: _filtroClienteController,
                              decoration: const InputDecoration(
                                labelText: 'Cliente / Mesa',
                                hintText: 'Ej. Carlos / Mesa 4',
                                prefixIcon: Icon(
                                  Icons.person_search,
                                  color: AppTheme.secondaryCyan,
                                  size: 20,
                                ),
                                isDense: true,
                              ),
                              onChanged: (_) => _cargarComandas(),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _filtroProductoController,
                              decoration: const InputDecoration(
                                labelText: 'Producto',
                                hintText: 'Ej. Mojito / Polar',
                                prefixIcon: Icon(
                                  Icons.local_drink,
                                  color: AppTheme.primaryAmber,
                                  size: 20,
                                ),
                                isDense: true,
                              ),
                              onChanged: (_) => _cargarComandas(),
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _filtroClienteController,
                              decoration: const InputDecoration(
                                labelText: 'Cliente / Mesa',
                                hintText: 'Ej. Carlos / Mesa 4',
                                prefixIcon: Icon(
                                  Icons.person_search,
                                  color: AppTheme.secondaryCyan,
                                  size: 20,
                                ),
                                isDense: true,
                              ),
                              onChanged: (_) => _cargarComandas(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _filtroProductoController,
                              decoration: const InputDecoration(
                                labelText: 'Producto',
                                hintText: 'Ej. Mojito / Polar',
                                prefixIcon: Icon(
                                  Icons.local_drink,
                                  color: AppTheme.primaryAmber,
                                  size: 20,
                                ),
                                isDense: true,
                              ),
                              onChanged: (_) => _cargarComandas(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  // Fila 2: Selector de Fecha y Total Recaudado (con Wrap anti-desborde)
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    _fechaSeleccionada ?? DateTime.now(),
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() => _fechaSeleccionada = picked);
                                _cargarComandas();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.borderLight),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.calendar_month,
                                    size: 16,
                                    color: AppTheme.secondaryCyan,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _fechaSeleccionada != null
                                        ? DateFormat('dd/MM/yyyy')
                                              .format(_fechaSeleccionada!)
                                        : 'Todas las fechas',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_fechaSeleccionada != null) ...[
                            const SizedBox(width: 6),
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              label: const Text(
                                'Ver todas',
                                style: TextStyle(fontSize: 11),
                              ),
                              backgroundColor: AppTheme.surfaceVariant,
                              onPressed: () {
                                setState(() => _fechaSeleccionada = null);
                                _cargarComandas();
                              },
                            ),
                          ],
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primaryAmber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Total: \$${_totalRecaudado.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // LISTA DE COMANDAS
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comandas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          size: 54,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No se encontraron comandas con los filtros actuales',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _limpiarFiltros,
                          child: const Text('Restablecer Filtros'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    itemCount: _comandas.length,
                    itemBuilder: (context, index) {
                      final cmd = _comandas[index];
                      return _buildCardComanda(cmd);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardComanda(Comanda cmd) {
    final dateFormat = DateFormat('dd/MM/yyyy - HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.primaryAmber.withValues(alpha: 0.5),
            ),
          ),
          child: const Icon(
            Icons.receipt,
            color: AppTheme.primaryAmber,
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                cmd.nombreCliente,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              '\$${cmd.precioTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: AppTheme.primaryAmber,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              dateFormat.format(cmd.fecha),
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            const SizedBox(width: 10),
            Text(
              '${cmd.detalles.length} productos',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.secondaryCyan,
              ),
            ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cmd.notas != null && cmd.notas!.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.comment,
                        size: 14,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Notas: ${cmd.notas}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                const Text(
                  'DETALLE DE ÍTEMS DESPACHADOS:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                ...cmd.detalles.map((d) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${d.cantidad.toStringAsFixed(0)}x  ${d.nombreProducto}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '\$${d.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(
                        Icons.print,
                        size: 16,
                        color: AppTheme.primaryAmber,
                      ),
                      label: const Text(
                        'Reimprimir Ticket',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        TicketPosBarra.imprimirTicket(
                          TicketPosData(
                            ordenArea: cmd.mesa,
                            cliente: cmd.nombreCliente,
                            mesero: cmd.mesero,
                            fecha: cmd.fecha,
                            ronda: cmd.ronda,
                            numeroOrden:
                                cmd.numeroTicket ??
                                (cmd.id.length >= 8
                                    ? cmd.id.substring(0, 8).toUpperCase()
                                    : 'BARRA'),
                            items: cmd.detalles
                                .map(
                                  (d) => TicketItemData(
                                    cantidad: d.cantidad,
                                    nombreProducto: d.nombreProducto,
                                    precioUnitario: d.precioUnitario,
                                  ),
                                )
                                .toList(),
                            notasCoordinacion: cmd.notas,
                            total: cmd.precioTotal,
                          ),
                        );
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
  }
}
