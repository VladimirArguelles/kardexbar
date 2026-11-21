import '../../../core/config/supabase_config.dart';
import '../models/insumo_model.dart';
import '../models/kardex_movimiento_model.dart';

/// Servicio para la gestión física de inventario e invocación de RPCs atómicas
class InventarioService {
  final _client = SupabaseConfig.client;

  /// Obtiene el listado de insumos y stock vivo de una sede específica
  Future<List<InsumoInventario>> getStockSede(String sedeId) async {
    final response = await _client
        .from('insumos_inventario')
        .select()
        .eq('sede_id', sedeId)
        .order('nombre', ascending: true);

    return (response as List<dynamic>)
        .map((i) => InsumoInventario.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  /// Registra una compra/entrada de inventario mediante RPC atómica
  Future<Map<String, dynamic>> registrarEntradaCompra({
    required String insumoId,
    required String sedeId,
    required double cantidad,
    required double costoUnitario,
    required String proveedorOMotivo,
  }) async {
    final payload = {
      'p_insumo_id': insumoId,
      'p_sede_id': sedeId,
      'p_cantidad': cantidad,
      'p_costo_unitario': costoUnitario,
      'p_proveedor_o_motivo': proveedorOMotivo.trim(),
    };

    final result = await _client.rpc('registrar_entrada_compra', params: payload);
    return Map<String, dynamic>.from(result as Map);
  }

  /// Registra un traslado entre sedes mediante RPC atómica
  Future<Map<String, dynamic>> registrarTrasladoSedes({
    required String insumoNombre,
    required String sedeOrigenId,
    required String sedeDestinoId,
    required double cantidad,
    required String motivo,
  }) async {
    final payload = {
      'p_insumo_nombre': insumoNombre.trim(),
      'p_sede_origen_id': sedeOrigenId,
      'p_sede_destino_id': sedeDestinoId,
      'p_cantidad': cantidad,
      'p_motivo': motivo.trim(),
    };

    final result = await _client.rpc('registrar_traslado_sedes', params: payload);
    return Map<String, dynamic>.from(result as Map);
  }

  /// Registra una merma o rotura de barra mediante RPC atómica
  Future<Map<String, dynamic>> registrarMerma({
    required String insumoId,
    required String sedeId,
    required double cantidad,
    required String motivo,
  }) async {
    final payload = {
      'p_insumo_id': insumoId,
      'p_sede_id': sedeId,
      'p_cantidad': cantidad,
      'p_motivo': motivo.trim(),
    };

    final result = await _client.rpc('registrar_merma', params: payload);
    return Map<String, dynamic>.from(result as Map);
  }

  /// Registra consumo interno diferenciado (Dueño vs Trabajador) mediante RPC atómica
  Future<Map<String, dynamic>> registrarConsumoInterno({
    required String insumoId,
    required String sedeId,
    required double cantidad,
    required String tipo, // 'CONSUMO_DUENO' o 'CONSUMO_TRABAJADOR'
    required String beneficiario,
    String? motivo,
  }) async {
    final payload = {
      'p_insumo_id': insumoId,
      'p_sede_id': sedeId,
      'p_cantidad': cantidad,
      'p_tipo': tipo,
      'p_beneficiario': beneficiario.trim(),
      'p_motivo': motivo,
    };

    final result = await _client.rpc('registrar_consumo_interno', params: payload);
    return Map<String, dynamic>.from(result as Map);
  }

  /// Registra un movimiento específico de bolsas de hielo mediante RPC atómica
  Future<Map<String, dynamic>> registrarMovimientoHielo({
    required String sedeId,
    required String tipoMovimiento, // 'COMPRA', 'MERMA', 'TRASLADO'
    required double cantidad,
    required String motivo,
    String? sedeDestinoId,
  }) async {
    final payload = {
      'p_sede_id': sedeId,
      'p_tipo_movimiento': tipoMovimiento,
      'p_cantidad': cantidad,
      'p_motivo': motivo.trim(),
      'p_sede_destino_id': sedeDestinoId,
    };

    final result = await _client.rpc('registrar_movimiento_hielo', params: payload);
    return Map<String, dynamic>.from(result as Map);
  }

  /// Obtiene los movimientos recientes del Kardex
  Future<List<KardexMovimiento>> getMovimientosKardex({
    String? sedeId,
    String? tipoMovimiento,
    int limit = 50,
  }) async {
    var query = _client.from('kardex_movimientos').select('''
      id,
      fecha,
      insumo_id,
      sede_origen_id,
      sede_destino_id,
      tipo_movimiento,
      cantidad,
      beneficiario_o_motivo,
      referencia_id,
      insumos_inventario (
        nombre,
        costo_unitario
      )
    ''');

    if (sedeId != null) {
      query = query.eq('sede_origen_id', sedeId);
    }
    if (tipoMovimiento != null) {
      query = query.eq('tipo_movimiento', tipoMovimiento);
    }

    final response = await query.order('fecha', ascending: false).limit(limit);

    return (response as List<dynamic>)
        .map((k) => KardexMovimiento.fromJson(k as Map<String, dynamic>))
        .toList();
  }
}
