/// Modelo de Producto de Barra
class ProductoBarra {
  final String id;
  final String nombre;
  final String categoria;
  final double precioVenta;
  final bool esReceta;
  final bool activo;

  ProductoBarra({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.precioVenta,
    this.esReceta = false,
    this.activo = true,
  });

  factory ProductoBarra.fromJson(Map<String, dynamic> json) {
    return ProductoBarra(
      id: json['id'] as String,
      nombre: json['nombre'] as String? ?? 'Sin nombre',
      categoria: json['categoria'] as String? ?? 'Otros',
      precioVenta:
          double.tryParse(json['precio_venta']?.toString() ?? '0') ?? 0.0,
      esReceta: json['es_receta'] == true,
      activo: json['activo'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'categoria': categoria,
      'precio_venta': precioVenta,
      'es_receta': esReceta,
      'activo': activo,
    };
  }
}

/// Modelo de Detalle de Comanda con cálculo automático de subtotal
class ComandaDetalle {
  final String? id;
  final String? comandaId;
  final String productoBarraId;
  final String nombreProducto;
  final double cantidad;
  final double precioUnitario;
  final int ronda;

  ComandaDetalle({
    this.id,
    this.comandaId,
    required this.productoBarraId,
    required this.nombreProducto,
    required this.cantidad,
    required this.precioUnitario,
    this.ronda = 1,
  });

  /// Cálculo exacto Cantidad * Precio
  double get subtotal => cantidad * precioUnitario;

  factory ComandaDetalle.fromJson(Map<String, dynamic> json) {
    return ComandaDetalle(
      id: json['id'] as String?,
      comandaId: json['comanda_id'] as String?,
      productoBarraId: json['producto_barra_id'] as String? ?? '',
      nombreProducto: json['nombre_producto'] as String? ?? '',
      cantidad: double.tryParse(json['cantidad']?.toString() ?? '1') ?? 1.0,
      precioUnitario:
          double.tryParse(json['precio_unitario']?.toString() ?? '0') ?? 0.0,
      ronda: int.tryParse(json['ronda']?.toString() ?? '1') ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (comandaId != null) 'comanda_id': comandaId,
      'producto_barra_id': productoBarraId,
      'nombre_producto': nombreProducto,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'ronda': ronda,
    };
  }
}

/// Modelo Encabezado de Comanda
class Comanda {
  final String id;
  final String? numeroTicket;
  final DateTime fecha;
  final String nombreCliente;
  final String sedeId;
  final double precioTotal;
  final String? notas;
  final String estado;
  final String mesa;
  final String mesero;
  final int ronda;
  final String? metodoPago;
  final List<ComandaDetalle> detalles;

  Comanda({
    required this.id,
    this.numeroTicket,
    required this.fecha,
    required this.nombreCliente,
    required this.sedeId,
    required this.precioTotal,
    this.notas,
    this.estado = 'REGISTRADA',
    this.mesa = 'BARRA',
    this.mesero = 'ILARIO MEDINA',
    this.ronda = 1,
    this.metodoPago,
    this.detalles = const [],
  });

  bool get esAbierta => estado.toUpperCase() == 'ABIERTA';

  factory Comanda.fromJson(Map<String, dynamic> json) {
    final detallesRaw = json['comanda_detalles'] as List<dynamic>? ?? [];
    return Comanda(
      id: json['id'] as String,
      numeroTicket: json['numero_ticket'] as String?,
      fecha: json['fecha'] != null
          ? DateTime.tryParse(json['fecha'].toString()) ?? DateTime.now()
          : DateTime.now(),
      nombreCliente:
          json['nombre_cliente'] as String? ??
          json['cliente'] as String? ??
          'Cliente Barra',
      sedeId: json['sede_id'] as String? ?? '',
      precioTotal:
          double.tryParse(
            json['precio_total']?.toString() ??
                json['total']?.toString() ??
                '0',
          ) ??
          0.0,
      notas: json['notas'] as String?,
      estado: json['estado'] as String? ?? 'REGISTRADA',
      mesa: json['mesa'] as String? ?? 'BARRA',
      mesero: json['mesero'] as String? ?? 'ILARIO MEDINA',
      ronda: int.tryParse(json['ronda']?.toString() ?? '1') ?? 1,
      metodoPago: json['metodo_pago'] as String?,
      detalles: detallesRaw
          .map((d) => ComandaDetalle.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}
