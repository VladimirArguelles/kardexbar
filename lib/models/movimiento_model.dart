import 'presentacion_model.dart';

enum TipoOperacionVenta {
  venta('VENTA', 'Venta Estándar'),
  cortesia('CORTESIA', 'Cortesía de la Casa'),
  consumoInterno('CONSUMO_INTERNO', 'Consumo Interno'),
  promocion('PROMOCION', 'Promoción / 2x1');

  final String dbValue;
  final String label;
  const TipoOperacionVenta(this.dbValue, this.label);

  static TipoOperacionVenta fromString(String? value) {
    return TipoOperacionVenta.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => TipoOperacionVenta.venta,
    );
  }
}

enum MetodoPago {
  efectivoUsd('EFECTIVO_USD', 'Efectivo USD (\$)'),
  efectivoBs('EFECTIVO_BS', 'Efectivo Bolívares (Bs)'),
  pagoMovil('PAGO_MOVIL', 'Pago Móvil'),
  puntoVenta('PUNTO_VENTA', 'Punto de Venta (Tarjeta)'),
  zelle('ZELLE', 'Zelle'),
  mixto('MIXTO', 'Pago Mixto / Múltiple'),
  otro('OTRO', 'Otro');

  final String dbValue;
  final String label;
  const MetodoPago(this.dbValue, this.label);

  static MetodoPago fromString(String? value) {
    return MetodoPago.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => MetodoPago.efectivoUsd,
    );
  }
}

enum EstadoMovimiento {
  confirmado('CONFIRMADO', 'Confirmado'),
  pendiente('PENDIENTE', 'Pendiente'),
  anulado('ANULADO', 'Anulado');

  final String dbValue;
  final String label;
  const EstadoMovimiento(this.dbValue, this.label);

  static EstadoMovimiento fromString(String? value) {
    return EstadoMovimiento.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => EstadoMovimiento.confirmado,
    );
  }
}

class DetalleMovimiento {
  final String? id;
  final String presentacionId;
  final String presentacionNombre;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;
  final String? notas;

  DetalleMovimiento({
    this.id,
    required this.presentacionId,
    required this.presentacionNombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    this.notas,
  });

  factory DetalleMovimiento.fromJson(Map<String, dynamic> json) {
    return DetalleMovimiento(
      id: json['id'] as String?,
      presentacionId: json['presentacion_id'] as String,
      presentacionNombre: json['presentaciones_venta'] != null
          ? (json['presentaciones_venta']['nombre'] as String? ?? 'Producto')
          : (json['presentacion_nombre'] as String? ?? 'Producto'),
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 1.0,
      precioUnitario: (json['precio_unitario'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      notas: json['notas'] as String?,
    );
  }

  Map<String, dynamic> toJson(String movimientoId) {
    return {
      if (id != null) 'id': id,
      'movimiento_id': movimientoId,
      'presentacion_id': presentacionId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'subtotal': subtotal,
      'notas': notas,
    };
  }
}

class Movimiento {
  final String id;
  final String numeroTicket;
  final DateTime fechaOperacion;
  final TipoOperacionVenta tipoOperacion;
  final CanalVenta canal;
  final EstadoMovimiento estado;
  final MetodoPago metodoPago;
  final double subtotal;
  final double descuento;
  final double total;
  final String? clienteNombre;
  final String? notas;
  final String? usuarioId;
  final List<DetalleMovimiento> detalles;

  Movimiento({
    required this.id,
    required this.numeroTicket,
    required this.fechaOperacion,
    required this.tipoOperacion,
    required this.canal,
    required this.estado,
    required this.metodoPago,
    required this.subtotal,
    required this.descuento,
    required this.total,
    this.clienteNombre,
    this.notas,
    this.usuarioId,
    this.detalles = const [],
  });

  factory Movimiento.fromJson(Map<String, dynamic> json) {
    List<DetalleMovimiento> dList = [];
    if (json['detalle_movimientos'] is List) {
      dList = (json['detalle_movimientos'] as List)
          .map((e) => DetalleMovimiento.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Movimiento(
      id: json['id'] as String,
      numeroTicket: json['numero_ticket'] as String? ?? 'S/N',
      fechaOperacion: json['fecha_operacion'] != null
          ? DateTime.parse(json['fecha_operacion'] as String)
          : DateTime.now(),
      tipoOperacion:
          TipoOperacionVenta.fromString(json['tipo_operacion'] as String?),
      canal: CanalVenta.fromString(json['canal'] as String?),
      estado: EstadoMovimiento.fromString(json['estado'] as String?),
      metodoPago: MetodoPago.fromString(json['metodo_pago'] as String?),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      descuento: (json['descuento'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      clienteNombre: json['cliente_nombre'] as String?,
      notas: json['notas'] as String?,
      usuarioId: json['usuario_id'] as String?,
      detalles: dList,
    );
  }
}
