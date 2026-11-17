/// Modelo que representa un cliente con historial de compras registradas en el POS
class ClienteHistorial {
  final String nombre;
  final int totalCompras;
  final DateTime? ultimaCompra;
  final double totalGastado;
  final String? ultimoTicket;

  const ClienteHistorial({
    required this.nombre,
    required this.totalCompras,
    this.ultimaCompra,
    this.totalGastado = 0.0,
    this.ultimoTicket,
  });

  factory ClienteHistorial.fromJson(Map<String, dynamic> json) {
    return ClienteHistorial(
      nombre: json['cliente_nombre'] as String? ?? 'Cliente Anónimo',
      totalCompras: (json['total_compras'] as num?)?.toInt() ?? 1,
      ultimaCompra: json['ultima_compra'] != null
          ? DateTime.tryParse(json['ultima_compra'] as String)
          : null,
      totalGastado: (json['total_gastado'] as num?)?.toDouble() ?? 0.0,
      ultimoTicket: json['ultimo_ticket'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cliente_nombre': nombre,
      'total_compras': totalCompras,
      'ultima_compra': ultimaCompra?.toIso8601String(),
      'total_gastado': totalGastado,
      'ultimo_ticket': ultimoTicket,
    };
  }
}
