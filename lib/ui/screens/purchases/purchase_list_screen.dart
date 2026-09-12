import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../data/db/database.dart';
import '../../../data/repositories/product_repository.dart';

class PurchaseListScreen extends StatefulWidget {
  const PurchaseListScreen({super.key});
  @override
  State<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends State<PurchaseListScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    _orders = await db.rawQuery('''
      SELECT po.*, s.name as supplier_name FROM purchase_orders po
      LEFT JOIN suppliers s ON s.id = po.supplier_id
      ORDER BY po.id DESC
    ''');
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purchases')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseFormScreen()));
          _load();
        },
        child: const Icon(Icons.add_shopping_cart),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('No purchase orders'))
              : ListView.builder(
                  itemCount: _orders.length,
                  itemBuilder: (ctx, i) {
                    final o = _orders[i];
                    final status = o['status'] as String;
                    final color = status == 'RECEIVED' ? Colors.green
                        : status == 'CANCELLED' ? Colors.red
                        : status == 'ORDERED' ? Colors.blue
                        : Colors.orange;
                    return ListTile(
                      title: Text(o['po_number'] as String),
                      subtitle: Text('${o['supplier_name']} · ${peso(o['total_cost'] as num?)}'),
                      trailing: Chip(label: Text(status, style: TextStyle(color: color, fontSize: 11))),
                    );
                  },
                ),
    );
  }
}

class PurchaseFormScreen extends StatefulWidget {
  const PurchaseFormScreen({super.key});
  @override
  State<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends State<PurchaseFormScreen> {
  List<Map<String, dynamic>> _suppliers = [];
  int? _selectedSupplier;
  final List<_POItem> _items = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    final db = await AppDatabase.instance.database;
    _suppliers = await db.query('suppliers', orderBy: 'name');
    setState(() {});
  }

  double get _total => _items.fold(0.0, (s, i) => s + i.qty * i.unitCost);

  void _addItem() async {
    final prods = await ProductRepository.instance.list();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5, expand: false,
        builder: (_, scroll) => ListView.builder(
          controller: scroll,
          itemCount: prods.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(prods[i].name),
            subtitle: Text('Last cost: ${peso(prods[i].costPrice)}'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _items.add(_POItem(prods[i].id!, prods[i].name, 1, prods[i].costPrice)));
            },
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedSupplier == null || _items.isEmpty) return;
    setState(() => _saving = true);
    try {
      final db = await AppDatabase.instance.database;
      final now = DateTime.now();
      final poNum = 'PO${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 10000}';
      final poId = await db.insert('purchase_orders', {
        'po_number': poNum, 'supplier_id': _selectedSupplier, 'status': 'DRAFT',
        'total_cost': _total, 'created_at': now.toIso8601String(),
      });
      for (final item in _items) {
        await db.insert('purchase_order_items', {
          'purchase_order_id': poId, 'product_id': item.productId,
          'quantity': item.qty, 'unit_cost': item.unitCost,
          'total': item.qty * item.unitCost,
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase Order')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              value: _selectedSupplier,
              items: _suppliers.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text(s['name'] as String))).toList(),
              onChanged: (v) => setState(() => _selectedSupplier = v),
              decoration: const InputDecoration(labelText: 'Supplier *'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Add Product')),
            const SizedBox(height: 12),
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Text('No items'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) {
                        final item = _items[i];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text('${peso(item.unitCost)} × ${item.qty}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(peso(item.qty * item.unitCost), style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18),
                                onPressed: () => setState(() => _items.removeAt(i)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Text('Total: ${peso(_total)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Create PO'),
            ),
          ],
        ),
      ),
    );
  }
}

class _POItem {
  final int productId;
  final String name;
  double qty;
  double unitCost;
  _POItem(this.productId, this.name, this.qty, this.unitCost);
}
