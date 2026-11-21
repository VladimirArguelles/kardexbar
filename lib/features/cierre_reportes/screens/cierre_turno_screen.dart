import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/export_print_widget.dart';
import '../../comandas/models/comanda_model.dart';
import '../../comandas/services/comandas_service.dart';
import '../../inventario/models/kardex_movimiento_model.dart';
import '../../inventario/services/inventario_service.dart';

/// Pantalla de Cierre de Turno y Cuadre Diario de Barra con ExportPrintWidget
class CierreTurnoScreen extends StatefulWidget {
  const CierreTurnoScreen({super.key});

  @override
  State<CierreTurnoScreen> createState() => _CierreTurnoScreenState();
}

class _CierreTurnoScreenState extends State<CierreTurnoScreen> {
  final _comandasService = ComandasService();
  final _inventarioService = InventarioService();

  DateTime _fechaCierre = DateTime.now();
  List<Comanda> _comandasTurno = [];
  List<KardexMovimiento> _movimientosTurno = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosCierre();
  }

  Future<void> _cargarDatosCierre() async {
    setState(() => _isLoading = true);
    try {
      final sedeId = await SupabaseConfig.getSedePrincipalId();
      final comandas = await _comandasService.getHistorialComandas(fecha: _fechaCierre);
      final movs = await _inventarioService.getMovimientosKardex(sedeId: sedeId, limit: 100);

      // Filtrar movimientos del día de cierre
      final movsDia = movs.where((m) {
        return m.fecha.year == _fechaCierre.year &&
            m.fecha.month == _fechaCierre.month &&
            m.fecha.day == _fechaCierre.day;
      }).toList();

      if (mounted) {
        setState(() {
          _comandasTurno = comandas;
          _movimientosTurno = movsDia;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos del cierre: $e'),
            backgroundColor: AppTheme.errorCoral,
          ),
        );
      }
    }
  }

  double get _totalRecaudado =>
      _comandasTurno.fold(0.0, (acc, c) => acc + c.precioTotal);

  double get _totalItemsDespachados {
    double total = 0;
    for (final c in _comandasTurno) {
      for (final d in c.detalles) {
        total += d.cantidad;
      }
    }
    return total;
  }

  double get _totalConsumoInterno => _movimientosTurno
      .where((m) => m.tipoMovimiento == 'CONSUMO_DUENO' || m.tipoMovimiento == 'CONSUMO_TRABAJADOR')
      .fold(0.0, (acc, m) => acc + m.cantidad);

  double get _totalMermas => _movimientosTurno
      .where((m) => m.tipoMovimiento == 'MERMA')
      .fold(0.0, (acc, m) => acc + m.cantidad);

  // Agrupa ventas por producto
  Map<String, Map<String, dynamic>> get _desgloseProductos {
    final Map<String, Map<String, dynamic>> mapa = {};
    for (final c in _comandasTurno) {
      for (final d in c.detalles) {
        if (!mapa.containsKey(d.nombreProducto)) {
          mapa[d.nombreProducto] = {
            'cantidad': 0.0,
            'precio_unitario': d.precioUnitario,
            'total': 0.0,
          };
        }
        mapa[d.nombreProducto]!['cantidad'] =
            (mapa[d.nombreProducto]!['cantidad'] as double) + d.cantidad;
        mapa[d.nombreProducto]!['total'] =
            (mapa[d.nombreProducto]!['total'] as double) + d.subtotal;
      }
    }
    return mapa;
  }

  ReporteExportData _generarDatosReporte() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final desglose = _desgloseProductos;

    final List<List<String>> filas = desglose.entries.map((entry) {
      final cant = entry.value['cantidad'] as double;
      final precio = entry.value['precio_unitario'] as double;
      final tot = entry.value['total'] as double;
      return [
        entry.key,
        cant.toStringAsFixed(0),
        '\$${precio.toStringAsFixed(2)}',
        '\$${tot.toStringAsFixed(2)}',
      ];
    }).toList();

    return ReporteExportData(
      titulo: 'Cierre de Turno de Barra',
      subtitulo: 'Sede Principal • Fecha: ${dateFormat.format(_fechaCierre)}',
      fecha: _fechaCierre,
      resumenKpis: {
        'Total Recaudado': '\$${_totalRecaudado.toStringAsFixed(2)}',
        'Comandas Atendidas': _comandasTurno.length.toString(),
        'Ítems Despachados': _totalItemsDespachados.toStringAsFixed(0),
        'Consumo Interno': '${_totalConsumoInterno.toStringAsFixed(1)} unid',
        'Mermas Turno': '${_totalMermas.toStringAsFixed(1)} unid',
      },
      columnasTabla: ['Producto', 'Cant Despachada', 'P. Unitario', 'Total Ventas'],
      filasTabla: filas,
      notasPie: 'Cuadre generado para arqueo de caja y auditoría física de botellas.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Cierre de Turno'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar datos',
            onPressed: _cargarDatosCierre,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Selector de Fecha del Turno
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event_note, color: AppTheme.primaryAmber, size: 22),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'FECHA DE OPERACIÓN',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textMuted,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  DateFormat('EEEE, dd/MM/yyyy', 'es_ES').format(_fechaCierre),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          icon: const Icon(Icons.calendar_month, size: 16),
                          label: const Text('Cambiar Fecha'),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _fechaCierre,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() => _fechaCierre = picked);
                              _cargarDatosCierre();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // TARJETAS KPI DEL TURNO
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryAmber, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL RECAUDADO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${_totalRecaudado.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryAmber,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_comandasTurno.length} comandas atendidas',
                              style: const TextStyle(fontSize: 11, color: AppTheme.secondaryCyan),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DESPACHOS & MERMAS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_totalItemsDespachados.toStringAsFixed(0)} ítems',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Mermas: ${_totalMermas.toStringAsFixed(1)} | Consumo Int: ${_totalConsumoInterno.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // INTEGRACIÓN EXPORTPRINTWIDGET
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EMISIÓN Y EXPORTACIÓN DEL CIERRE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryAmber,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Emita el ticket impreso en formato POS para la firma del Bartender y Supervisor o guarde la planilla en formato Excel compatible (.csv).',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ExportPrintWidget(
                          data: _generarDatosReporte(),
                          buttonLabelPrint: 'Imprimir Cierre (PDF/POS)',
                          buttonLabelExport: 'Exportar Cierre (Excel/CSV)',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // DESGLOSE POR PRODUCTO DESPACHADO
                const Text(
                  'DESGLOSE DE VENTAS POR PRODUCTO',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                if (_desgloseProductos.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No hay ventas registradas en la fecha seleccionada',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    ),
                  )
                else
                  Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _desgloseProductos.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = _desgloseProductos.entries.elementAt(index);
                        final cant = entry.value['cantidad'] as double;
                        final tot = entry.value['total'] as double;

                        return ListTile(
                          title: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Cantidad: ${cant.toStringAsFixed(0)} unidades',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          trailing: Text(
                            '\$${tot.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryAmber,
                            ),
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
