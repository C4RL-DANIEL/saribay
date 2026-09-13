import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../data/db/database.dart';
import '../../../providers/language_provider.dart';
import '../../../services/security_service.dart';
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
  final _apiEndpointCtrl = TextEditingController();
  bool _loading = true;
  bool _autoLogin = false;
  bool _biometricsEnabled = false;
  int _sessionTimeout = 30;

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
    _apiEndpointCtrl.text = map['api_endpoint'] ?? 'https://openrouter.ai/api/v1';
    
    // Load security settings from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _autoLogin = prefs.getBool('auto_login_enabled') ?? false;
    _sessionTimeout = prefs.getInt('session_timeout') ?? 30;
    
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final db = await AppDatabase.instance.database;
    await db.rawInsert("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", ['store_name', _nameCtrl.text.trim()]);
    await db.rawInsert("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", ['store_address', _addrCtrl.text.trim()]);
    await db.rawInsert("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", ['store_phone', _phoneCtrl.text.trim()]);
    await db.rawInsert("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", ['api_endpoint', _apiEndpointCtrl.text.trim()]);
    await SettingsService.instance.load();
    
    // Save security settings to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_login_enabled', _autoLogin);
    await prefs.setInt('session_timeout', _sessionTimeout);
    
    // Update SecurityService
    final security = context.read<SecurityService>();
    await security.setSessionTimeout(_sessionTimeout);
    
    if (mounted) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.settingsSaved)));
    }
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Session Timeout'),
        children: [5, 10, 15, 30, 60].map((mins) => SimpleDialogOption(
          onPressed: () {
            setState(() => _sessionTimeout = mins);
            Navigator.pop(ctx);
          },
          child: Row(
            children: [
              if (_sessionTimeout == mins) const Icon(Icons.check, color: Color(0xFF1B8A5A)),
              if (_sessionTimeout == mins) const SizedBox(width: 8),
              Text('$mins minutes'),
            ],
          ),
        )).toList(),
      ),
    );
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
          // Security Settings
          const Text('Security', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Auto-Login'),
                  subtitle: const Text('Remember username for faster login'),
                  value: _autoLogin,
                  onChanged: (v) => setState(() => _autoLogin = v),
                  secondary: const Icon(Icons.login),
                ),
                SwitchListTile(
                  title: const Text('Biometric Login'),
                  subtitle: const Text('Use fingerprint or face ID'),
                  value: _biometricsEnabled,
                  onChanged: (v) async {
                    final security = context.read<SecurityService>();
                    await security.setBiometrics(v);
                    setState(() => _biometricsEnabled = v);
                  },
                  secondary: const Icon(Icons.fingerprint),
                ),
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('Session Timeout'),
                  subtitle: Text('$_sessionTimeout minutes'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showTimeoutDialog(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(l.saveSettings),
          ),

          const SizedBox(height: 24),
          // AI API Configuration
          const Text('AI API Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _apiEndpointCtrl,
                    decoration: InputDecoration(
                      labelText: 'API Endpoint URL',
                      hintText: 'https://api.xiaomi.com/v1',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.cloud),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter the API endpoint for Xiaomi MiMo v2.5. If the AI shows "Local" status, '
                    'the API may not be configured correctly.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
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
