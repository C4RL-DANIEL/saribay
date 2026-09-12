import 'package:flutter/material.dart';

import '../../../data/db/database.dart';
import '../../../data/models/models.dart';

class PromotionScreen extends StatefulWidget {
  const PromotionScreen({super.key});
  @override
  State<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends State<PromotionScreen> {
  List<Promotion> _promos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('promotions', orderBy: 'id DESC');
    _promos = rows.map(Promotion.fromMap).toList();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promotions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(null),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _promos.isEmpty
              ? const Center(child: Text('No promotions'))
              : ListView.builder(
                  itemCount: _promos.length,
                  itemBuilder: (ctx, i) {
                    final p = _promos[i];
                    return SwitchListTile(
                      title: Text(p.name),
                      subtitle: Text('${p.type} ${p.discountPercent != null ? "${p.discountPercent}% off" : ""}${p.discountAmount != null ? "₱${p.discountAmount} off" : ""}'),
                      value: p.isActive,
                      onChanged: (v) async {
                        final db = await AppDatabase.instance.database;
                        await db.rawUpdate('UPDATE promotions SET is_active = ? WHERE id = ?', [v ? 1 : 0, p.id]);
                        _load();
                      },
                      secondary: Icon(p.isActive ? Icons.local_offer : Icons.local_offer_outlined),
                    );
                  },
                ),
    );
  }

  void _showForm(Promotion? existing) {
    final name = TextEditingController(text: existing?.name);
    final discPct = TextEditingController(text: existing?.discountPercent?.toString() ?? '');
    final discAmt = TextEditingController(text: existing?.discountAmount?.toString() ?? '');
    String type = existing?.type ?? 'PERCENT';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Promotion'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name *')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'PERCENT', child: Text('% Discount')),
                  DropdownMenuItem(value: 'FIXED', child: Text('₱ Discount')),
                ],
                onChanged: (v) => type = v ?? type,
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 8),
              TextField(controller: discPct, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount %')),
              const SizedBox(height: 8),
              TextField(controller: discAmt, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount ₱')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              final db = await AppDatabase.instance.database;
              await db.insert('promotions', {
                'name': name.text.trim(), 'type': type,
                'discount_percent': double.tryParse(discPct.text),
                'discount_amount': double.tryParse(discAmt.text),
                'is_active': 1, 'created_at': DateTime.now().toIso8601String(),
              });
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
