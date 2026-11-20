import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/export_print_widget.dart';
import '../../inventario/models/insumo_model.dart';
import '../../inventario/models/kardex_movimiento_model.dart';
import '../../inventario/services/inventario_service.dart';

/// Pantalla para el registro diferenciado de Consumo Interno: Dueño vs Trabajadores
class ConsumoInternoScreen extends StatefulWidget {
  const ConsumoInternoScreen({super.key});

  @override
  State<ConsumoInternoScreen> createState() => _ConsumoInternoScreenState();
}

class _ConsumoInternoScreenState extends State<ConsumoInternoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = InventarioService();

  final _cantidadController = TextEditingController();
  final _beneficiarioController = TextEditingController();
  final _motivoController = TextEditingController();

  // 'CONSUMO_DUENO' o 'CONSUMO_TRABAJADOR'
  String _tipoSeleccionado = 'CONSUMO_DUENO';

  List<InsumoInventario> _insumos = [];
  InsumoInventario? _insumoSeleccionado;
  List<KardexMovimiento> _historialConsumos = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _beneficiarioController.text = 'Dueño / Administración';
    _cargarDatos();
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _beneficiarioController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final sedeId = await SupabaseConfig.getSedePrincipalId();
      final insumos = await _service.getStockSede(sedeId);
      final movs = await _service.getMovimientosKardex(sedeId: sedeId, limit: 30);

      final consumos = movs.where((m) {
        return m.tipoMovimiento == 'CONSUMO_DUENO' || m.tipoMovimiento == 'CONSUMO_TRABAJADOR';
      }).toList();

      if (mounted) {
        setState(() {
          _insumos = insumos;
          if (_insumos.isNotEmpty && _insumoSeleccionado == null) {
            _insumoSeleccionado = _insumos.first;
          }
          _historialConsumos = consumos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: AppTheme.errorCoral,
          ),
        );
      }
    }
  }

  double get _totalConsumoDueno => _historialConsumos
      .where((c) => c.tipoMovimiento == 'CONSUMO_DUENO')
      .fold(0.0, (acc, c) => acc + c.cantidad);

  double get _totalConsumoTrabajadores => _historialConsumos
      .where((c) => c.tipoMovimiento == 'CONSUMO_TRABAJADOR')
      .fold(0.0, (acc, c) => acc + c.cantidad);

  Future<void> _guardarConsumoInterno() async {
    if (!_formKey.currentState!.validate() || _insumoSeleccionado == null) return;

    setState(() => _isSaving = true);
    try {
      final sedeId = await SupabaseConfig.getSedePrincipalId();
      final cantidad = double.parse(_cantidadController.text);
      final beneficiario = _beneficiarioController.text.trim();
      final motivo = _motivoController.text.trim();

      await _service.registrarConsumoInterno(
        insumoId: _insumoSeleccionado!.id,
        sedeId: sedeId,
        cantidad: cantidad,
        tipo: _tipoSeleccionado,
        beneficiario: beneficiario,
        motivo: motivo.isEmpty ? null : motivo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Consumo registrado exitosamente (${_tipoSeleccionado == 'CONSUMO_DUENO' ? 'Dueño' : 'Trabajador'})!',
            ),
            backgroundColor: AppTheme.successMint,
          ),
        );
        _cantidadController.clear();
        _motivoController.clear();
        _cargarDatos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar consumo: $e'),
            backgroundColor: AppTheme.errorCoral,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _exportarReporteConsumos() {
    final filas = _historialConsumos.map((c) {
      return [
        DateFormat('dd/MM/yyyy HH:mm').format(c.fecha),
        c.tipoMovimiento == 'CONSUMO_DUENO' ? 'DUEÑO' : 'TRABAJADOR',
        c.insumoNombre ?? 'Insumo',
        c.cantidad.toStringAsFixed(1),
        c.beneficiarioOMotivo ?? '',
      ];
    }).toList();

    ExportPrintWidget.showModal(
      context,
      data: ReporteExportData(
        titulo: 'Reporte de Consumo Interno',
        subtitulo: 'Auditoría de Cortesías y Consumos',
        fecha: DateTime.now(),
        resumenKpis: {
          'Consumo Dueño': '${_totalConsumoDueno.toStringAsFixed(1)} unid',
          'Consumo Trabajadores': '${_totalConsumoTrabajadores.toStringAsFixed(1)} unid',
          'Total Registros': '${_historialConsumos.length}',
        },
        columnasTabla: ['Fecha / Hora', 'Tipo', 'Insumo', 'Cantidad', 'Beneficiario / Detalle'],
        filasTabla: filas,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Consumo Interno (Cortesías)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar consumos',
            onPressed: _cargarDatos,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Exportar reporte de consumos',
            onPressed: _historialConsumos.isEmpty ? null : _exportarReporteConsumos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // KPIS RESUMEN DUAL: DUEÑO VS TRABAJADORES
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryAmber, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.star, color: AppTheme.primaryAmber, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'CONSUMO DUEÑO',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryAmber,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _totalConsumoDueno.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const Text('Unidades consumidas', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.secondaryCyan, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.badge, color: AppTheme.secondaryCyan, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'TRABAJADORES',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.secondaryCyan,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _totalConsumoTrabajadores.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const Text('Unidades consumidas', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // FORMULARIO DE REGISTRO
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'REGISTRO DIFERENCIADO DE CONSUMO',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryAmber,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Selector Segmentado de Tipo: Dueño vs Trabajador
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'CONSUMO_DUENO',
                                label: Text('Consumo Dueño'),
                                icon: Icon(Icons.star_outline),
                              ),
                              ButtonSegment(
                                value: 'CONSUMO_TRABAJADOR',
                                label: Text('Trabajadores'),
                                icon: Icon(Icons.badge_outlined),
                              ),
                            ],
                            selected: {_tipoSeleccionado},
                            onSelectionChanged: (set) {
                              setState(() {
                                _tipoSeleccionado = set.first;
                                if (_tipoSeleccionado == 'CONSUMO_DUENO') {
                                  _beneficiarioController.text = 'Dueño / Administración';
                                } else {
                                  _beneficiarioController.clear();
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Selector Insumo
                          DropdownButtonFormField<InsumoInventario>(
                            initialValue: _insumoSeleccionado,
                            decoration: const InputDecoration(
                              labelText: 'Insumo / Bebida a Consumir *',
                              prefixIcon: Icon(Icons.local_bar, color: AppTheme.primaryAmber),
                            ),
                            items: _insumos.map((i) {
                              return DropdownMenuItem(
                                value: i,
                                child: Text('${i.nombre} (Stock: ${i.stockActual.toStringAsFixed(1)} ${i.unidadMedida})'),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _insumoSeleccionado = val),
                          ),
                          const SizedBox(height: 14),

                          // Cantidad y Beneficiario
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: TextFormField(
                                  controller: _cantidadController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Cantidad *',
                                    hintText: 'Ej. 1',
                                    suffixText: _insumoSeleccionado?.unidadMedida ?? '',
                                    prefixIcon: const Icon(Icons.calculate, color: AppTheme.secondaryCyan),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Requerido';
                                    final num? n = num.tryParse(val);
                                    if (n == null || n <= 0) return '> 0';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 6,
                                child: TextFormField(
                                  controller: _beneficiarioController,
                                  decoration: InputDecoration(
                                    labelText: _tipoSeleccionado == 'CONSUMO_DUENO'
                                        ? 'Nombre del Dueño/Mesa'
                                        : 'Nombre del Trabajador *',
                                    hintText: _tipoSeleccionado == 'CONSUMO_DUENO'
                                        ? 'Ej. Dueño / Invitados'
                                        : 'Ej. Juan (Bartender) / Pedro (Seguridad)',
                                    prefixIcon: const Icon(Icons.person, color: AppTheme.textMuted),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Ingrese beneficiario';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Motivo / Observaciones
                          TextFormField(
                            controller: _motivoController,
                            decoration: const InputDecoration(
                              labelText: 'Motivo / Detalle (opcional)',
                              hintText: 'Ej. Cena fin de turno / Prueba de cóctel',
                              prefixIcon: Icon(Icons.notes, color: AppTheme.textMuted),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Botón de Envío
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _tipoSeleccionado == 'CONSUMO_DUENO'
                                  ? AppTheme.primaryAmber
                                  : AppTheme.secondaryCyan,
                              foregroundColor: AppTheme.background,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.background),
                                  )
                                : const Icon(Icons.check, size: 20),
                            label: Text(
                              'REGISTRAR CONSUMO ATÓMICO',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            onPressed: _isSaving ? null : _guardarConsumoInterno,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // HISTORIAL DE CONSUMOS INTERNOS
                const Text(
                  'CONSUMOS RECIENTES REGISTRADOS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                if (_historialConsumos.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No hay consumos internos registrados',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    ),
                  )
                else
                  ..._historialConsumos.map((c) {
                    final esDueno = c.tipoMovimiento == 'CONSUMO_DUENO';
                    final colorBadge = esDueno ? AppTheme.primaryAmber : AppTheme.secondaryCyan;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorBadge.withValues(alpha: 0.15),
                          child: Icon(
                            esDueno ? Icons.star : Icons.badge,
                            color: colorBadge,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          c.insumoNombre ?? 'Insumo',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy HH:mm').format(c.fecha)}  •  ${c.beneficiarioOMotivo ?? ''}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        trailing: Text(
                          '-${c.cantidad.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colorBadge,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
