class DetalleComanda {
  final String id;
  final String comandaId;
  final String productoId;
  final String productoNombre;
  final String categoriaClasificada; // 'Cocteles', 'Jugos', 'Cervezas', 'Otros'
  final double cantidad;
  final double precioUnitario;
  final double total;

  DetalleComanda({
    required this.id,
    required this.comandaId,
    required this.productoId,
    required this.productoNombre,
    required this.categoriaClasificada,
    required this.cantidad,
    required this.precioUnitario,
    required this.total,
  });

  factory DetalleComanda.fromJson(Map<String, dynamic> json) {
    return DetalleComanda(
      id: json['id'] as String,
      comandaId: json['comanda_id'] as String? ?? '',
      productoId: json['producto_id'] as String? ?? '',
      productoNombre: json['productos'] != null
          ? (json['productos']['nombre'] as String? ?? 'Producto')
          : (json['producto_nombre'] as String? ?? 'Producto'),
      categoriaClasificada:
          json['categoria_clasificada'] as String? ?? 'Otros',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 1.0,
      precioUnitario: (json['precio_unitario'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'comanda_id': comandaId,
      'producto_id': productoId,
      'categoria_clasificada': categoriaClasificada,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'total': total,
    };
  }
}

class VentaComanda {
  final String id;
  final String numeroTicketCaja;
  final DateTime fecha;
  final double total;
  final String estado;
  final String? clienteNombre;
  final String? notas;
  final List<DetalleComanda> detalles;

  VentaComanda({
    required this.id,
    required this.numeroTicketCaja,
    required this.fecha,
    required this.total,
    required this.estado,
    this.clienteNombre,
    this.notas,
    this.detalles = const [],
  });

  factory VentaComanda.fromJson(Map<String, dynamic> json) {
    List<DetalleComanda> items = [];
    if (json['detalle_comandas'] is List) {
      items = (json['detalle_comandas'] as List)
          .map((e) => DetalleComanda.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return VentaComanda(
      id: json['id'] as String,
      numeroTicketCaja: json['numero_ticket_caja'] as String? ?? 'S/N',
      fecha: json['fecha'] != null
          ? DateTime.parse(json['fecha'] as String)
          : DateTime.now(),
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      estado: json['estado'] as String? ?? 'CONFIRMADO',
      clienteNombre: json['cliente_nombre'] as String?,
      notas: json['notas'] as String?,
      detalles: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numero_ticket_caja': numeroTicketCaja,
      'fecha': fecha.toIso8601String(),
      'total': total,
      'estado': estado,
      'cliente_nombre': clienteNombre,
      'notas': notas,
    };
  }
}
