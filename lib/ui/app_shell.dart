import 'package:flutter/material.dart';

import 'screens/dashboard/dashboard_screen.dart';
import 'screens/inventory/inventory_screen.dart';
import 'screens/more/more_screen.dart';
import 'screens/pos/pos_screen.dart';
import 'screens/products/product_list_screen.dart';

/// Premium adaptive main shell.
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
            // Premium sidebar
            Container(
              width: 220,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1B8A5A), Color(0xFF0D5C3A)],
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const Icon(Icons.storefront, size: 48, color: Colors.white),
                  const SizedBox(height: 8),
                  const Text('SariBay',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 32),
                  ...List.generate(_items.length, (i) {
                    final item = _items[i];
                    final selected = _index == i;
                    return ListTile(
                      leading: Icon(
                        selected ? item.selected : item.icon,
                        color: Colors.white,
                      ),
                      title: Text(item.label,
                          style: const TextStyle(color: Colors.white)),
                      selected: selected,
                      selectedTileColor: Colors.white.withOpacity( 0.2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      onTap: () => setState(() => _index = i),
                    );
                  }),
                ],
              ),
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
        elevation: 8,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF1B8A5A).withOpacity( 0.15),
        destinations: [
          for (final e in _items)
            NavigationDestination(
              icon: Icon(e.icon, color: Colors.grey),
              selectedIcon: Icon(e.selected, color: const Color(0xFF1B8A5A)),
              label: e.label,
            ),
        ],
      ),
    );
  }
}
