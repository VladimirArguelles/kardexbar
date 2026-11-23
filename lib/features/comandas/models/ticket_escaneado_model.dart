import 'comanda_model.dart';

/// Representa un ítem detectado por la visión artificial del ticket de comanda
class ItemTicketEscaneado {
  String? productoId;
  String nombreDetectado;
  double cantidad;
  ProductoBarra? productoSugerido;

  ItemTicketEscaneado({
    this.productoId,
    required this.nombreDetectado,
    required this.cantidad,
    this.productoSugerido,
  });

  /// Indica si el ítem tiene un producto de catálogo válido asignado
  bool get estaVinculado => productoSugerido != null;

  factory ItemTicketEscaneado.fromJson(
    Map<String, dynamic> json, {
    List<ProductoBarra> catalogo = const [],
  }) {
    final rawId = json['producto_id'] as String?;
    final prodId = (rawId != null && rawId.trim().isNotEmpty)
        ? rawId.trim()
        : null;
    final nombre = json['nombre_detectado'] as String? ?? 'Producto detectado';
    final cant = double.tryParse(json['cantidad']?.toString() ?? '1') ?? 1.0;

    // Buscar en catálogo si hay coincidencia directa por ID
    ProductoBarra? sugerido;
    if (prodId != null && catalogo.isNotEmpty) {
      try {
        sugerido = catalogo.firstWhere((p) => p.id == prodId);
      } catch (_) {
        sugerido = null;
      }
    }

    // Si no hubo coincidencia por ID pero el catálogo tiene productos, buscar por nombre
    if (sugerido == null && catalogo.isNotEmpty) {
      final cleanName = nombre.trim().toLowerCase();
      try {
        sugerido = catalogo.firstWhere(
          (p) =>
              p.nombre.trim().toLowerCase() == cleanName ||
              p.nombre.trim().toLowerCase().contains(cleanName) ||
              cleanName.contains(p.nombre.trim().toLowerCase()),
        );
      } catch (_) {
        sugerido = null;
      }
    }

    return ItemTicketEscaneado(
      productoId: sugerido?.id ?? prodId,
      nombreDetectado: nombre,
      cantidad: cant > 0 ? cant : 1.0,
      productoSugerido: sugerido,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'producto_id': productoSugerido?.id ?? productoId,
      'nombre_detectado': nombreDetectado,
      'cantidad': cantidad,
    };
  }
}

/// Representa el resultado completo del escaneo inteligente del ticket
class TicketEscaneadoResult {
  final String? numeroTicket;
  final String? cliente;
  final String? mesero;
  final List<ItemTicketEscaneado> items;

  TicketEscaneadoResult({
    this.numeroTicket,
    this.cliente,
    this.mesero,
    required this.items,
  });

  factory TicketEscaneadoResult.fromJson(
    Map<String, dynamic> json, {
    List<ProductoBarra> catalogo = const [],
  }) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final itemsParsed = rawItems
        .map(
          (i) => ItemTicketEscaneado.fromJson(
            i as Map<String, dynamic>,
            catalogo: catalogo,
          ),
        )
        .toList();

    return TicketEscaneadoResult(
      numeroTicket: (json['numero_ticket'] as String?)?.trim(),
      cliente: (json['cliente'] as String?)?.trim(),
      mesero: (json['mesero'] as String?)?.trim(),
      items: itemsParsed,
    );
  }
}
