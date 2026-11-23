/// Modelo de Insumo de Inventario Físico por Sede
class InsumoInventario {
  final String id;
  final String sedeId;
  final String nombre;
  final String unidadMedida;
  final double stockActual;
  final double stockMinimo;
  final double costoUnitario;

  InsumoInventario({
    required this.id,
    required this.sedeId,
    required this.nombre,
    required this.unidadMedida,
    required this.stockActual,
    required this.stockMinimo,
    required this.costoUnitario,
  });

  bool get isAgotado => stockActual <= 0;
  bool get isMinimo => stockActual > 0 && stockActual <= stockMinimo;
  bool get isOptimo => stockActual > stockMinimo;

  String get estadoAlerta {
    if (isAgotado) return 'AGOTADO';
    if (isMinimo) return 'BAJO';
    return 'ÓPTIMO';
  }

  factory InsumoInventario.fromJson(Map<String, dynamic> json) {
    return InsumoInventario(
      id: json['id'] as String,
      sedeId: json['sede_id'] as String? ?? '',
      nombre: json['nombre'] as String? ?? 'Sin nombre',
      unidadMedida: json['unidad_medida'] as String? ?? 'unidad',
      stockActual:
          double.tryParse(json['stock_actual']?.toString() ?? '0') ?? 0.0,
      stockMinimo:
          double.tryParse(json['stock_minimo']?.toString() ?? '5') ?? 5.0,
      costoUnitario:
          double.tryParse(json['costo_unitario']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sede_id': sedeId,
      'nombre': nombre,
      'unidad_medida': unidadMedida,
      'stock_actual': stockActual,
      'stock_minimo': stockMinimo,
      'costo_unitario': costoUnitario,
    };
  }
}
