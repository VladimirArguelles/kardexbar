import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/comanda_model.dart';

/// Widget de Mesas / Cuentas Abiertas para el Bartender
/// Muestra las comandas en curso con opción de selección rápida para añadir rondas o cerrar cuenta.
class MesasAbiertasWidget extends StatelessWidget {
  final List<Comanda> comandasAbiertas;
  final Comanda? comandaSeleccionada;
  final bool isLoading;
  final ValueChanged<Comanda> onSelectComanda;
  final VoidCallback onNuevaComanda;
  final VoidCallback onRecargar;

  const MesasAbiertasWidget({
    super.key,
    required this.comandasAbiertas,
    required this.comandaSeleccionada,
    required this.isLoading,
    required this.onSelectComanda,
    required this.onNuevaComanda,
    required this.onRecargar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.table_restaurant,
                    color: AppTheme.primaryAmber,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'MESAS / CUENTAS ABIERTAS (${comandasAbiertas.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryAmber,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (comandaSeleccionada != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(
                        Icons.add,
                        size: 16,
                        color: AppTheme.secondaryCyan,
                      ),
                      label: const Text(
                        'NUEVA CUENTA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryCyan,
                        ),
                      ),
                      onPressed: onNuevaComanda,
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      size: 18,
                      color: AppTheme.textMuted,
                    ),
                    tooltip: 'Actualizar mesas abiertas',
                    visualDensity: VisualDensity.compact,
                    onPressed: onRecargar,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const SizedBox(
              height: 60,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (comandasAbiertas.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No hay cuentas abiertas. Al pulsar "DESPACHAR", el pedido quedará abierto aquí para agregar más rondas.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: comandasAbiertas.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final cmd = comandasAbiertas[index];
                  final isSelected = comandaSeleccionada?.id == cmd.id;

                  return InkWell(
                    onTap: () => onSelectComanda(cmd),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryAmber.withValues(alpha: 0.15)
                            : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryAmber
                              : AppTheme.borderLight,
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text(
                                cmd.mesa.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? AppTheme.primaryAmber
                                      : AppTheme.secondaryCyan,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryAmber.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Ronda ${cmd.ronda}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryAmber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cmd.nombreCliente,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total: \$${cmd.precioTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.successMint,
                            ),
                          ),
                        ],
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
