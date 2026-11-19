import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/presentacion_model.dart';

class ProductCard extends StatelessWidget {
  final PresentacionVenta presentacion;
  final int countInCart;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;
  final VoidCallback? onEditPrice;

  const ProductCard({
    super.key,
    required this.presentacion,
    this.countInCart = 0,
    required this.onAdd,
    this.onRemove,
    this.onEditPrice,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = countInCart > 0;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.surfaceHighlight : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppTheme.primaryAmber : AppTheme.borderLight,
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: AppTheme.primaryAmber.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Cabecera: Categoría y Canal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        presentacion.categoria.label,
                        style: const TextStyle(
                          color: AppTheme.secondaryCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (presentacion.canalVenta != CanalVenta.barra)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.infoViolet.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          presentacion.canalVenta.label,
                          style: const TextStyle(
                            color: AppTheme.infoViolet,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Nombre y Código
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      presentacion.nombre,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      presentacion.codigo,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),

                // Desconsolidación / Receta
                if (presentacion.equivalencias.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.layers_outlined, size: 12, color: AppTheme.primaryOrange),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            presentacion.equivalencias.map((e) {
                              return '${Formatters.number(e.factorUnidadesU)}x ${e.producto?.nombre ?? 'Insumo'}';
                            }).join(', '),
                            style: const TextStyle(
                              color: AppTheme.primaryOrange,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 6),

                // Precio y Botón de Acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Formatters.currency(presentacion.precioVigente),
                          style: const TextStyle(
                            color: AppTheme.primaryAmber,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (onEditPrice != null) ...[
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: onEditPrice,
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(Icons.edit, size: 14, color: AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isSelected)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.surfaceVariant,
                            ),
                            icon: const Icon(Icons.remove, color: AppTheme.textPrimary),
                            onPressed: onRemove,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '$countInCart',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryAmber,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.primaryAmber,
                            ),
                            icon: const Icon(Icons.add, color: Colors.black),
                            onPressed: onAdd,
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add_shopping_cart_rounded,
                          size: 16,
                          color: AppTheme.primaryAmber,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
