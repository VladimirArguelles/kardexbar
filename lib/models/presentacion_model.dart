import 'producto_model.dart';

enum CanalVenta {
  barra('BARRA', 'Barra Principal'),
  mesa('MESA', 'Salón / Mesas'),
  reservacion('RESERVACION', 'Reservaciones'),
  evento('EVENTO', 'Eventos Especiales'),
  vip('VIP', 'Zona VIP');

  final String dbValue;
  final String label;
  const CanalVenta(this.dbValue, this.label);

  static CanalVenta fromString(String? value) {
    return CanalVenta.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => CanalVenta.barra,
    );
  }
}

class RecetaEquivalencia {
  final String id;
  final String presentacionId;
  final String productoId;
  final double factorUnidadesU;
  final bool esIngredientePrincipal;
  final String? notas;
  final Producto? producto;

  RecetaEquivalencia({
    required this.id,
    required this.presentacionId,
    required this.productoId,
    required this.factorUnidadesU,
    required this.esIngredientePrincipal,
    this.notas,
    this.producto,
  });

  factory RecetaEquivalencia.fromJson(Map<String, dynamic> json) {
    return RecetaEquivalencia(
      id: json['id'] as String,
      presentacionId: json['presentacion_id'] as String,
      productoId: json['producto_id'] as String,
      factorUnidadesU: (json['factor_unidades_u'] as num?)?.toDouble() ?? 1.0,
      esIngredientePrincipal: json['es_ingrediente_principal'] as bool? ?? true,
      notas: json['notas'] as String?,
      producto: json['productos'] != null
          ? Producto.fromJson(json['productos'] as Map<String, dynamic>)
          : null,
    );
  }
}

class PresentacionVenta {
  final String id;
  final String codigo;
  final String nombre;
  final String? descripcion;
  final CategoriaProducto categoria;
  final CanalVenta canalVenta;
  final bool activo;
  final double precioVigente;
  final List<RecetaEquivalencia> equivalencias;

  PresentacionVenta({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.descripcion,
    required this.categoria,
    required this.canalVenta,
    required this.activo,
    this.precioVigente = 0.0,
    this.equivalencias = const [],
  });

  factory PresentacionVenta.fromJson(Map<String, dynamic> json) {
    // Si viene de la vista_precios_vigentes
    final precio = (json['precio_unitario'] as num?)?.toDouble() ?? 0.0;

    List<RecetaEquivalencia> eqList = [];
    if (json['recetas_equivalencias'] is List) {
      eqList = (json['recetas_equivalencias'] as List)
          .map((e) => RecetaEquivalencia.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return PresentacionVenta(
      id: (json['presentacion_id'] ?? json['id']) as String,
      codigo: json['codigo'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      categoria: CategoriaProducto.fromString(json['categoria'] as String?),
      canalVenta: CanalVenta.fromString(json['canal_venta'] as String?),
      activo: json['activo'] as bool? ?? true,
      precioVigente: precio,
      equivalencias: eqList,
    );
  }

  PresentacionVenta copyWith({
    double? precioVigente,
    List<RecetaEquivalencia>? equivalencias,
  }) {
    return PresentacionVenta(
      id: id,
      codigo: codigo,
      nombre: nombre,
      descripcion: descripcion,
      categoria: categoria,
      canalVenta: canalVenta,
      activo: activo,
      precioVigente: precioVigente ?? this.precioVigente,
      equivalencias: equivalencias ?? this.equivalencias,
    );
  }
}
