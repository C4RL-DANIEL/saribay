import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../data/db/database.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int _tab = 0;
  Map<String, dynamic> _sales = {};
  Map<String, dynamic> _inventory = {};
  Map<String, dynamic> _financial = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;

    // Sales summary
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final salesToday = await db.rawQuery(
        "SELECT COUNT(*) as cnt, COALESCE(SUM(total),0) as total, COALESCE(SUM(profit),0) as profit, COALESCE(SUM(cogs),0) as cogs "
        "FROM sales WHERE status='COMPLETED' AND date(created_at) = ?", [today]);
    final salesMonth = await db.rawQuery(
        "SELECT COUNT(*) as cnt, COALESCE(SUM(total),0) as total, COALESCE(SUM(profit),0) as profit "
        "FROM sales WHERE status='COMPLETED' AND created_at >= datetime('now', '-30 days')");
    final salesYear = await db.rawQuery(
        "SELECT COUNT(*) as cnt, COALESCE(SUM(total),0) as total, COALESCE(SUM(profit),0) as profit "
        "FROM sales WHERE status='COMPLETED' AND created_at >= datetime('now', '-365 days')");

    // Inventory
    final totalProducts = await db.rawQuery("SELECT COUNT(*) as cnt FROM products WHERE is_deleted=0");
    final lowStock = await db.rawQuery("SELECT COUNT(*) as cnt FROM products WHERE is_deleted=0 AND min_stock > 0 AND stock <= min_stock");
    final inventoryValue = await db.rawQuery("SELECT COALESCE(SUM(stock * cost_price),0) as total FROM products WHERE is_deleted=0");

    // Financial
    final expensesMonth = await db.rawQuery(
        "SELECT COALESCE(SUM(amount),0) as total FROM expenses WHERE expense_date >= datetime('now', '-30 days')");
    final utangTotal = await db.rawQuery("SELECT COALESCE(SUM(utang_balance),0) as total FROM customers WHERE utang_balance > 0");

    setState(() {
      _sales = {
        'today': salesToday.first, 'month': salesMonth.first, 'year': salesYear.first,
      };
      _inventory = {
        'products': totalProducts.first['cnt'],
        'lowStock': lowStock.first['cnt'],
        'value': inventoryValue.first['total'],
      };
      _financial = {
        'expensesMonth': expensesMonth.first['total'],
        'utangTotal': utangTotal.first['total'],
      };
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Sales')),
              ButtonSegment(value: 1, label: Text('Inventory')),
              ButtonSegment(value: 2, label: Text('Financial')),
            ],
            selected: {_tab},
            onSelectionChanged: (v) => setState(() => _tab = v.first),
          ),
          const SizedBox(height: 16),
          if (_tab == 0) _buildSalesReport(),
          if (_tab == 1) _buildInventoryReport(),
          if (_tab == 2) _buildFinancialReport(),
        ],
      ),
    );
  }

  Widget _buildSalesReport() {
    final today = _sales['today'] as Map;
    final month = _sales['month'] as Map;
    final year = _sales['year'] as Map;
    return Column(
      children: [
        _reportCard('Today', [
          _row('Transactions', '${today['cnt']}'),
          _row('Revenue', peso(today['total'] as num?)),
          _row('Profit', peso(today['profit'] as num?)),
          _row('COGS', peso(today['cogs'] as num?)),
        ]),
        const SizedBox(height: 12),
        _reportCard('This Month (30 days)', [
          _row('Transactions', '${month['cnt']}'),
          _row('Revenue', peso(month['total'] as num?)),
          _row('Profit', peso(month['profit'] as num?)),
        ]),
        const SizedBox(height: 12),
        _reportCard('This Year', [
          _row('Transactions', '${year['cnt']}'),
          _row('Revenue', peso(year['total'] as num?)),
          _row('Profit', peso(year['profit'] as num?)),
        ]),
      ],
    );
  }

  Widget _buildInventoryReport() {
    return Column(
      children: [
        _reportCard('Inventory', [
          _row('Total Products', '${_inventory['products']}'),
          _row('Low Stock Items', '${_inventory['lowStock']}'),
          _row('Inventory Value', peso(_inventory['value'] as num?)),
        ]),
      ],
    );
  }

  Widget _buildFinancialReport() {
    return Column(
      children: [
        _reportCard('Financial', [
          _row('Expenses (30 days)', peso(_financial['expensesMonth'] as num?)),
          _row('Outstanding Utang', peso(_financial['utangTotal'] as num?)),
        ]),
      ],
    );
  }

  Widget _reportCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
      ),
    );
  }
}
