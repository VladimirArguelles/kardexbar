import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración centralizada de Supabase para KardexBar.
class SupabaseConfig {
  static const String url = 'https://raqmozfiuyoctylzxnms.supabase.co';
  static const String publishableKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJhcW1vemZpdXlvY3R5bHp4bm1zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ4ODA1MjcsImV4cCI6MjExMDQ1NjUyN30.8QwLZODpwJQfoIBg1J8HyFwR4mkvX8X12XL-UhQzozU';

  /// Nombre y constantes de Sede Principal fija por defecto
  static const String sedePrincipalNombre = 'Sede Principal';
  static const String sedeSecundariaNombre = 'Sede Secundaria';
  static const String defaultSedePrincipalId =
      'f0a52a94-59e9-48cd-9225-b07d0388f1a5';
  static const String defaultSedeSecundariaId =
      '155e0e55-6711-4a09-86ae-59a8825d437f';

  static String _cachedSedePrincipalId = defaultSedePrincipalId;
  static String _cachedSedeSecundariaId = defaultSedeSecundariaId;

  /// Inicializa el cliente Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      debug: false,
    );
  }

  /// Instancia global del cliente de Supabase
  static SupabaseClient get client => Supabase.instance.client;

  /// Obtiene de forma reactiva o devuelve el ID en caché de la Sede Principal
  static Future<String> getSedePrincipalId() async {
    try {
      final res = await client
          .from('sedes')
          .select('id')
          .eq('es_principal', true)
          .maybeSingle();
      if (res != null && res['id'] != null) {
        _cachedSedePrincipalId = res['id'] as String;
      }
    } catch (_) {}
    return _cachedSedePrincipalId;
  }

  /// Obtiene de forma reactiva o devuelve el ID en caché de la Sede Secundaria
  static Future<String> getSedeSecundariaId() async {
    try {
      final res = await client
          .from('sedes')
          .select('id')
          .eq('nombre', sedeSecundariaNombre)
          .maybeSingle();
      if (res != null && res['id'] != null) {
        _cachedSedeSecundariaId = res['id'] as String;
      }
    } catch (_) {}
    return _cachedSedeSecundariaId;
  }
}
