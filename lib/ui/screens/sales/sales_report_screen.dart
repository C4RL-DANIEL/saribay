import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../data/db/database.dart';
import '../../widgets/animated_widgets.dart';

/// Comprehensive sales report with daily/weekly/monthly breakdowns.
class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});
  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  int _selectedPeriod = 0; // 0=today, 1=week, 2=month, 3=year
  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _hourlySales = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final db = await AppDatabase.instance.database;
    
    String dateFilter;
    switch (_selectedPeriod) {
      case 0: dateFilter = "date(created_at) = date('now')"; break;
      case 1: dateFilter = "created_at >= datetime('now', '-7 days')"; break;
      case 2: dateFilter = "created_at >= datetime('now', '-30 days')"; break;
      case 3: dateFilter = "created_at >= datetime('now', '-365 days')"; break;
      default: dateFilter = "1=1";
    }

    // Sales summary
    final sales = await db.rawQuery('''
      SELECT COUNT(*) as transactions, COALESCE(SUM(total),0) as revenue, 
             COALESCE(SUM(profit),0) as profit, COALESCE(SUM(cogs),0) as cogs,
             COALESCE(AVG(total),0) as avg_order
      FROM sales WHERE status='COMPLETED' AND $dateFilter
    ''');

    // Top products
    final topProducts = await db.rawQuery('''
      SELECT si.product_name, SUM(si.quantity) as qty, SUM(si.total) as revenue,
             AVG(si.unit_price) as avg_price
      FROM sale_items si JOIN sales s ON s.id = si.sale_id
      WHERE s.status='COMPLETED' AND $dateFilter
      GROUP BY si.product_name ORDER BY revenue DESC LIMIT 10
    ''');

    // Hourly sales pattern (today only)
    final hourly = await db.rawQuery('''
      SELECT strftime('%H', created_at) as hour, COUNT(*) as cnt, SUM(total) as total
      FROM sales WHERE status='COMPLETED' AND date(created_at) = date('now')
      GROUP BY hour ORDER BY hour
    ''');

    setState(() {
      final revenue = (sales.first['revenue'] as num?)?.toDouble() ?? 0;
      final profit = (sales.first['profit'] as num?)?.toDouble() ?? 0;
      _data = {
        'transactions': sales.first['transactions'],
        'revenue': revenue,
        'profit': profit,
        'cogs': sales.first['cogs'],
        'avgOrder': sales.first['avg_order'],
        'margin': revenue > 0 ? (profit / revenue * 100) : 0.0,
      };
      _topProducts = topProducts;
      _hourlySales = hourly;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Period selector
                  _buildPeriodSelector(),
                  const SizedBox(height: 16),
                  
                  // Summary cards
                  _buildSummaryCards(),
                  const SizedBox(height: 16),
                  
                  // Top products
                  _buildTopProducts(),
                  const SizedBox(height: 16),
                  
                  // Hourly pattern
                  if (_selectedPeriod == 0) _buildHourlyPattern(),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 0, label: Text('Today')),
        ButtonSegment(value: 1, label: Text('Week')),
        ButtonSegment(value: 2, label: Text('Month')),
        ButtonSegment(value: 3, label: Text('Year')),
      ],
      selected: {_selectedPeriod},
      onSelectionChanged: (v) {
        setState(() => _selectedPeriod = v.first);
        _loadData();
      },
    );
  }

  Widget _buildSummaryCards() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _summaryCard(Icons.attach_money, 'Revenue', peso(_data['revenue']), Colors.green),
        _summaryCard(Icons.trending_up, 'Profit', peso(_data['profit']), Colors.blue),
        _summaryCard(Icons.receipt_long, 'Transactions', '${_data['transactions']}', Colors.purple),
        _summaryCard(Icons.analytics, 'Margin', '${(_data['margin'] as double).toStringAsFixed(1)}%', Colors.orange),
      ],
    );
  }

  Widget _summaryCard(IconData icon, String label, dynamic value, Color color) {
    return SizedBox(
      width: 160,
      child: AnimatedCard(
        showShadow: true,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProducts() {
    if (_topProducts.isEmpty) return const SizedBox.shrink();
    
    return AnimatedCard(
      showShadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(),
          ..._topProducts.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            return AnimatedListItem(
              index: i,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                title: Text(p['product_name'] as String),
                subtitle: Text('${p['qty']} sold'),
                trailing: Text(peso(p['revenue'] as num?), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHourlyPattern() {
    if (_hourlySales.isEmpty) return const SizedBox.shrink();
    
    return AnimatedCard(
      showShadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hourly Sales Pattern', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _hourlySales.length,
              itemBuilder: (ctx, i) {
                final h = _hourlySales[i];
                final maxTotal = _hourlySales.fold<double>(0, (s, e) => 
                  (e['total'] as num?)?.toDouble() ?? 0 > s ? (e['total'] as num?)?.toDouble() ?? 0 : s);
                final height = maxTotal > 0 ? ((h['total'] as num?)?.toDouble() ?? 0 / maxTotal * 80) : 0.0;
                
                return Container(
                  width: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(peso(h['total'] as num?), style: const TextStyle(fontSize: 8)),
                      const SizedBox(height: 4),
                      Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B8A5A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${h['hour']}:00', style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
