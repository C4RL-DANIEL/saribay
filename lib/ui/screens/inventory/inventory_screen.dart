import 'package:flutter/material.dart';

import '../../../data/db/database.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../services/inventory_service.dart';

/// Inventory management: low stock alerts, movements, stock count.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  int _tab = 0;
  List<Map<String, dynamic>> _lowStock = [];
  List<Map<String, dynamic>> _movements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    _lowStock = await ProductRepository.instance.lowStock();
    _movements = await db.rawQuery(
        'SELECT m.*, p.name as product_name FROM inventory_movements m '
        'LEFT JOIN products p ON p.id = m.product_id '
        'ORDER BY m.id DESC LIMIT 100');
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: Column(
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Low Stock')),
              ButtonSegment(value: 1, label: Text('Movements')),
            ],
            selected: {_tab},
            onSelectionChanged: (v) => setState(() => _tab = v.first),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tab == 0
                    ? _buildLowStock()
                    : _buildMovements(),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStock() {
    if (_lowStock.isEmpty) return const Center(child: Text('No low stock items'));
    return ListView.builder(
      itemCount: _lowStock.length,
      itemBuilder: (ctx, i) {
        final p = _lowStock[i];
        return ListTile(
          leading: const Icon(Icons.warning_amber, color: Colors.orange),
          title: Text(p['name'] as String),
          subtitle: Text('Stock: ${(p['stock'] as num).toStringAsFixed(0)} / Min: ${(p['min_stock'] as num).toStringAsFixed(0)}'),
          trailing: FilledButton.tonal(
            onPressed: () => _showAdjustDialog(p),
            child: const Text('Adjust'),
          ),
        );
      },
    );
  }

  Widget _buildMovements() {
    if (_movements.isEmpty) return const Center(child: Text('No movements yet'));
    return ListView.builder(
      itemCount: _movements.length,
      itemBuilder: (ctx, i) {
        final m = _movements[i];
        final change = (m['quantity_change'] as num).toDouble();
        return ListTile(
          leading: Icon(change > 0 ? Icons.add_circle : Icons.remove_circle,
              color: change > 0 ? Colors.green : Colors.red),
          title: Text('${m['product_name']} (${m['type']})'),
          subtitle: Text('${change > 0 ? "+" : ""}${change.toStringAsFixed(0)} → Stock: ${(m['stock_after'] as num).toStringAsFixed(0)}'),
          trailing: Text(m['created_at'] as String, style: const TextStyle(fontSize: 11)),
        );
      },
    );
  }

  void _showAdjustDialog(Map<String, dynamic> product) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust: ${product['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current stock: ${(product['stock'] as num).toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'New count (physical)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final newStock = double.tryParse(ctrl.text) ?? 0;
              final diff = newStock - (product['stock'] as num).toDouble();
              if (diff != 0) {
                await InventoryService.instance.adjustStock(
                  productId: product['id'] as int,
                  change: diff,
                  type: 'ADJUSTMENT',
                  reason: 'Stock count adjustment',
                );
              }
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('Adjust'),
          ),
        ],
      ),
    );
  }
}
