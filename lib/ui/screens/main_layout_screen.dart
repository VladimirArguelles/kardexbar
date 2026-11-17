import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'cierre_screen.dart';
import 'dashboard_screen.dart';
import 'inventario_screen.dart';
import 'pos_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    PosScreen(),
    InventarioScreen(),
    CierreScreen(),
    DashboardScreen(),
  ];

  final List<String> _titles = const [
    'Punto de Venta & Comandas',
    'Control de Inventario & Kardex',
    'Arqueo Diario & Cierre de Barra',
    'Panel de Métricas & Auditoría',
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Image.asset(
                'assets/images/logo.png',
                height: 38,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 14),
            Container(
              height: 22,
              width: 1,
              color: AppTheme.borderLight,
            ),
            const SizedBox(width: 14),
            Text(
              _titles[_currentIndex],
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: const [
                Icon(Icons.person_pin_circle_rounded, color: AppTheme.secondaryCyan, size: 16),
                SizedBox(width: 6),
                Text(
                  'Bartender en Turno',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              backgroundColor: AppTheme.surface,
              selectedIndex: _currentIndex,
              onDestinationSelected: (val) => setState(() => _currentIndex = val),
              labelType: NavigationRailLabelType.all,
              indicatorColor: AppTheme.primaryAmber,
              selectedIconTheme: const IconThemeData(color: Colors.black),
              unselectedIconTheme: const IconThemeData(color: AppTheme.textMuted),
              selectedLabelTextStyle: const TextStyle(
                color: AppTheme.primaryAmber,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.point_of_sale_outlined),
                  selectedIcon: Icon(Icons.point_of_sale),
                  label: Text('POS Barra'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: Text('Kardex'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: Text('Arqueo'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics),
                  label: Text('Métricas'),
                ),
              ],
            ),
          if (isDesktop) const VerticalDivider(color: AppTheme.borderLight, width: 1),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isDesktop
          ? NavigationBar(
              backgroundColor: AppTheme.surface,
              selectedIndex: _currentIndex,
              indicatorColor: AppTheme.primaryAmber,
              onDestinationSelected: (val) => setState(() => _currentIndex = val),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.point_of_sale_outlined),
                  selectedIcon: Icon(Icons.point_of_sale, color: Colors.black),
                  label: 'POS',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2, color: Colors.black),
                  label: 'Kardex',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check, color: Colors.black),
                  label: 'Arqueo',
                ),
                NavigationDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics, color: Colors.black),
                  label: 'Métricas',
                ),
              ],
            )
          : null,
    );
  }
}
