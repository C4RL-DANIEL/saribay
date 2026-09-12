import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../data/db/database.dart';

class CashDrawerScreen extends StatefulWidget {
  const CashDrawerScreen({super.key});
  @override
  State<CashDrawerScreen> createState() => _CashDrawerScreenState();
}

class _CashDrawerScreenState extends State<CashDrawerScreen> {
  Map<String, dynamic>? _drawer;
  List<Map<String, dynamic>> _movements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    final open = await db.query('cash_drawers', where: 'status = ?', whereArgs: ['OPEN'], limit: 1);
    _drawer = open.isNotEmpty ? open.first : null;
    if (_drawer != null) {
      _movements = await db.query('cash_movements',
          where: 'drawer_id = ?', whereArgs: [_drawer!['id']], orderBy: 'id DESC');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_drawer == null) return _buildOpenDrawer();
    return _buildActiveDrawer();
  }

  Widget _buildOpenDrawer() {
    final amt = TextEditingController(text: '500');
    return Scaffold(
      appBar: AppBar(title: const Text('Cash Drawer')),
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_balance_wallet, size: 64),
                const SizedBox(height: 16),
                const Text('No Open Drawer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: amt,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Opening Amount (₱)'),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    final opening = double.tryParse(amt.text) ?? 0;
                    final db = await AppDatabase.instance.database;
                    final now = DateTime.now().toIso8601String();
                    final drawerId = await db.insert('cash_drawers', {
                      'opened_by': 1, 'opening_amount': opening, 'opened_at': now, 'status': 'OPEN',
                    });
                    await db.insert('cash_movements', {
                      'drawer_id': drawerId, 'type': 'OPEN', 'amount': opening, 'created_at': now,
                    });
                    _load();
                  },
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Open Drawer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveDrawer() {
    final opening = (_drawer!['opening_amount'] as num).toDouble();
    final cashIn = _movements.where((m) => m['type'] == 'SALE').fold<double>(0, (s, m) => s + (m['amount'] as num).toDouble());
    final cashOut = _movements.where((m) => m['type'] == 'EXPENSE' || m['type'] == 'CASH_OUT' || m['type'] == 'REFUND')
        .fold<double>(0, (s, m) => s + (m['amount'] as num).toDouble());
    final expected = opening + cashIn - cashOut;

    return Scaffold(
      appBar: AppBar(title: const Text('Cash Drawer (OPEN)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row('Opening', peso(opening)),
                  _row('Cash In (Sales)', peso(cashIn)),
                  _row('Cash Out (Refunds)', peso(cashOut)),
                  const Divider(),
                  _row('Expected Cash', peso(expected), bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Movements', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._movements.map((m) => ListTile(
            dense: true,
            leading: Icon(
              m['type'] == 'SALE' ? Icons.add_circle : Icons.remove_circle,
              color: m['type'] == 'SALE' ? Colors.green : Colors.red,
            ),
            title: Text(m['type'] as String),
            subtitle: Text(m['created_at'] as String),
            trailing: Text(peso(m['amount'] as num)),
          )),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _showCloseDialog(expected),
            icon: const Icon(Icons.lock),
            label: const Text('Close Drawer'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 18 : 14)),
        ],
      ),
    );
  }

  void _showCloseDialog(double expected) {
    final actual = TextEditingController(text: expected.toStringAsFixed(2));
    final reason = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Drawer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Expected: ${peso(expected)}'),
              const SizedBox(height: 8),
              TextField(controller: actual, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Actual Cash (₱)')),
              const SizedBox(height: 8),
              TextField(controller: reason, decoration: const InputDecoration(labelText: 'Variance Reason (if any)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final actualVal = double.tryParse(actual.text) ?? 0;
              final variance = actualVal - expected;
              final db = await AppDatabase.instance.database;
              final now = DateTime.now().toIso8601String();
              await db.rawUpdate(
                "UPDATE cash_drawers SET closed_at=?, expected_cash=?, actual_cash=?, variance=?, variance_reason=?, status='CLOSED' WHERE id=?",
                [now, expected, actualVal, variance, reason.text.trim().isNotEmpty ? reason.text.trim() : null, _drawer!['id']],
              );
              await db.insert('cash_movements', {
                'drawer_id': _drawer!['id'], 'type': 'CLOSE', 'amount': actualVal,
                'reason': reason.text.trim(), 'created_at': now,
              });
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
