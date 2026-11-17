import 'producto_model.dart';

enum TipoDiferencia {
  faltante('FALTANTE', 'Faltante en Barra'),
  sobrante('SOBRANTE', 'Sobrante en Barra'),
  exacto('EXACTO', 'Cuadre Exacto');

  final String dbValue;
  final String label;
  const TipoDiferencia(this.dbValue, this.label);

  static TipoDiferencia fromDiferencia(double diff) {
    if (diff < -0.01) return TipoDiferencia.faltante;
    if (diff > 0.01) return TipoDiferencia.sobrante;
    return TipoDiferencia.exacto;
  }
}

class CierreDiarioItem {
  final String cierreId;
  final String fecha;
  final String productoId;
  final String codigoProducto;
  final String nombreProducto;
  final CategoriaProducto categoria;
  final String unidadMedida;
  final double stockInicial;
  final double surtidoDia;
  final double ventasSalidasDia;
  final double stockTeorico;
  double conteoFisico;
  double get diferencia => conteoFisico - stockTeorico;
  final bool cerrado;

  CierreDiarioItem({
    required this.cierreId,
    required this.fecha,
    required this.productoId,
    required this.codigoProducto,
    required this.nombreProducto,
    required this.categoria,
    required this.unidadMedida,
    required this.stockInicial,
    required this.surtidoDia,
    required this.ventasSalidasDia,
    required this.stockTeorico,
    required this.conteoFisico,
    required this.cerrado,
  });

  TipoDiferencia get tipoDiferencia => TipoDiferencia.fromDiferencia(diferencia);

  factory CierreDiarioItem.fromJson(Map<String, dynamic> json) {
    return CierreDiarioItem(
      cierreId: (json['cierre_id'] ?? json['id'] ?? '') as String,
      fecha: json['fecha']?.toString() ?? '',
      productoId: json['producto_id'] as String? ?? '',
      codigoProducto: json['codigo_producto'] as String? ?? '',
      nombreProducto: (json['nombre_producto'] ?? json['nombre'] ?? '') as String,
      categoria: CategoriaProducto.fromString(json['categoria'] as String?),
      unidadMedida: json['unidad_medida'] as String? ?? 'UND',
      stockInicial: (json['stock_inicial'] as num?)?.toDouble() ?? 0.0,
      surtidoDia: (json['surtido_dia'] as num?)?.toDouble() ?? 0.0,
      ventasSalidasDia: (json['ventas_salidas_dia'] as num?)?.toDouble() ?? 0.0,
      stockTeorico: (json['stock_teorico'] as num?)?.toDouble() ?? 0.0,
      conteoFisico: (json['conteo_fisico'] as num?)?.toDouble() ?? 0.0,
      cerrado: json['cerrado'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toConteoJson() {
    return {
      'producto_id': productoId,
      'conteo_fisico': conteoFisico,
    };
  }
}
