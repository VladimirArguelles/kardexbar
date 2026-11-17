import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/cierre_diario_model.dart';
import '../../providers/app_providers.dart';
import '../widgets/difference_badge.dart';
import '../widgets/metric_card.dart';

class CierreScreen extends ConsumerStatefulWidget {
  const CierreScreen({super.key});

  @override
  ConsumerState<CierreScreen> createState() => _CierreScreenState();
}

class _CierreScreenState extends ConsumerState<CierreScreen> {
  final Map<String, TextEditingController> _conteoControllers = {};
  bool _isSaving = false;
  String _observaciones = '';

  @override
  void dispose() {
    for (var c in _conteoControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardarCierre(List<CierreDiarioItem> items) async {
    setState(() => _isSaving = true);
    final fecha = ref.read(fechaCierreSeleccionadaProvider);

    try {
      // Sincronizar conteos desde los controladores de texto
      for (var it in items) {
        if (_conteoControllers.containsKey(it.productoId)) {
          final text = _conteoControllers[it.productoId]!.text.replaceAll(',', '.');
          it.conteoFisico = double.tryParse(text) ?? it.stockTeorico;
        }
      }

      final cierreService = ref.read(cierreServiceProvider);
      await cierreService.registrarConteoYCerrar(
        fecha: fecha,
        items: items,
        observaciones: _observaciones.isNotEmpty ? _observaciones : null,
      );

      ref.invalidate(arqueoCierreProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Arqueo y Cierre Diario guardado con éxito en Supabase!'),
          backgroundColor: AppTheme.successMint,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar cierre: $e'),
          backgroundColor: AppTheme.errorCoral,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fecha = ref.watch(fechaCierreSeleccionadaProvider);
    final cierreAsync = ref.watch(arqueoCierreProvider);

    return Scaffold(
      body: Column(
        children: [
          // Header de Selección de Fecha y Acciones
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: AppTheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calculate_outlined, color: AppTheme.primaryAmber, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cierre y Arqueo Diario de Barra',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Fecha de Cuadre: ${Formatters.date(fecha)}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: const Text('Cambiar Fecha'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: fecha,
                          firstDate: DateTime(2025),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: AppTheme.darkTheme,
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          ref.read(fechaCierreSeleccionadaProvider.notifier).state = picked;
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppTheme.primaryAmber),
                      onPressed: () => ref.invalidate(arqueoCierreProvider),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Contenido Principal
          Expanded(
            child: cierreAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay productos configurados para el arqueo.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  );
                }

                // Inicializar controladores de texto si no están creados
                for (var it in items) {
                  if (!_conteoControllers.containsKey(it.productoId)) {
                    _conteoControllers[it.productoId] = TextEditingController(
                      text: it.conteoFisico > 0
                          ? Formatters.number(it.conteoFisico)
                          : Formatters.number(it.stockTeorico),
                    );
                  }
                }

                final faltantes = items.where((i) => i.tipoDiferencia == TipoDiferencia.faltante).length;
                final exactos = items.where((i) => i.tipoDiferencia == TipoDiferencia.exacto).length;
                final sobrantes = items.where((i) => i.tipoDiferencia == TipoDiferencia.sobrante).length;

                return Column(
                  children: [
                    // Resumen de Métricas de Cuadre
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: MetricCard(
                              title: 'Total Insumos',
                              value: '${items.length}',
                              subtitle: 'Productos auditados',
                              icon: Icons.checklist_rtl_rounded,
                              accentColor: AppTheme.secondaryCyan,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MetricCard(
                              title: 'Cuadre Exacto',
                              value: '$exactos',
                              subtitle: 'Sin discrepancias',
                              icon: Icons.check_circle_outline,
                              accentColor: AppTheme.successMint,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MetricCard(
                              title: 'Faltantes',
                              value: '$faltantes',
                              subtitle: 'Requiere justificación',
                              icon: Icons.arrow_downward_rounded,
                              accentColor: AppTheme.errorCoral,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MetricCard(
                              title: 'Sobrantes',
                              value: '$sobrantes',
                              subtitle: 'Exceso en barra',
                              icon: Icons.arrow_upward_rounded,
                              accentColor: AppTheme.infoViolet,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tabla de Arqueo Detallada
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(AppTheme.surfaceVariant),
                              columns: const [
                                DataColumn(label: Text('Producto / Insumo', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Stock Inicial', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                DataColumn(label: Text('Surtido (+)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                DataColumn(label: Text('Ventas (-)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                DataColumn(label: Text('Stock Teórico', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryCyan)), numeric: true),
                                DataColumn(label: Text('Conteo Físico', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryAmber))),
                                DataColumn(label: Text('Diferencia', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: items.map((it) {
                                final ctrl = _conteoControllers[it.productoId]!;
                                final diff = it.diferencia;

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            it.nombreProducto,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            '${it.codigoProducto} • ${it.categoria.label}',
                                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(Formatters.number(it.stockInicial))),
                                    DataCell(Text('+ ${Formatters.number(it.surtidoDia)}', style: const TextStyle(color: AppTheme.successMint))),
                                    DataCell(Text('- ${Formatters.number(it.ventasSalidasDia)}', style: const TextStyle(color: AppTheme.errorCoral))),
                                    DataCell(
                                      Text(
                                        '${Formatters.number(it.stockTeorico)} ${it.unidadMedida}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryCyan),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 100,
                                        child: TextField(
                                          controller: ctrl,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          textAlign: TextAlign.center,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            suffixText: it.unidadMedida,
                                            suffixStyle: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                          ),
                                          onChanged: (val) {
                                            final double? nuevo = double.tryParse(val.replaceAll(',', '.'));
                                            if (nuevo != null) {
                                              setState(() {
                                                it.conteoFisico = nuevo;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      DifferenceBadge(
                                        diferencia: diff,
                                        unidadMedida: it.unidadMedida,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Barra Inferior de Confirmación y Cierre
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppTheme.surface,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Observaciones del cierre (opcional: personal de turno, incidentes)...',
                                prefixIcon: Icon(Icons.note_alt_outlined),
                              ),
                              onChanged: (val) => _observaciones = val,
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryAmber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                            onPressed: _isSaving ? null : () => _guardarCierre(items),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Icon(Icons.lock_clock_rounded, color: Colors.black),
                            label: Text(
                              _isSaving ? 'GUARDANDO CIERRE...' : 'FINALIZAR Y CERRAR TURNO',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryAmber),
              ),
              error: (err, _) => Center(
                child: Text('Error al cargar arqueo: $err', style: const TextStyle(color: AppTheme.errorCoral)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
