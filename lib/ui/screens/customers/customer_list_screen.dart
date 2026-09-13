import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../data/db/database.dart';
import '../../../data/models/models.dart';

/// Customer list with utang balance display.
class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});
  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  List<Customer> _customers = [];
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    final where = _search.isEmpty ? null : 'name LIKE ?';
    final args = _search.isEmpty ? null : <Object?>['%$_search%'];
    final rows = await db.query('customers', where: where, whereArgs: args, orderBy: 'name');
    setState(() {
      _customers = rows.map(Customer.fromMap).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(null),
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search...', prefixIcon: Icon(Icons.search), isDense: true),
              onChanged: (v) { _search = v; _load(); },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? const Center(child: Text('No customers'))
                    : ListView.builder(
                        itemCount: _customers.length,
                        itemBuilder: (ctx, i) {
                          final c = _customers[i];
                          return ListTile(
                            title: Text(c.name),
                            subtitle: Text(c.phone ?? 'No phone'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (c.utangBalance > 0)
                                  Text(peso(c.utangBalance),
                                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                if (c.loyaltyPoints > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, size: 12, color: Colors.amber),
                                      Text(' ${c.loyaltyPoints.toStringAsFixed(0)} pts',
                                          style: const TextStyle(fontSize: 10, color: Colors.amber)),
                                    ],
                                  ),
                                Text('Spent: ${peso(c.totalSpent)}', style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                            onTap: () => _showDetail(c),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showDetail(Customer c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Text(c.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            if (c.phone != null) Text('Phone: ${c.phone}'),
            if (c.address != null) Text('Address: ${c.address}'),
            const Divider(),
            _stat('Total Spent', peso(c.totalSpent)),
            _stat('Loyalty Points', c.loyaltyPoints.toStringAsFixed(0)),
            _stat('Credit Limit', peso(c.creditLimit)),
            _stat('Utang Balance', peso(c.utangBalance)),
            if (c.birthday != null) _stat('Birthday', c.birthday!),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () { Navigator.pop(ctx); _showForm(c); },
                icon: const Icon(Icons.edit), label: const Text('Edit'),
              )),
              const SizedBox(width: 8),
              if (c.utangBalance > 0)
                Expanded(child: FilledButton.icon(
                  onPressed: () { Navigator.pop(ctx); _showPayUtang(c); },
                  icon: const Icon(Icons.payment), label: const Text('Pay Utang'),
                )),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: const TextStyle(color: Colors.grey)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
      ),
    );
  }

  void _showForm(Customer? existing) {
    final name = TextEditingController(text: existing?.name);
    final phone = TextEditingController(text: existing?.phone);
    final address = TextEditingController(text: existing?.address);
    final limit = TextEditingController(text: (existing?.creditLimit ?? 0).toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Customer' : 'Edit Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name *')),
              const SizedBox(height: 8),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 8),
              TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 8),
              TextField(controller: limit, decoration: const InputDecoration(labelText: 'Credit Limit (₱)'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              final db = await AppDatabase.instance.database;
              final data = {
                'name': name.text.trim(),
                'phone': phone.text.trim().isNotEmpty ? phone.text.trim() : null,
                'address': address.text.trim().isNotEmpty ? address.text.trim() : null,
                'credit_limit': double.tryParse(limit.text) ?? 0,
              };
              if (existing == null) {
                data['created_at'] = DateTime.now().toIso8601String();
                await db.insert('customers', data);
              } else {
                await db.update('customers', data, where: 'id = ?', whereArgs: [existing.id]);
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

  void _showPayUtang(Customer c) {
    final ctrl = TextEditingController(text: c.utangBalance.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pay Utang - ${c.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Balance: ${peso(c.utangBalance)}'),
            const SizedBox(height: 8),
            TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text) ?? 0;
              if (amount <= 0 || amount > c.utangBalance) return;
              final db = await AppDatabase.instance.database;
              final newBal = c.utangBalance - amount;
              await db.insert('credit_transactions', {
                'customer_id': c.id, 'type': 'PAYMENT', 'amount': amount,
                'balance_after': newBal, 'created_at': DateTime.now().toIso8601String(),
              });
              await db.rawUpdate('UPDATE customers SET utang_balance = ? WHERE id = ?', [newBal, c.id]);
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }
}
