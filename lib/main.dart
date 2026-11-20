import 'package:flutter/material.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/bartender_login_screen.dart';
import 'features/auth/boot_screen.dart';
import 'features/cierre_reportes/screens/cierre_turno_screen.dart';
import 'features/comandas/screens/historial_comandas_screen.dart';
import 'features/comandas/screens/nueva_comanda_screen.dart';
import 'features/consumo_interno/screens/consumo_interno_screen.dart';
import 'features/hielo/screens/control_hielo_screen.dart';
import 'features/inventario/screens/entradas_screen.dart';
import 'features/inventario/screens/mermas_screen.dart';
import 'features/inventario/screens/stock_vivo_screen.dart';
import 'features/inventario/screens/traslados_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase con las credenciales de KardexBar
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Supabase init warning: $e');
  }

  runApp(const KardexBarApp());
}

/// Aplicación principal KardexBar con tema oscuro de alto contraste
class KardexBarApp extends StatelessWidget {
  const KardexBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KardexBar - Control de Barra e Inventario',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Builder(
        builder: (context) => BootScreen(
          onFinished: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (loginContext) => BartenderLoginScreen(
                  onLoginSuccess: () {
                    Navigator.of(loginContext).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const MainBarLayoutScreen(),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Contenedor y shell de navegación para el Bartender en Sede Principal
class MainBarLayoutScreen extends StatefulWidget {
  const MainBarLayoutScreen({super.key});

  @override
  State<MainBarLayoutScreen> createState() => _MainBarLayoutScreenState();
}

class _MainBarLayoutScreenState extends State<MainBarLayoutScreen> {
  int _currentIndex = 0;
  int _subIndexComandas = 0;
  int _subIndexInventario = 0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_bar, color: AppTheme.primaryAmber, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'KARDEXBAR',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Terminal de Barra',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Badge de Sede Principal fija
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryAmber.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.store, size: 14, color: AppTheme.primaryAmber),
                  SizedBox(width: 6),
                  Text(
                    SupabaseConfig.sedePrincipalNombre,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryAmber,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Enlace con Sede Secundaria
          Tooltip(
            message: 'Trazabilidad con Sede Secundaria activa',
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.secondaryCyan.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sync_alt, size: 14, color: AppTheme.secondaryCyan),
                  SizedBox(width: 6),
                  Text(
                    'Enlace Sede 2',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondaryCyan,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.lock_outline, color: AppTheme.textMuted),
            tooltip: 'Bloquear / Salir del Turno',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => BartenderLoginScreen(
                    onLoginSuccess: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const MainBarLayoutScreen()),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (isWide) _buildNavigationRail(),
          Expanded(
            child: _buildCurrentScreen(),
          ),
        ],
      ),
      bottomNavigationBar: isWide ? null : _buildBottomNavigationBar(),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0: // COMANDAS (Nueva Comanda o Historial)
        return Column(
          children: [
            _buildSubTabBar(
              selectedIndex: _subIndexComandas,
              labels: const ['NUEVA COMANDA', 'HISTORIAL DE COMANDAS'],
              icons: const [Icons.add_shopping_cart, Icons.receipt_long],
              onChanged: (idx) => setState(() => _subIndexComandas = idx),
            ),
            Expanded(
              child: _subIndexComandas == 0
                  ? const NuevaComandaScreen()
                  : const HistorialComandasScreen(),
            ),
          ],
        );

      case 1: // INVENTARIO (Stock Vivo, Entradas, Traslados, Mermas)
        return Column(
          children: [
            _buildSubTabBar(
              selectedIndex: _subIndexInventario,
              labels: const ['STOCK VIVO', 'ENTRADAS / COMPRAS', 'TRASLADOS', 'MERMAS'],
              icons: const [Icons.inventory_2, Icons.add_circle_outline, Icons.swap_horiz, Icons.delete_outline],
              onChanged: (idx) => setState(() => _subIndexInventario = idx),
            ),
            Expanded(
              child: IndexedStack(
                index: _subIndexInventario,
                children: const [
                  StockVivoScreen(),
                  EntradasScreen(),
                  TrasladosScreen(),
                  MermasScreen(),
                ],
              ),
            ),
          ],
        );

      case 2: // CONTROL DE HIELO
        return const ControlHieloScreen();

      case 3: // CONSUMO INTERNO
        return const ConsumoInternoScreen();

      case 4: // CIERRE Y REPORTES
        return const CierreTurnoScreen();

      default:
        return const NuevaComandaScreen();
    }
  }

  Widget _buildSubTabBar({
    required int selectedIndex,
    required List<String> labels,
    required List<IconData> icons,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(labels.length, (idx) {
            final isSelected = selectedIndex == idx;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                avatar: Icon(
                  icons[idx],
                  size: 16,
                  color: isSelected ? AppTheme.background : AppTheme.primaryAmber,
                ),
                label: Text(labels[idx]),
                selected: isSelected,
                selectedColor: AppTheme.primaryAmber,
                backgroundColor: AppTheme.surfaceVariant,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.background : AppTheme.textPrimary,
                ),
                onSelected: (val) {
                  if (val) onChanged(idx);
                },
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      backgroundColor: AppTheme.surface,
      labelType: NavigationRailLabelType.all,
      indicatorColor: AppTheme.primaryAmber,
      selectedLabelTextStyle: const TextStyle(
        color: AppTheme.primaryAmber,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 11,
      ),
      selectedIconTheme: const IconThemeData(color: AppTheme.background),
      unselectedIconTheme: const IconThemeData(color: AppTheme.textMuted),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.receipt),
          selectedIcon: Icon(Icons.receipt_long),
          label: Text('Comandas'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: Text('Inventario'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.ac_unit_outlined),
          selectedIcon: Icon(Icons.ac_unit),
          label: Text('Hielo'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.people_alt_outlined),
          selectedIcon: Icon(Icons.people_alt),
          label: Text('Consumo'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.point_of_sale_outlined),
          selectedIcon: Icon(Icons.point_of_sale),
          label: Text('Cierre'),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      backgroundColor: AppTheme.surface,
      indicatorColor: AppTheme.primaryAmber,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.receipt),
          selectedIcon: Icon(Icons.receipt_long, color: AppTheme.background),
          label: 'Comandas',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2, color: AppTheme.background),
          label: 'Inventario',
        ),
        NavigationDestination(
          icon: Icon(Icons.ac_unit_outlined),
          selectedIcon: Icon(Icons.ac_unit, color: AppTheme.background),
          label: 'Hielo',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_alt_outlined),
          selectedIcon: Icon(Icons.people_alt, color: AppTheme.background),
          label: 'Consumo',
        ),
        NavigationDestination(
          icon: Icon(Icons.point_of_sale_outlined),
          selectedIcon: Icon(Icons.point_of_sale, color: AppTheme.background),
          label: 'Cierre',
        ),
      ],
    );
  }
}
