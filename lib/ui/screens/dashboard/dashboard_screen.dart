import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/money.dart';
import '../../../data/db/database.dart';
import '../../widgets/animated_widgets.dart';
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
    final utang = await db.rawQuery(
        "SELECT COUNT(*) as cnt, COALESCE(SUM(utang_balance),0) as total FROM customers WHERE utang_balance > 0");
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
        'utangCount': utang.first['cnt'],
        'utangTotal': utang.first['total'],
        'totalProducts': totalProducts.first['cnt'],
      };
      _bestSellers = bestSellers;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const ShimmerLoading(width: 150, height: 32),
              const SizedBox(height: 8),
              const ShimmerLoading(width: 200, height: 16),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(child: ShimmerLoading(height: 120)),
                  const SizedBox(width: 12),
                  Expanded(child: ShimmerLoading(height: 120)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: ShimmerLoading(height: 120)),
                  const SizedBox(width: 12),
                  Expanded(child: ShimmerLoading(height: 120)),
                ],
              ),
              const SizedBox(height: 20),
              const ShimmerLoading(width: 150, height: 24),
              const SizedBox(height: 12),
              ...List.generate(3, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ShimmerLoading(height: 60),
              )),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.dashboard,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 20),

            // Today's stats
            Row(
              children: [
                _statCard(Icons.receipt_long, l.todaysSales,
                    peso(_data['salesToday'] as num?), const Color(0xFF1B8A5A)),
                const SizedBox(width: 12),
                _statCard(Icons.trending_up, l.profit,
                    peso(_data['profitToday'] as num?), Colors.blue),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statCard(Icons.shopping_bag, l.products,
                    '${_data['totalProducts']}', Colors.purple),
                const SizedBox(width: 12),
                _statCard(Icons.receipt, l.transactions,
                    '${_data['txToday']}', Colors.orange),
              ],
            ),
            const SizedBox(height: 20),

            // Alerts
            if ((_data['lowStock'] as int) > 0)
              _alertCard(Icons.warning_amber, l.lowStock,
                  '${_data['lowStock']} items need restocking', Colors.orange),
            if ((_data['utangCount'] as int) > 0)
              _alertCard(Icons.person_off, l.outstandingUtang,
                  '${peso(_data['utangTotal'] as num?)} from ${_data['utangCount']} customers', Colors.deepOrange),

            const SizedBox(height: 20),

            // Best sellers
            if (_bestSellers.isNotEmpty) ...[
              Text(l.bestSellers,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              AnimatedCard(
                showShadow: true,
                child: Column(
                  children: _bestSellers.asMap().entries.map((e) {
                    final i = e.key;
                    final b = e.value;
                    return AnimatedListItem(
                      index: i,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1B8A5A).withOpacity(0.1),
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Color(0xFF1B8A5A),
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(b['product_name'] as String),
                        subtitle: Text('${b['qty']} sold'),
                        trailing: Text(peso(b['revenue'] as num?),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Quick actions
            Row(
              children: [
                Expanded(
                  child: _actionButton(Icons.receipt_long, l.salesHistory, () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SalesHistoryScreen()));
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionButton(Icons.inventory_2, l.inventory, () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const InventoryScreen()));
                  }),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, dynamic value, Color color) {
    return Expanded(
      child: AnimatedCard(
        showShadow: true,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text('$value',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _alertCard(IconData icon, String title, String subtitle, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: color),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 32, color: const Color(0xFF1B8A5A)),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
