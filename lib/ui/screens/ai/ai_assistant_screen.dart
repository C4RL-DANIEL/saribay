import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../data/db/database.dart';

/// AI assistant that queries real store data to answer business questions.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});
  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _msgCtrl = TextEditingController();
  final List<_ChatMsg> _messages = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMsg(
        'ai',
        'Hello! I\'m your SariBay AI Assistant. Ask me anything about your store:\n'
        '• What sold the most today?\n'
        '• How much profit did I make this week?\n'
        '• Which products should I reorder?\n'
        '• Who owes me money?\n'
        '• What products are not selling?\n'
        '• Why did sales decrease?\n'
        '• Which products have the highest margin?'));
  }

  Future<void> _send() async {
    final q = _msgCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _messages.add(_ChatMsg('user', q));
      _msgCtrl.clear();
      _loading = true;
    });

    final answer = await _answer(q);
    setState(() {
      _messages.add(_ChatMsg('ai', answer));
      _loading = false;
    });
  }

  Future<String> _answer(String question) async {
    final db = await AppDatabase.instance.database;
    final q = question.toLowerCase();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // Best sellers today
    if (q.contains('sold the most') || q.contains('best sell') || q.contains('top product')) {
      final rows = await db.rawQuery('''
        SELECT si.product_name, SUM(si.quantity) as qty, SUM(si.total) as revenue
        FROM sale_items si JOIN sales s ON s.id = si.sale_id
        WHERE s.status = 'COMPLETED' AND date(s.created_at) = ?
        GROUP BY si.product_name ORDER BY qty DESC LIMIT 5
      ''', [today]);
      if (rows.isEmpty) return 'No sales today yet.';
      return 'Top sellers today:\n${rows.map((r) => '• ${r['product_name']}: ${r['qty']} sold (${peso(r['revenue'] as num?)})').join('\n')}';
    }

    // Profit this week
    if (q.contains('profit') || q.contains('earning')) {
      final rows = await db.rawQuery(
          "SELECT COALESCE(SUM(profit),0) as p, COALESCE(SUM(total),0) as t, COUNT(*) as c "
          "FROM sales WHERE status='COMPLETED' AND created_at >= datetime('now', '-7 days')");
      final r = rows.first;
      return 'This week:\n• Revenue: ${peso(r['t'] as num?)}\n• Profit: ${peso(r['p'] as num?)}\n• Transactions: ${r['c']}';
    }

    // Reorder
    if (q.contains('reorder') || q.contains('low stock')) {
      final rows = await db.rawQuery(
          "SELECT name, stock, min_stock FROM products WHERE is_deleted=0 AND min_stock > 0 AND stock <= min_stock ORDER BY stock");
      if (rows.isEmpty) return 'All products are well-stocked!';
      return 'Products needing reorder:\n${rows.map((r) => '• ${r['name']}: ${r['stock']} left (min: ${r['min_stock']})').join('\n')}';
    }

    // Utang / owes money
    if (q.contains('owes') || q.contains('utang') || q.contains('credit') || q.contains('debt')) {
      final rows = await db.rawQuery(
          "SELECT name, utang_balance FROM customers WHERE utang_balance > 0 ORDER BY utang_balance DESC");
      if (rows.isEmpty) return 'No outstanding utang!';
      final total = rows.fold<double>(0, (s, r) => s + (r['utang_balance'] as num).toDouble());
      return 'Outstanding utang: ${peso(total)}\n${rows.map((r) => '• ${r['name']}: ${peso(r['utang_balance'] as num?)}').join('\n')}';
    }

    // Not selling / slow movers
    if (q.contains('not selling') || q.contains('slow') || q.contains('dead stock')) {
      final rows = await db.rawQuery('''
        SELECT p.name, p.stock, p.cost_price, COALESCE(SUM(si.quantity),0) as sold
        FROM products p LEFT JOIN sale_items si ON si.product_id = p.id
        LEFT JOIN sales s ON s.id = si.sale_id AND s.status='COMPLETED' AND s.created_at >= datetime('now', '-30 days')
        WHERE p.is_deleted = 0 AND p.is_active = 1
        GROUP BY p.id ORDER BY sold ASC LIMIT 5
      ''');
      return 'Slowest movers (30 days):\n${rows.map((r) => '• ${r['name']}: ${r['sold']} sold, ${r['stock']} in stock').join('\n')}';
    }

    // Highest margin
    if (q.contains('margin') || q.contains('most profit')) {
      final rows = await db.rawQuery(
          "SELECT name, selling_price, cost_price, "
          "(selling_price - cost_price) as margin, "
          "CASE WHEN selling_price > 0 THEN ((selling_price - cost_price) / selling_price * 100) ELSE 0 END as margin_pct "
          "FROM products WHERE is_deleted=0 AND selling_price > 0 AND cost_price > 0 ORDER BY margin DESC LIMIT 5");
      return 'Highest margin products:\n${rows.map((r) => '• ${r["name"]}: ₱${r["margin"]} (${(r["margin_pct"] as num?)?.toStringAsFixed(0) ?? "0"}%)').join('\n')}';
    }

    // Busiest time
    if (q.contains('busiest') || q.contains('peak')) {
      final rows = await db.rawQuery(
          "SELECT strftime('%H', created_at) as hour, COUNT(*) as cnt "
          "FROM sales WHERE status='COMPLETED' AND created_at >= datetime('now', '-30 days') "
          "GROUP BY hour ORDER BY cnt DESC LIMIT 3");
      if (rows.isEmpty) return 'Not enough data for peak hours.';
      return 'Busiest hours:\n${rows.map((r) => '• ${r["hour"]}:00 — ${r["cnt"]} sales').join('\n')}';
    }

    // Sales decrease
    if (q.contains('decrease') || q.contains('drop') || q.contains('why')) {
      final thisWeek = await db.rawQuery(
          "SELECT COALESCE(SUM(total),0) as t FROM sales WHERE status='COMPLETED' AND created_at >= datetime('now', '-7 days')");
      final lastWeek = await db.rawQuery(
          "SELECT COALESCE(SUM(total),0) as t FROM sales WHERE status='COMPLETED' AND created_at >= datetime('now', '-14 days') AND created_at < datetime('now', '-7 days')");
      final tw = (thisWeek.first['t'] as num).toDouble();
      final lw = (lastWeek.first['t'] as num).toDouble();
      final diff = lw > 0 ? ((tw - lw) / lw * 100) : 0.0;
      if (tw >= lw) return 'Sales are UP ${diff.abs().toStringAsFixed(1)}% this week vs last week. Good job!';
      return 'Sales are DOWN ${diff.abs().toStringAsFixed(1)}% this week vs last week.\nThis week: ${peso(tw)} vs last week: ${peso(lw)}\nPossible causes: fewer transactions, lower average order value, or seasonal variation.';
    }

    return 'I can help with: best sellers, profit, reorder, utang, slow movers, margins, peak hours, sales trends. Try asking one of those!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final msg = _messages[i];
                final isUser = msg.role == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg.text),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Ask about your store...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _loading ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMsg {
  final String role;
  final String text;
  _ChatMsg(this.role, this.text);
}
