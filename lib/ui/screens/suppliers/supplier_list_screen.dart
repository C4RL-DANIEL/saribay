import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../data/db/database.dart';
import '../../../data/models/models.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});
  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  List<Supplier> _suppliers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('suppliers', orderBy: 'name');
    setState(() {
      _suppliers = rows.map(Supplier.fromMap).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suppliers')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(null),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _suppliers.isEmpty
              ? const Center(child: Text('No suppliers'))
              : ListView.builder(
                  itemCount: _suppliers.length,
                  itemBuilder: (ctx, i) {
                    final s = _suppliers[i];
                    return ListTile(
                      title: Text(s.name),
                      subtitle: Text(s.phone ?? ''),
                      trailing: s.outstandingBalance > 0
                          ? Text(peso(s.outstandingBalance), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
                          : null,
                      onTap: () => _showForm(s),
                    );
                  },
                ),
    );
  }

  void _showForm(Supplier? existing) {
    final name = TextEditingController(text: existing?.name);
    final phone = TextEditingController(text: existing?.phone);
    final address = TextEditingController(text: existing?.address);
    final contact = TextEditingController(text: existing?.contactPerson);
    final email = TextEditingController(text: existing?.email);
    final notes = TextEditingController(text: existing?.notes);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Supplier' : 'Edit Supplier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name *')),
              const SizedBox(height: 8),
              TextField(controller: contact, decoration: const InputDecoration(labelText: 'Contact Person')),
              const SizedBox(height: 8),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 8),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 8),
              TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 8),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
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
                'contact_person': contact.text.trim().isNotEmpty ? contact.text.trim() : null,
                'phone': phone.text.trim().isNotEmpty ? phone.text.trim() : null,
                'email': email.text.trim().isNotEmpty ? email.text.trim() : null,
                'address': address.text.trim().isNotEmpty ? address.text.trim() : null,
                'notes': notes.text.trim().isNotEmpty ? notes.text.trim() : null,
              };
              if (existing == null) {
                data['created_at'] = DateTime.now().toIso8601String();
                await db.insert('suppliers', data);
              } else {
                await db.update('suppliers', data, where: 'id = ?', whereArgs: [existing.id]);
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
}
