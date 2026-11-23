import '../../../core/config/supabase_config.dart';
import '../models/comanda_model.dart';

/// Servicio para la gestión de productos, registro de comandas atómicas e historial
class ComandasService {
  final _client = SupabaseConfig.client;

  /// Obtiene los productos activos del catálogo de barra
  Future<List<ProductoBarra>> getProductosBarra() async {
    final response = await _client
        .from('productos_barra')
        .select()
        .eq('activo', true)
        .order('categoria', ascending: true)
        .order('nombre', ascending: true);

    return (response as List<dynamic>)
        .map((p) => ProductoBarra.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// Registra una comanda completa ejecutando la RPC atómica en PostgreSQL
  /// Cumple la regla estricta de integridad transaccional (ACID).
  Future<Map<String, dynamic>> registrarComandaCompleta({
    required DateTime fecha,
    required String nombreCliente,
    required String sedeId,
    required List<Map<String, dynamic>> items,
    String? notas,
  }) async {
    final payload = {
      'p_fecha': fecha.toIso8601String(),
      'p_nombre_cliente': nombreCliente.trim(),
      'p_sede_id': sedeId,
      'p_items_json': items,
      'p_notas': notas,
    };

    final result = await _client.rpc(
      'registrar_comanda_completa',
      params: payload,
    );
    return Map<String, dynamic>.from(result as Map);
  }

  /// Despacha una ronda (para cuenta nueva o existente) mediante RPC atómica.
  /// Descuenta de inmediato los productos del inventario y registra kardex.
  Future<Map<String, dynamic>> despacharRonda({
    String? comandaId,
    required String nombreCliente,
    String mesa = 'BARRA',
    String mesero = 'ILARIO MEDINA',
    required String sedeId,
    required List<Map<String, dynamic>> items,
    String? notas,
  }) async {
    final payload = {
      'p_comanda_id': comandaId,
      'p_nombre_cliente': nombreCliente.trim(),
      'p_mesa': mesa.trim(),
      'p_mesero': mesero.trim(),
      'p_sede_id': sedeId,
      'p_items_json': items,
      'p_notas': notas?.trim(),
    };

    final result = await _client.rpc(
      'despachar_comanda_ronda',
      params: payload,
    );
    return Map<String, dynamic>.from(result as Map);
  }

  /// Cierra y registra definitivamente la comanda abierta cuando el cliente paga la cuenta.
  Future<Map<String, dynamic>> cerrarComandaAbierta({
    required String comandaId,
    String metodoPago = 'EFECTIVO_USD',
    String? notas,
  }) async {
    final payload = {
      'p_comanda_id': comandaId,
      'p_metodo_pago': metodoPago,
      'p_notas': notas?.trim(),
    };

    final result = await _client.rpc('cerrar_comanda_abierta', params: payload);
    return Map<String, dynamic>.from(result as Map);
  }

  /// Obtiene todas las comandas en estado ABIERTA para el widget de Mesas Abiertas
  Future<List<Comanda>> getComandasAbiertas({String? sedeId}) async {
    var query = _client
        .from('comandas')
        .select('''
      id,
      numero_ticket,
      fecha,
      nombre_cliente,
      cliente,
      sede_id,
      precio_total,
      total,
      notas,
      estado,
      mesa,
      mesero,
      ronda,
      updated_at,
      comanda_detalles (
        id,
        comanda_id,
        producto_barra_id,
        nombre_producto,
        cantidad,
        precio_unitario,
        ronda
      )
    ''')
        .eq('estado', 'ABIERTA');

    if (sedeId != null && sedeId.isNotEmpty) {
      query = query.eq('sede_id', sedeId);
    }

    final response = await query.order('updated_at', ascending: false);

    return (response as List<dynamic>)
        .map((c) => Comanda.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene el historial de comandas con soporte para doble buscador (Cliente y Producto)
  Future<List<Comanda>> getHistorialComandas({
    DateTime? fecha,
    String? filtroCliente,
    String? filtroProducto,
  }) async {
    var query = _client.from('comandas').select('''
      id,
      numero_ticket,
      fecha,
      nombre_cliente,
      cliente,
      sede_id,
      precio_total,
      total,
      notas,
      estado,
      mesa,
      mesero,
      ronda,
      comanda_detalles (
        id,
        comanda_id,
        producto_barra_id,
        nombre_producto,
        cantidad,
        precio_unitario,
        ronda
      )
    ''');

    // Filtro por fecha si se especifica (usando formato YYYY-MM-DD para columna fecha de PostgreSQL)
    if (fecha != null) {
      final dateStr =
          '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
      query = query.eq('fecha', dateStr);
    }

    // Filtro 1: Buscador por Nombre de Cliente
    if (filtroCliente != null && filtroCliente.trim().isNotEmpty) {
      query = query.ilike('nombre_cliente', '%${filtroCliente.trim()}%');
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(100);

    List<Comanda> list = (response as List<dynamic>)
        .map((c) => Comanda.fromJson(c as Map<String, dynamic>))
        .toList();

    // Filtro 2: Buscador por Producto (coincidencia de todas las palabras clave para mayor flexibilidad)
    if (filtroProducto != null && filtroProducto.trim().isNotEmpty) {
      final palabras = filtroProducto
          .trim()
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      list = list.where((cmd) {
        return cmd.detalles.any((d) {
          final prodName = d.nombreProducto.toLowerCase();
          return palabras.every((p) => prodName.contains(p));
        });
      }).toList();
    }

    return list;
  }
}
