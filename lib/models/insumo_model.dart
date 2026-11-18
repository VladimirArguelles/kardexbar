class Insumo {
  final String id;
  final String nombre;
  final String unidadMedida; // 'ml', 'unidad', 'gr'
  final double stockActual;
  final double stockMinimo;
  final bool agotado;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Insumo({
    required this.id,
    required this.nombre,
    required this.unidadMedida,
    required this.stockActual,
    required this.stockMinimo,
    required this.agotado,
    this.createdAt,
    this.updatedAt,
  });

  bool get estaAgotado => agotado || stockActual <= 0;

  bool get requiereReabastecimiento =>
      !estaAgotado && stockMinimo > 0 && stockActual <= stockMinimo;

  double get porcentajeStock =>
      stockMinimo > 0 ? (stockActual / stockMinimo).clamp(0.0, 2.0) : 1.0;

  factory Insumo.fromJson(Map<String, dynamic> json) {
    final double stock = (json['stock_actual'] as num?)?.toDouble() ?? 0.0;
    final bool isAgotado = json['agotado'] as bool? ?? (stock <= 0);

    return Insumo(
      id: json['id'] as String,
      nombre: json['nombre'] as String? ?? '',
      unidadMedida: json['unidad_medida'] as String? ?? 'unidad',
      stockActual: stock,
      stockMinimo: (json['stock_minimo'] as num?)?.toDouble() ?? 10.0,
      agotado: isAgotado,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'unidad_medida': unidadMedida,
      'stock_actual': stockActual,
      'stock_minimo': stockMinimo,
      'agotado': agotado,
    };
  }

  Insumo copyWith({
    String? id,
    String? nombre,
    String? unidadMedida,
    double? stockActual,
    double? stockMinimo,
    bool? agotado,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Insumo(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      unidadMedida: unidadMedida ?? this.unidadMedida,
      stockActual: stockActual ?? this.stockActual,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      agotado: agotado ?? this.agotado,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
