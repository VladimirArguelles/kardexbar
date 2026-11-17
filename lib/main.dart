import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'ui/screens/main_layout_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase con las credenciales del proyecto kardexbar
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Nota: Inicialización de Supabase: $e');
  }

  runApp(
    const ProviderScope(
      child: KardexBarApp(),
    ),
  );
}

class KardexBarApp extends StatelessWidget {
  const KardexBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KardexBar - Control de Barra e Inventario',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainLayoutScreen(),
    );
  }
}
