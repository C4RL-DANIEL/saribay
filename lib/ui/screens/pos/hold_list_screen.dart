import 'package:flutter/material.dart';

import '../../../data/db/database.dart';

class HoldListScreen extends StatefulWidget {
  const HoldListScreen({super.key});
  @override
  State<HoldListScreen> createState() => _HoldListScreenState();
}

class _HoldListScreenState extends State<HoldListScreen> {
  List<Map<String, dynamic>> _held = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('held_sales', orderBy: 'id DESC');
    setState(() => _held = rows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Held Sales')),
      body: _held.isEmpty
          ? const Center(child: Text('No held sales'))
          : ListView.builder(
              itemCount: _held.length,
              itemBuilder: (ctx, i) {
                final h = _held[i];
                return ListTile(
                  title: Text(h['label'] ?? 'Held #${h['id']}'),
                  subtitle: Text('${h['created_at']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      final db = await AppDatabase.instance.database;
                      await db.delete('held_sales', where: 'id = ?', whereArgs: [h['id']]);
                      _load();
                    },
                  ),
                  onTap: () {
                    Navigator.pop(context, h); // return held sale
                  },
                );
              },
            ),
    );
  }
}
