import 'package:flutter/material.dart';

import '../../../data/db/database.dart';
import '../../../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('settings');
    final map = {for (var r in rows) r['key'] as String: r['value'] as String? ?? ''};
    _nameCtrl.text = map['store_name'] ?? '';
    _addrCtrl.text = map['store_address'] ?? '';
    _phoneCtrl.text = map['store_phone'] ?? '';
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final db = await AppDatabase.instance.database;
    await db.rawInsert("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", ['store_name', _nameCtrl.text.trim()]);
    await db.rawInsert("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", ['store_address', _addrCtrl.text.trim()]);
    await db.rawInsert("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", ['store_phone', _phoneCtrl.text.trim()]);
    await SettingsService.instance.load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Store Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Store Name')),
          const SizedBox(height: 12),
          TextField(controller: _addrCtrl, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
          const SizedBox(height: 12),
          TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 24),
          const Text('Currency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.attach_money),
              title: Text('PHP (₱)'),
              subtitle: Text('Philippine Peso — default and only'),
              trailing: Icon(Icons.check_circle, color: Colors.green),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}
