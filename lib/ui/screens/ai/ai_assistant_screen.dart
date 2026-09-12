import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../data/db/database.dart';
import '../../../services/ai/mimo_api_service.dart';
import '../../../services/ai/store_data_service.dart';

/// AI assistant powered by MiMo v2.5 with local data fallback.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});
  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMsg> _messages = [];
  bool _loading = false;
  int _tab = 0;
  bool _apiAvailable = false;

  static const _systemPrompt = '''
You are SariBay AI, a smart business assistant for a Sari-Sari store in the Philippines.

RULES:
1. ONLY answer questions related to the store's business: sales, inventory, products, customers, utang/credit, suppliers, expenses, cash drawer, profit, promotions, employees, and store operations.
2. If a question is NOT related to the store (e.g., politics, general knowledge, coding), politely decline and redirect to store topics.
3. Use the provided store data to give specific, actionable answers.
4. Always use Philippine Peso (₱) for money amounts.
5. Be concise but helpful. Use bullet points for lists.
6. If data is missing for a question, say so honestly.
7. Suggest specific actions the store owner can take.
8. Never make up data — only use what's provided in the context.

EXAMPLE QUESTIONS YOU CAN ANSWER:
- What should I reorder?
- Which products are most profitable?
- How is my cash flow?
- Who are my best customers?
- Are there any anomalies in my sales?
- What promotions should I run?
- How do my expenses compare to revenue?
- Which products are expiring soon?

DECLINE POLITELY FOR:
- General knowledge questions
- Politics, news, entertainment
- Technical/coding questions
- Anything unrelated to running the store
''';

  static const _suggestions = [
    'What should I reorder?',
    'Analyze my profit margins',
    'Show me my best customers',
    'Are there any anomalies?',
    'Compare this week vs last week',
    'What promotions should I run?',
    'Analyze my expenses',
    'How is my inventory health?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMsg(
        'ai',
        'Hello! I\'m SariBay AI, powered by MiMo v2.5. 🤖\n\n'
        'I analyze your real store data to give you business insights.\n\n'
        'Ask me anything about your store!',
        DateTime.now()));
    _checkApi();
  }

  Future<void> _checkApi() async {
    _apiAvailable = await MimoApiService.instance.healthCheck();
    if (mounted) setState(() {});
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final q = _msgCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _messages.add(_ChatMsg('user', q, DateTime.now()));
      _msgCtrl.clear();
      _loading = true;
    });
    _scrollDown();

    // Build store data context
    String answer;
    try {
      final storeContext = await StoreDataService.instance.buildContext();

      if (_apiAvailable) {
        // Try MiMo API first
        answer = await MimoApiService.instance.chat(
          systemPrompt: _systemPrompt,
          userMessage: q,
          context: storeContext,
        );

        // If network error, fall back to local
        if (answer == 'NETWORK_ERROR') {
          answer = await _localAnswer(q);
          answer += '\n\n_(Using local analysis — API unavailable)_';
        }
      } else {
        // Local analysis fallback
        answer = await _localAnswer(q);
        answer += '\n\n_(Using local analysis — connect to internet for AI-powered answers)_';
      }
    } catch (e) {
      answer = 'Error: $e\n\nPlease try again.';
    }

    setState(() {
      _messages.add(_ChatMsg('ai', answer, DateTime.now()));
      _loading = false;
    });
    _scrollDown();
  }

  /// Local keyword-based analysis as fallback when API is unavailable.
  Future<String> _localAnswer(String question) async {
    final db = await AppDatabase.instance.database;
    final q = question.toLowerCase();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (q.contains('reorder') || q.contains('low stock') || q.contains('restock')) {
      final rows = await db.rawQuery(
          "SELECT name, stock, min_stock FROM products WHERE is_deleted=0 AND min_stock > 0 AND stock <= min_stock ORDER BY stock");
      if (rows.isEmpty) return '✅ All products are well-stocked!';
      return '📦 Products needing reorder:\n${rows.map((r) => '• ${r['name']}: ${r['stock']} left (min: ${r['min_stock']})').join('\n')}';
    }

    if (q.contains('profit') || q.contains('margin') || q.contains('earning')) {
      final rows = await db.rawQuery(
          "SELECT COALESCE(SUM(profit),0) as p, COALESCE(SUM(total),0) as t, COUNT(*) as c "
          "FROM sales WHERE status='COMPLETED' AND created_at >= datetime('now', '-7 days')");
      final r = rows.first;
      final profit = (r['p'] as num?)?.toDouble() ?? 0;
      final total = (r['t'] as num?)?.toDouble() ?? 0;
      final margin = total > 0 ? (profit / total * 100).toStringAsFixed(1) : '0';
      return '💰 This week:\n• Revenue: ${peso(total)}\n• Profit: ${peso(profit)}\n• Margin: $margin%\n• Transactions: ${r['c']}';
    }

    if (q.contains('utang') || q.contains('owe') || q.contains('credit') || q.contains('debt')) {
      final rows = await db.rawQuery(
          "SELECT name, utang_balance FROM customers WHERE utang_balance > 0 ORDER BY utang_balance DESC");
      if (rows.isEmpty) return '✅ No outstanding utang!';
      final total = rows.fold<double>(0, (s, r) => s + (r['utang_balance'] as num).toDouble());
      return '💳 Outstanding utang: ${peso(total)}\n${rows.map((r) => '• ${r['name']}: ${peso(r['utang_balance'] as num?)}').join('\n')}';
    }

    if (q.contains('best') || q.contains('top') || q.contains('sold the most')) {
      final rows = await db.rawQuery('''
        SELECT si.product_name, SUM(si.quantity) as qty, SUM(si.total) as revenue
        FROM sale_items si JOIN sales s ON s.id = si.sale_id
        WHERE s.status = 'COMPLETED' AND date(s.created_at) = ?
        GROUP BY si.product_name ORDER BY qty DESC LIMIT 5
      ''', [today]);
      if (rows.isEmpty) return '📊 No sales today yet.';
      return '📊 Top sellers today:\n${rows.map((r) => '• ${r['product_name']}: ${r['qty']} sold (${peso(r['revenue'] as num?)})').join('\n')}';
    }

    if (q.contains('anomal') || q.contains('suspicious') || q.contains('unusual')) {
      final anomalies = <String>[];
      final refunds = await db.rawQuery("SELECT COUNT(*) as c FROM sales WHERE status='REFUNDED' AND created_at >= datetime('now', '-7 days')");
      if ((refunds.first['c'] as int) > 3) anomalies.add('⚠️ ${refunds.first['c']} refunds this week');
      final adj = await db.rawQuery("SELECT COUNT(*) as c FROM inventory_movements WHERE type='ADJUSTMENT' AND created_at >= datetime('now', '-7 days')");
      if ((adj.first['c'] as int) > 5) anomalies.add('⚠️ ${adj.first['c']} stock adjustments this week');
      if (anomalies.isEmpty) return '✅ No anomalies detected.';
      return '🔍 Anomalies:\n${anomalies.join('\n')}';
    }

    if (q.contains('compare') || q.contains('vs') || q.contains('last week')) {
      final tw = await db.rawQuery("SELECT COALESCE(SUM(total),0) as t FROM sales WHERE status='COMPLETED' AND created_at >= datetime('now', '-7 days')");
      final lw = await db.rawQuery("SELECT COALESCE(SUM(total),0) as t FROM sales WHERE status='COMPLETED' AND created_at >= datetime('now', '-14 days') AND created_at < datetime('now', '-7 days')");
      final thisW = (tw.first['t'] as num).toDouble();
      final lastW = (lw.first['t'] as num).toDouble();
      final diff = lastW > 0 ? ((thisW - lastW) / lastW * 100) : 0.0;
      return '📈 This week: ${peso(thisW)}\n📉 Last week: ${peso(lastW)}\nChange: ${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}%';
    }

    if (q.contains('slow') || q.contains('not selling') || q.contains('dead stock')) {
      final rows = await db.rawQuery('''
        SELECT p.name, COALESCE(SUM(si.quantity),0) as sold
        FROM products p LEFT JOIN sale_items si ON si.product_id = p.id
        LEFT JOIN sales s ON s.id = si.sale_id AND s.status='COMPLETED' AND s.created_at >= datetime('now', '-30 days')
        WHERE p.is_deleted = 0 AND p.is_active = 1 GROUP BY p.id ORDER BY sold ASC LIMIT 5
      ''');
      return '📉 Slowest movers:\n${rows.map((r) => '• ${r['name']}: ${r['sold']} sold').join('\n')}';
    }

    if (q.contains('expense')) {
      final rows = await db.rawQuery(
          "SELECT category, SUM(amount) as total FROM expenses WHERE expense_date >= datetime('now', '-30 days') GROUP BY category ORDER BY total DESC");
      if (rows.isEmpty) return '💸 No expenses recorded this month.';
      return '💸 Expenses (30 days):\n${rows.map((r) => '• ${r['category']}: ${peso(r['total'] as num?)}').join('\n')}';
    }

    if (q.contains('customer') || q.contains('spending')) {
      final rows = await db.rawQuery(
          "SELECT name, total_spent FROM customers ORDER BY total_spent DESC LIMIT 5");
      if (rows.isEmpty) return '👤 No customer data yet.';
      return '👤 Top customers:\n${rows.map((r) => '• ${r['name']}: ${peso(r['total_spent'] as num?)}').join('\n')}';
    }

    return '🤖 I can help with: best sellers, profit, reorder, utang, slow movers, anomalies, comparison, expenses, customers.\n\nTry asking one of these!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _apiAvailable ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _apiAvailable ? Icons.cloud : Icons.cloud_off,
                  size: 14,
                  color: _apiAvailable ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  _apiAvailable ? 'MiMo v2.5' : 'Local',
                  style: TextStyle(
                      fontSize: 11,
                      color: _apiAvailable ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_tab == 0 ? Icons.insights : Icons.chat),
            onPressed: () => setState(() => _tab = _tab == 0 ? 1 : 0),
            tooltip: _tab == 0 ? 'Insights' : 'Chat',
          ),
        ],
      ),
      body: _tab == 0 ? _buildChat() : _buildInsights(),
    );
  }

  Widget _buildChat() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length + (_loading ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == _messages.length) {
                return const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Analyzing...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
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
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.85),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF1B8A5A) : Colors.grey.shade100,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser)
                        const Row(
                          children: [
                            Icon(Icons.smart_toy, size: 14, color: Color(0xFF1B8A5A)),
                            SizedBox(width: 4),
                            Text('SariBay AI',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1B8A5A))),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Text(msg.text, style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87, height: 1.4, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 10, color: isUser ? Colors.white70 : Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: _suggestions.map((s) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 11)),
                onPressed: () { _msgCtrl.text = s; _send(); },
              ),
            )).toList(),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity( 0.05), blurRadius: 4)],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ask about your store...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF1B8A5A),
                child: IconButton(
                  onPressed: _loading ? null : _send,
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsights() {
    return FutureBuilder<List<_Insight>>(
      future: _getInsights(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final insights = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('AI Insights', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Automated analysis of your store data', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            ...insights.map((ins) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: ins.color.withOpacity( 0.15),
                  child: Icon(ins.icon, color: ins.color, size: 20),
                ),
                title: Text(ins.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(ins.message),
              ),
            )),
          ],
        );
      },
    );
  }

  Future<List<_Insight>> _getInsights() async {
    final db = await AppDatabase.instance.database;
    final insights = <_Insight>[];

    final lowStock = await db.rawQuery(
        "SELECT COUNT(*) as c FROM products WHERE is_deleted=0 AND min_stock > 0 AND stock <= min_stock");
    final c = lowStock.first['c'] as int;
    if (c > 0) {
      insights.add(_Insight(Icons.warning_amber, 'Low Stock Alert', '$c products need restocking', Colors.orange));
    }

    final utang = await db.rawQuery(
        "SELECT COUNT(*) as c, COALESCE(SUM(utang_balance),0) as t FROM customers WHERE utang_balance > 0");
    final utangCount = utang.first['c'] as int;
    if (utangCount > 0) {
      insights.add(_Insight(Icons.person_off, 'Outstanding Utang', '${peso(utang.first['t'] as num?)} from $utangCount customers', Colors.deepOrange));
    }

    final today = await db.rawQuery(
        "SELECT COALESCE(SUM(total),0) as t, COALESCE(SUM(profit),0) as p FROM sales "
        "WHERE status='COMPLETED' AND date(created_at) = date('now')");
    final todaySales = (today.first['t'] as num?)?.toDouble() ?? 0;
    if (todaySales > 0) {
      insights.add(_Insight(Icons.today, 'Today\'s Sales', '${peso(todaySales)} revenue, ${peso(today.first['p'] as num?)} profit', Colors.green));
    } else {
      insights.add(_Insight(Icons.today, 'No Sales Today', 'Start selling to track performance', Colors.grey));
    }

    final best = await db.rawQuery('''
      SELECT product_name, SUM(quantity) as qty FROM sale_items si
      JOIN sales s ON s.id = si.sale_id WHERE s.status='COMPLETED'
      AND s.created_at >= datetime('now', '-30 days')
      GROUP BY product_name ORDER BY qty DESC LIMIT 1
    ''');
    if (best.isNotEmpty) {
      insights.add(_Insight(Icons.star, 'Best Seller (30 days)', '${best.first['product_name']}: ${best.first['qty']} sold', Colors.amber));
    }

    final refunds = await db.rawQuery(
        "SELECT COUNT(*) as c FROM sales WHERE status='REFUNDED' AND created_at >= datetime('now', '-7 days')");
    if ((refunds.first['c'] as int) > 3) {
      insights.add(_Insight(Icons.bug_report, 'High Refund Rate', '${refunds.first['c']} refunds this week', Colors.red));
    }

    if (insights.isEmpty) {
      insights.add(_Insight(Icons.info, 'Getting Started', 'Add products and make sales to see AI insights', Colors.blue));
    }

    return insights;
  }
}

class _ChatMsg {
  final String role;
  final String text;
  final DateTime time;
  _ChatMsg(this.role, this.text, this.time);
}

class _Insight {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  _Insight(this.icon, this.title, this.message, this.color);
}
