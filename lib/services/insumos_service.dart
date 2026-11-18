import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/insumo_model.dart';
import '../models/movimiento_kardex_model.dart';

class InsumosService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Obtiene los insumos físicos de barra ordenados por estado y nombre
  Future<List<Insumo>> getInsumos({String? search, String? unidad}) async {
    var query = _client.from('insumos').select();

    if (unidad != null && unidad.isNotEmpty && unidad != 'TODOS') {
      query = query.eq('unidad_medida', unidad);
    }

    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('nombre', '%${search.trim()}%');
    }

    final data = await query.order('agotado', ascending: true).order('nombre');
    return (data as List).map((e) => Insumo.fromJson(e)).toList();
  }

  /// Registra un movimiento físico en el Kardex y actualiza el stock del insumo
  Future<void> registrarMovimiento({
    required String insumoId,
    required TipoMovimientoKardex tipo,
    required double cantidad,
    String? motivo,
    String? destino,
  }) async {
    // 1. Consultar insumo actual
    final row = await _client
        .from('insumos')
        .select('stock_actual, nombre')
        .eq('id', insumoId)
        .single();

    final double stockAnterior = (row['stock_actual'] as num).toDouble();
    double nuevoStock;

    switch (tipo) {
      case TipoMovimientoKardex.entrada:
        nuevoStock = stockAnterior + cantidad;
        break;
      case TipoMovimientoKardex.merma:
      case TipoMovimientoKardex.traspasoSede2:
      case TipoMovimientoKardex.venta:
        nuevoStock = (stockAnterior - cantidad).clamp(0.0, double.infinity);
        break;
      case TipoMovimientoKardex.agotado:
        nuevoStock = 0.0;
        break;
    }

    final bool estaAgotado = nuevoStock <= 0.0;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // 2. Actualizar stock en insumos
    await _client.from('insumos').update({
      'stock_actual': nuevoStock,
      'agotado': estaAgotado,
      'updated_at': nowIso,
    }).eq('id', insumoId);

    // 3. Registrar traza en movimientos_kardex
    await _client.from('movimientos_kardex').insert({
      'insumo_id': insumoId,
      'tipo_movimiento': tipo.dbValue,
      'cantidad': cantidad,
      'motivo': motivo,
      'destino': tipo == TipoMovimientoKardex.traspasoSede2
          ? (destino ?? 'Sede 2')
          : destino,
      'fecha': nowIso,
    });
  }

  /// Acción rápida para marcar un insumo como AGOTADO inmediatamente
  Future<void> marcarAgotado({
    required String insumoId,
    String? motivo,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // 1. Poner stock en 0 y agotado en true
    await _client.from('insumos').update({
      'stock_actual': 0.0,
      'agotado': true,
      'updated_at': nowIso,
    }).eq('id', insumoId);

    // 2. Registrar evento en movimientos_kardex
    await _client.from('movimientos_kardex').insert({
      'insumo_id': insumoId,
      'tipo_movimiento': TipoMovimientoKardex.agotado.dbValue,
      'cantidad': 0.0,
      'motivo': motivo ?? 'Declarado AGOTADO en barra por falta de insumo',
      'destino': 'Barra Principal',
      'fecha': nowIso,
    });
  }

  /// Consulta el historial reciente de movimientos del Kardex
  Future<List<MovimientoKardex>> getMovimientosKardex({
    String? insumoId,
    int limit = 50,
  }) async {
    var query = _client
        .from('movimientos_kardex')
        .select('*, insumos(nombre)');

    if (insumoId != null) {
      query = query.eq('insumo_id', insumoId);
    }

    final data = await query
        .order('fecha', ascending: false)
        .limit(limit);

    return (data as List).map((e) => MovimientoKardex.fromJson(e)).toList();
  }
}
