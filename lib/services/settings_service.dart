import 'package:sqflite/sqflite.dart';

import '../data/db/database.dart';

/// Key-value settings store backed by SQLite.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  final Map<String, String> _cache = {};
  bool _loaded = false;

  Future<void> load() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('settings');
    _cache
      ..clear()
      ..addEntries(rows.map((r) => MapEntry(r['key'] as String, r['value'] as String? ?? '')));
    _loaded = true;
  }

  Future<String> get(String key, {String fallback = ''}) async {
    if (!_loaded) await load();
    return _cache[key] ?? fallback;
  }

  String getSync(String key, {String fallback = ''}) => _cache[key] ?? fallback;

  Future<void> set(String key, String value) async {
    final db = await AppDatabase.instance.database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _cache[key] = value;
  }

  Future<String> storeName() => get('store_name', fallback: 'My Sari-Sari Store');
  String currencySymbol() => '\u20B1';
}
