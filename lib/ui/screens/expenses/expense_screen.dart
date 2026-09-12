import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../data/db/database.dart';
import '../../../data/models/models.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});
  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  List<Expense> _expenses = [];
  String _selectedCategory = 'All';
  bool _loading = true;

  static const _categories = ['All', 'Electricity', 'Water', 'Internet', 'Rent', 'Transportation', 'Salary', 'Supplies', 'Repairs', 'Other'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    final where = _selectedCategory == 'All' ? null : 'category = ?';
    final args = _selectedCategory == 'All' ? null : <Object?>[_selectedCategory];
    final rows = await db.query('expenses', where: where, whereArgs: args, orderBy: 'expense_date DESC');
    setState(() {
      _expenses = rows.map(Expense.fromMap).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _expenses.fold<double>(0, (s, e) => s + e.amount);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          Center(child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(peso(total), style: const TextStyle(fontWeight: FontWeight.bold)),
          )),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(null),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: _categories.map((c) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(c, style: const TextStyle(fontSize: 12)),
                  selected: _selectedCategory == c,
                  onSelected: (_) { setState(() => _selectedCategory = c); _load(); },
                ),
              )).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _expenses.isEmpty
                    ? const Center(child: Text('No expenses'))
                    : ListView.builder(
                        itemCount: _expenses.length,
                        itemBuilder: (ctx, i) {
                          final e = _expenses[i];
                          return ListTile(
                            title: Text(e.description ?? e.category),
                            subtitle: Text('${e.category} · ${e.expenseDate}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(peso(e.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (e.paymentMethod != null) Text(e.paymentMethod!, style: const TextStyle(fontSize: 10)),
                              ],
                            ),
                            onLongPress: () => _delete(e),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showForm(Expense? existing) {
    final desc = TextEditingController(text: existing?.description);
    final amt = TextEditingController(text: existing?.amount.toStringAsFixed(2));
    String cat = existing?.category ?? 'Other';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Expense' : 'Edit Expense'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: cat,
                items: _categories.skip(1).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => cat = v ?? cat,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 8),
              TextField(controller: amt, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₱) *')),
              const SizedBox(height: 8),
              TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amt.text) ?? 0;
              if (amount <= 0) return;
              final db = await AppDatabase.instance.database;
              final data = {
                'category': cat, 'amount': amount,
                'description': desc.text.trim().isNotEmpty ? desc.text.trim() : null,
                'expense_date': DateTime.now().toIso8601String(),
                'created_at': DateTime.now().toIso8601String(),
              };
              if (existing == null) {
                await db.insert('expenses', data);
              } else {
                await db.update('expenses', data, where: 'id = ?', whereArgs: [existing.id]);
              }
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _delete(Expense e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('${e.description ?? e.category} - ${peso(e.amount)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final db = await AppDatabase.instance.database;
              await db.delete('expenses', where: 'id = ?', whereArgs: [e.id]);
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
