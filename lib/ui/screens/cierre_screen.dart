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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.surface,
            child: Row(
              children: [
                const Icon(Icons.calculate_outlined, color: AppTheme.primaryAmber, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Cierre y Arqueo Diario',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        Formatters.date(fecha),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.calendar_today, size: 15),
                      label: Text(
                        '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
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
                    const SizedBox(width: 6),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.refresh, color: AppTheme.primaryAmber, size: 20),
                      tooltip: 'Actualizar arqueo',
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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 700;
                          final c1 = MetricCard(
                            title: 'Total Insumos',
                            value: '${items.length}',
                            subtitle: 'Productos auditados',
                            icon: Icons.checklist_rtl_rounded,
                            accentColor: AppTheme.secondaryCyan,
                          );
                          final c2 = MetricCard(
                            title: 'Cuadre Exacto',
                            value: '$exactos',
                            subtitle: 'Sin discrepancias',
                            icon: Icons.check_circle_outline,
                            accentColor: AppTheme.successMint,
                          );
                          final c3 = MetricCard(
                            title: 'Faltantes',
                            value: '$faltantes',
                            subtitle: 'Requiere justificación',
                            icon: Icons.arrow_downward_rounded,
                            accentColor: AppTheme.errorCoral,
                          );
                          final c4 = MetricCard(
                            title: 'Sobrantes',
                            value: '$sobrantes',
                            subtitle: 'Exceso en barra',
                            icon: Icons.arrow_upward_rounded,
                            accentColor: AppTheme.infoViolet,
                          );

                          if (isCompact) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: c1),
                                    const SizedBox(width: 10),
                                    Expanded(child: c2),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: c3),
                                    const SizedBox(width: 10),
                                    Expanded(child: c4),
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: c1),
                              const SizedBox(width: 12),
                              Expanded(child: c2),
                              const SizedBox(width: 12),
                              Expanded(child: c3),
                              const SizedBox(width: 12),
                              Expanded(child: c4),
                            ],
                          );
                        },
                      ),
                    ),

                    // Lista de Arqueo Detallada sin desbordes ni solapamientos
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          return _buildAuditoriaItem(items[idx]);
                        },
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

  Widget _buildMetricSnippet(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAuditoriaItem(CierreDiarioItem it) {
    final ctrl = _conteoControllers[it.productoId]!;
    final diff = it.diferencia;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: Nombre del producto (Expanded, negrita, max 2 líneas) + Diferencia Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      it.nombreProducto,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${it.codigoProducto} • ${it.categoria.label}',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DifferenceBadge(
                diferencia: diff,
                unidadMedida: it.unidadMedida,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppTheme.borderLight, height: 1),
          const SizedBox(height: 10),
          // Fila 2: Columnas numéricas alineadas a la derecha y campo de conteo físico
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Teórico', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                      Text(
                        '${Formatters.number(it.stockTeorico)} ${it.unidadMedida}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryCyan,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  _buildMetricSnippet('Inicial', Formatters.number(it.stockInicial)),
                  _buildMetricSnippet('Surtido', '+${Formatters.number(it.surtidoDia)}', color: AppTheme.successMint),
                  _buildMetricSnippet('Ventas', '-${Formatters.number(it.ventasSalidasDia)}', color: AppTheme.errorCoral),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Físico: ',
                    style: TextStyle(color: AppTheme.primaryAmber, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    width: 95,
                    child: TextField(
                      controller: ctrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
