import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/app_providers.dart';
import '../widgets/metric_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ultimasVentasAsync = ref.watch(ultimasVentasProvider);
    final productosAsync = ref.watch(inventarioProductosProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bienvenida y Estado del Sistema
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Panel de Control KardexBar',
                        style: Theme.of(context).textTheme.headlineMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Monitoreo en vivo de ventas, kardex y barra',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tarjetas KPI Principales
            ultimasVentasAsync.when(
              data: (ventas) {
                final double totalVendido =
                    ventas.fold(0.0, (acc, item) => acc + item.total);

                return productosAsync.when(
                  data: (productos) {
                    final int bajoMinimo =
                        productos.where((p) => p.requiereReabastecimiento).length;

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 750;

                        final cardVentas = MetricCard(
                          title: 'Ventas Recientes',
                          value: Formatters.currency(totalVendido),
                          subtitle: '${ventas.length} comandas procesadas',
                          icon: Icons.attach_money_rounded,
                          accentColor: AppTheme.primaryAmber,
                        );
                        final cardComandas = MetricCard(
                          title: 'Comandas Confirmadas',
                          value: '${ventas.length}',
                          subtitle: 'Despachos de barra',
                          icon: Icons.receipt_long_rounded,
                          accentColor: AppTheme.secondaryCyan,
                        );
                        final cardInsumos = MetricCard(
                          title: 'Insumos en Barra',
                          value: '${productos.length}',
                          subtitle: 'Catálogo inventariable',
                          icon: Icons.liquor_rounded,
                          accentColor: AppTheme.infoViolet,
                        );
                        final cardStock = MetricCard(
                          title: 'Stock Crítico',
                          value: '$bajoMinimo',
                          subtitle: bajoMinimo > 0 ? 'Requiere surtido urgente' : 'Niveles óptimos',
                          icon: Icons.warning_amber_rounded,
                          accentColor: bajoMinimo > 0 ? AppTheme.errorCoral : AppTheme.successMint,
                        );

                        if (isCompact) {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: cardVentas),
                                  const SizedBox(width: 12),
                                  Expanded(child: cardComandas),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: cardInsumos),
                                  const SizedBox(width: 12),
                                  Expanded(child: cardStock),
                                ],
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: cardVentas),
                            const SizedBox(width: 14),
                            Expanded(child: cardComandas),
                            const SizedBox(width: 14),
                            Expanded(child: cardInsumos),
                            const SizedBox(width: 14),
                            Expanded(child: cardStock),
                          ],
                        );
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(color: AppTheme.primaryAmber),
                  error: (_, _) => const SizedBox(),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryAmber),
              ),
              error: (err, _) => Text('Error: $err', style: const TextStyle(color: AppTheme.errorCoral)),
            ),

            const SizedBox(height: 32),

            // Registro de Últimas Comandas y Despachos
            Text(
              'Últimos Despachos y Comandas de Barra',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            ultimasVentasAsync.when(
              data: (ventas) {
                if (ventas.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: const [
                            Icon(Icons.point_of_sale, size: 48, color: AppTheme.textMuted),
                            SizedBox(height: 12),
                            Text(
                              'Aún no hay comandas registradas en la jornada.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ventas.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: AppTheme.borderLight, height: 1),
                    itemBuilder: (context, idx) {
                      final mov = ventas[idx];

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.receipt_rounded, color: AppTheme.primaryAmber, size: 22),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                mov.numeroTicket,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                mov.canal.label,
                                style: const TextStyle(
                                  color: AppTheme.secondaryCyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${Formatters.dateTime(mov.fechaOperacion)} • Pago: ${mov.metodoPago.label}',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          Formatters.currency(mov.total),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryAmber,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryAmber),
              ),
              error: (err, _) => Text('Error: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
