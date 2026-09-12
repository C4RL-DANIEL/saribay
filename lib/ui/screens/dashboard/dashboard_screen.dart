import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money.dart';
import '../../../data/db/database.dart';
import '../sales/sales_history_screen.dart';
import '../inventory/inventory_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>> _bestSellers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final weekAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();

    final salesToday = await db.rawQuery(
        "SELECT COUNT(*) as cnt, COALESCE(SUM(total),0) as total, COALESCE(SUM(profit),0) as profit "
        "FROM sales WHERE status='COMPLETED' AND date(created_at) = ?", [today]);
    final salesWeek = await db.rawQuery(
        "SELECT COALESCE(SUM(total),0) as total, COALESCE(SUM(profit),0) as profit "
        "FROM sales WHERE status='COMPLETED' AND created_at >= ?", [weekAgo]);
    final lowStock = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM products WHERE is_deleted=0 AND min_stock > 0 AND stock <= min_stock");
    final outOfStock = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM products WHERE is_deleted=0 AND stock <= 0");
    final utang = await db.rawQuery(
        "SELECT COUNT(*) as cnt, COALESCE(SUM(utang_balance),0) as total FROM customers WHERE utang_balance > 0");
    final expToday = await db.rawQuery(
        "SELECT COALESCE(SUM(amount),0) as total FROM expenses WHERE expense_date = ?", [today]);
    final drawer = await db.query('cash_drawers', where: 'status = ?', whereArgs: ['OPEN'], limit: 1);
    final totalProducts = await db.rawQuery("SELECT COUNT(*) as cnt FROM products WHERE is_deleted=0 AND is_active=1");
    final bestSellers = await db.rawQuery('''
      SELECT si.product_name, SUM(si.quantity) as qty, SUM(si.total) as revenue
      FROM sale_items si JOIN sales s ON s.id = si.sale_id
      WHERE s.status = 'COMPLETED' AND s.created_at >= ?
      GROUP BY si.product_name ORDER BY qty DESC LIMIT 5
    ''', [weekAgo]);

    setState(() {
      _data = {
        'salesToday': salesToday.first['total'],
        'profitToday': salesToday.first['profit'],
        'txToday': salesToday.first['cnt'],
        'salesWeek': salesWeek.first['total'],
        'profitWeek': salesWeek.first['profit'],
        'lowStock': lowStock.first['cnt'],
        'outOfStock': outOfStock.first['cnt'],
        'utangCount': utang.first['cnt'],
        'utangTotal': utang.first['total'],
        'expToday': expToday.first['total'],
        'cashBalance': drawer.isNotEmpty ? drawer.first['opening_amount'] : 0,
        'totalProducts': totalProducts.first['cnt'],
      };
      _bestSellers = bestSellers;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final ts = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Dashboard', style: ts.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Today's summary cards
          Wrap(spacing: 12, runSpacing: 12, children: [
            _card(Icons.today, 'Today\'s Sales', peso(_data['salesToday']), Colors.green),
            _card(Icons.trending_up, 'Today\'s Profit', peso(_data['profitToday']), Colors.blue),
            _card(Icons.receipt_long, 'Transactions', '${_data['txToday']}', Colors.purple),
            _card(Icons.shopping_bag, 'Total Products', '${_data['totalProducts']}', Colors.teal),
          ]),
          const SizedBox(height: 16),
          // Alerts
          Wrap(spacing: 12, runSpacing: 12, children: [
            if ((_data['lowStock'] as int) > 0)
              _card(Icons.warning_amber, 'Low Stock', '${_data['lowStock']} items', Colors.orange),
            if ((_data['outOfStock'] as int) > 0)
              _card(Icons.error_outline, 'Out of Stock', '${_data['outOfStock']} items', Colors.red),
            if ((_data['utangCount'] as int) > 0)
              _card(Icons.person_off, 'Utang Owed', peso(_data['utangTotal']), Colors.deepOrange),
            if ((_data['expToday'] as double) > 0)
            _card(Icons.money_off, 'Expenses Today', peso(_data['expToday']), Colors.red),
          ]),
          const SizedBox(height: 16),
          if (_bestSellers.isNotEmpty) ...[
            Text('Best Sellers (7 days)', style: ts.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._bestSellers.map((b) => ListTile(
              dense: true,
              leading: const Icon(Icons.star, size: 20),
              title: Text('${b['product_name']}'),
              trailing: Text('${b['qty']} sold'),
              subtitle: Text(peso(b['revenue'])),
            )),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesHistoryScreen())),
              icon: const Icon(Icons.receipt_long), label: const Text('Sales History'),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
              icon: const Icon(Icons.inventory_2), label: const Text('Inventory'),
            )),
          ]),
        ],
      ),
    );
  }

  Widget _card(IconData icon, String label, String value, Color color) {
    return SizedBox(
      width: 180,
      child: Card(
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}
