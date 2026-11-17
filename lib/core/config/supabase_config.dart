import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración centralizada de Supabase para KardexBar.
class SupabaseConfig {
  static const String url = 'https://raqmozfiuyoctylzxnms.supabase.co';
  static const String publishableKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJhcW1vemZpdXlvY3R5bHp4bm1zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ4ODA1MjcsImV4cCI6MjExMDQ1NjUyN30.8QwLZODpwJQfoIBg1J8HyFwR4mkvX8X12XL-UhQzozU';

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
}
