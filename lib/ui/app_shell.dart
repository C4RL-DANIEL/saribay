import 'package:flutter/material.dart';

import 'screens/dashboard/dashboard_screen.dart';
import 'screens/inventory/inventory_screen.dart';
import 'screens/more/more_screen.dart';
import 'screens/pos/pos_screen.dart';
import 'screens/products/product_list_screen.dart';

/// Adaptive main shell: bottom nav (phone) or navigation rail (tablet).
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _items = [
    (icon: Icons.dashboard_outlined, selected: Icons.dashboard, label: 'Home'),
    (icon: Icons.point_of_sale_outlined, selected: Icons.point_of_sale, label: 'POS'),
    (icon: Icons.inventory_2_outlined, selected: Icons.inventory_2, label: 'Products'),
    (icon: Icons.warehouse_outlined, selected: Icons.warehouse, label: 'Stock'),
    (icon: Icons.more_horiz, selected: Icons.more, label: 'More'),
  ];

  static const _pages = [
    DashboardScreen(),
    PosScreen(),
    ProductListScreen(),
    InventoryScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.shortestSide >= 600;
    final body = _pages[_index];
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              extended: MediaQuery.of(context).size.width > 1000,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final e in _items)
                  NavigationRailDestination(
                    icon: Icon(e.icon),
                    selectedIcon: Icon(e.selected),
                    label: Text(e.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final e in _items)
            NavigationDestination(
              icon: Icon(e.icon),
              selectedIcon: Icon(e.selected),
              label: e.label,
            ),
        ],
      ),
    );
  }
}
