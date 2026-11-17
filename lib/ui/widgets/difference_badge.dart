import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/cierre_diario_model.dart';

class DifferenceBadge extends StatelessWidget {
  final double diferencia;
  final String unidadMedida;

  const DifferenceBadge({
    super.key,
    required this.diferencia,
    this.unidadMedida = 'UND',
  });

  @override
  Widget build(BuildContext context) {
    final tipo = TipoDiferencia.fromDiferencia(diferencia);

    Color color;
    Color bgColor;
    IconData icon;
    String prefix;

    switch (tipo) {
      case TipoDiferencia.faltante:
        color = AppTheme.errorCoral;
        bgColor = AppTheme.errorCoral.withValues(alpha: 0.15);
        icon = Icons.arrow_downward_rounded;
        prefix = '';
        break;
      case TipoDiferencia.sobrante:
        color = AppTheme.infoViolet;
        bgColor = AppTheme.infoViolet.withValues(alpha: 0.15);
        icon = Icons.arrow_upward_rounded;
        prefix = '+';
        break;
      case TipoDiferencia.exacto:
        color = AppTheme.successMint;
        bgColor = AppTheme.successMint.withValues(alpha: 0.15);
        icon = Icons.check_circle_outline_rounded;
        prefix = '';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$prefix${Formatters.number(diferencia)} $unidadMedida',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
