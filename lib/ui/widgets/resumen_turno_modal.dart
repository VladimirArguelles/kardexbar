import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/reporte_export_helper.dart';
import '../../providers/app_providers.dart';
import '../../services/comandas_service.dart';

class ResumenTurnoModal extends ConsumerStatefulWidget {
  const ResumenTurnoModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ResumenTurnoModal(),
      ),
    );
  }

  @override
  ConsumerState<ResumenTurnoModal> createState() => _ResumenTurnoModalState();
}

class _ResumenTurnoModalState extends ConsumerState<ResumenTurnoModal> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final fecha = ref.watch(resumenTurnoFechaProvider);
    final resumenAsync = ref.watch(resumenTurnoProvider);
    final size = MediaQuery.of(context).size;

    return Container(
      width: size.width > 900 ? 860 : size.width * 0.95,
      height: size.height * 0.90,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header del Modal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryAmber, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Resumen de Turno & Comandas de Barra',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Fecha de Auditoría: ${Formatters.date(fecha)}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: const Text('Fecha'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: fecha,
                          firstDate: DateTime(2025),
                          lastDate: DateTime.now(),
                          builder: (context, child) => Theme(
                            data: AppTheme.darkTheme,
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          ref.read(resumenTurnoFechaProvider.notifier).state = picked;
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textMuted),
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Contenido con datos del turno
          Expanded(
            child: resumenAsync.when(
              data: (data) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tarjetas KPI de resumen general
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricMini(
                              'Comandas',
                              '${data.totalComandas}',
                              Icons.confirmation_number_outlined,
                              AppTheme.secondaryCyan,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricMini(
                              'Despachos',
                              '${data.totalItemsDespachados.toStringAsFixed(0)} unds',
                              Icons.liquor_rounded,
                              AppTheme.infoViolet,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricMini(
                              'Total Vendido',
                              Formatters.currency(data.totalRecaudado),
                              Icons.attach_money_rounded,
                              AppTheme.successMint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Tablas clasificadas por categoría
                      _buildCategoriaSection('Cócteles', data.itemsPorCategoria['Cocteles'] ?? []),
                      const SizedBox(height: 20),
                      _buildCategoriaSection('Jugos & Sin Alcohol', data.itemsPorCategoria['Jugos'] ?? []),
                      const SizedBox(height: 20),
                      _buildCategoriaSection('Cervezas', data.itemsPorCategoria['Cervezas'] ?? []),
                      const SizedBox(height: 20),
                      _buildCategoriaSection('Otros Insumos / Servicios', data.itemsPorCategoria['Otros'] ?? []),
                    ],
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryAmber),
              ),
              error: (err, _) => Center(
                child: Text('Error al cargar resumen: $err', style: const TextStyle(color: AppTheme.errorCoral)),
              ),
            ),
          ),

          // Barra inferior con botones de Exportación
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border(top: BorderSide(color: AppTheme.borderLight)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
                resumenAsync.maybeWhen(
                  data: (data) => Wrap(
                    spacing: 12,
                    children: [
                      // Botón Exportar CSV / Excel
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.secondaryCyan,
                          side: const BorderSide(color: AppTheme.secondaryCyan),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: _isExporting
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                setState(() => _isExporting = true);
                                try {
                                  await ReporteExportHelper.exportarResumenCsv(data);
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Reporte CSV/Excel generado y listo para guardar'),
                                      backgroundColor: AppTheme.successMint,
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Error al exportar: $e'), backgroundColor: AppTheme.errorCoral),
                                  );
                                } finally {
                                  if (mounted) setState(() => _isExporting = false);
                                }
                              },
                        icon: const Icon(Icons.table_view_rounded, size: 18),
                        label: const Text('Exportar Excel/CSV'),
                      ),

                      // Botón Imprimir / Guardar PDF
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryAmber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        onPressed: _isExporting
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                setState(() => _isExporting = true);
                                try {
                                  await ReporteExportHelper.imprimirResumenPdf(data);
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Error al generar PDF: $e'), backgroundColor: AppTheme.errorCoral),
                                  );
                                } finally {
                                  if (mounted) setState(() => _isExporting = false);
                                }
                              },
                        icon: const Icon(Icons.print_rounded, size: 18, color: Colors.black),
                        label: const Text('Imprimir / Guardar PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricMini(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriaSection(String title, List<ItemResumenCategoria> items) {
    final subtotal = items.fold(0.0, (acc, it) => acc + it.totalRecaudado);
    final unidades = items.fold(0.0, (acc, it) => acc + it.cantidadTotal);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de categoría
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.category_rounded, size: 18, color: AppTheme.primaryAmber),
                    const SizedBox(width: 8),
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${unidades.toStringAsFixed(0)} unds  •  Subtotal: ${Formatters.currency(subtotal)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryCyan,
                  ),
                ),
              ],
            ),
          ),

          // Tabla de renglones
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No se registraron ventas en esta categoría durante el turno.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(color: AppTheme.borderLight, height: 1),
              itemBuilder: (context, idx) {
                final it = items[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          it.productoNombre,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${it.cantidadTotal.toStringAsFixed(0)} und',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          Formatters.currency(it.precioUnitario),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          Formatters.currency(it.totalRecaudado),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
