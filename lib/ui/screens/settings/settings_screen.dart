import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../data/db/database.dart';
import '../../../providers/language_provider.dart';
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
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.settingsSaved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Language selection
          Text(l.language, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _buildLanguageSelector(context),

          const SizedBox(height: 24),
          Text(l.storeInformation, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: l.storeName)),
          const SizedBox(height: 12),
          TextField(controller: _addrCtrl, decoration: InputDecoration(labelText: l.address), maxLines: 2),
          const SizedBox(height: 12),
          TextField(controller: _phoneCtrl, decoration: InputDecoration(labelText: l.phone)),

          const SizedBox(height: 24),
          Text(l.currency, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('PHP (₱)'),
              subtitle: Text(l.philippinePeso),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
            ),
          ),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(l.saveSettings),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final options = [
      ('en', 'English 🇺🇸'),
      ('tl_partial', 'Partial Tagalog 🇵🇭'),
      ('tl', 'Full Tagalog 🇵🇭'),
    ];
    return Card(
      child: Column(
        children: options.map((opt) {
          return RadioListTile<String>(
            title: Text(opt.$2),
            value: opt.$1,
            groupValue: lang.languageCode,
            activeColor: const Color(0xFF1B8A5A),
            onChanged: (v) {
              if (v != null) lang.setLanguage(v);
            },
          );
        }).toList(),
      ),
    );
  }
}
