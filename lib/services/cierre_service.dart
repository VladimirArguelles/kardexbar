import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/cierre_diario_model.dart';

class CierreService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Invoca el procedimiento almacenado (RPC) de PostgreSQL: generar_cierre_diario
  /// Calcula el stock inicial, surtido del día, salidas teóricas por comanda y balance
  Future<List<CierreDiarioItem>> generarCierreDiario({DateTime? fecha}) async {
    final targetDate = fecha ?? DateTime.now();
    final dateString =
        '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

    final res = await _client.rpc('generar_cierre_diario', params: {
      'p_fecha': dateString,
    });

    return (res as List)
        .map((e) => CierreDiarioItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Envía los conteos físicos de la barra y finaliza el cierre diario
  /// Invoca la RPC: registrar_conteo_fisico_y_cerrar
  Future<List<CierreDiarioItem>> registrarConteoYCerrar({
    required DateTime fecha,
    required List<CierreDiarioItem> items,
    String? observaciones,
  }) async {
    final dateString =
        '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

    final conteosJson = items.map((i) => i.toConteoJson()).toList();

    final res = await _client.rpc('registrar_conteo_fisico_y_cerrar', params: {
      'p_fecha': dateString,
      'p_conteos': conteosJson,
      'p_observaciones': observaciones,
    });

    return (res as List)
        .map((e) => CierreDiarioItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Consulta auditoría de diferencias del día o históricas
  Future<List<Map<String, dynamic>>> getAuditoriaDiferencias({DateTime? fecha}) async {
    var query = _client
        .from('auditoria_diferencias')
        .select('*, productos(nombre, codigo, categoria)');

    if (fecha != null) {
      final dateString =
          '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
      query = query.eq('fecha', dateString);
    }

    final data = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }
}
