enum CategoriaProducto {
  cerveza('CERVEZA', 'Cervezas'),
  licor('LICOR', 'Licores & Destilados'),
  coctel('COCTEL', 'Cócteles de Autor'),
  bebidaNoAlcoholica('BEBIDA_NO_ALCOHOLICA', 'Sin Alcohol & Jugos'),
  servicio('SERVICIO', 'Servicios & Descorche'),
  snack('SNACK', 'Snacks'),
  otro('OTRO', 'Otros');

  final String dbValue;
  final String label;
  const CategoriaProducto(this.dbValue, this.label);

  static CategoriaProducto fromString(String? value) {
    return CategoriaProducto.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => CategoriaProducto.otro,
    );
  }
}

class Producto {
  final String id;
  final String codigo;
  final String nombre;
  final String? descripcion;
  final CategoriaProducto categoria;
  final String unidadMedida;
  final double costoUnitario;
  final bool esInventariable;
  final double stockActual;
  final double stockMinimo;
  final bool activo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Producto({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.descripcion,
    required this.categoria,
    required this.unidadMedida,
    required this.costoUnitario,
    required this.esInventariable,
    required this.stockActual,
    required this.stockMinimo,
    required this.activo,
    this.createdAt,
    this.updatedAt,
  });

  bool get requiereReabastecimiento =>
      esInventariable && stockActual <= stockMinimo;

  double get porcentajeStock =>
      stockMinimo > 0 ? (stockActual / stockMinimo).clamp(0.0, 2.0) : 1.0;

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: json['id'] as String,
      codigo: json['codigo'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      categoria: CategoriaProducto.fromString(json['categoria'] as String?),
      unidadMedida: json['unidad_medida'] as String? ?? 'UND',
      costoUnitario: (json['costo_unitario'] as num?)?.toDouble() ?? 0.0,
      esInventariable: json['es_inventariable'] as bool? ?? true,
      stockActual: (json['stock_actual'] as num?)?.toDouble() ?? 0.0,
      stockMinimo: (json['stock_minimo'] as num?)?.toDouble() ?? 0.0,
      activo: json['activo'] as bool? ?? true,
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
      'codigo': codigo,
      'nombre': nombre,
      'descripcion': descripcion,
      'categoria': categoria.dbValue,
      'unidad_medida': unidadMedida,
      'costo_unitario': costoUnitario,
      'es_inventariable': esInventariable,
      'stock_actual': stockActual,
      'stock_minimo': stockMinimo,
      'activo': activo,
    };
  }
}
