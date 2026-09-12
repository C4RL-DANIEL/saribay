import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../data/db/database.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});
  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<Map<String, dynamic>> _sales = [];
  String _filter = 'today';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    String where = "status != 'HELD'";
    if (_filter == 'today') {
      where += " AND date(created_at) = date('now')";
    } else if (_filter == 'week') {
      where += " AND created_at >= datetime('now', '-7 days')";
    } else if (_filter == 'month') {
      where += " AND created_at >= datetime('now', '-30 days')";
    }
    _sales = await db.rawQuery(
        "SELECT s.*, u.name as user_name FROM sales s LEFT JOIN users u ON u.id = s.user_id WHERE $where ORDER BY s.id DESC");
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales History')),
      body: Column(
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'today', label: Text('Today')),
              ButtonSegment(value: 'week', label: Text('Week')),
              ButtonSegment(value: 'month', label: Text('Month')),
              ButtonSegment(value: 'all', label: Text('All')),
            ],
            selected: {_filter},
            onSelectionChanged: (v) { setState(() { _filter = v.first; _loading = true; }); _load(); },
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _sales.isEmpty
                    ? const Center(child: Text('No sales'))
                    : ListView.builder(
                        itemCount: _sales.length,
                        itemBuilder: (ctx, i) {
                          final s = _sales[i];
                          final status = s['status'] as String;
                          final color = status == 'COMPLETED' ? Colors.green
                              : status == 'REFUNDED' ? Colors.red
                              : Colors.orange;
                          return ListTile(
                            title: Text(s['receipt_no'] as String),
                            subtitle: Text('${s['user_name'] ?? 'Unknown'} · ${s['created_at']}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(peso(s['total'] as num?), style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(status, style: TextStyle(color: color, fontSize: 11)),
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
