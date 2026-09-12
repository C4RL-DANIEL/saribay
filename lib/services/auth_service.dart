import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../data/db/database.dart';
import '../data/models/models.dart';
import 'audit_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  String hashPin(String pin) => sha256.convert(utf8.encode('saribay:$pin')).toString();

  /// Ensure an owner exists; called on first run.
  Future<bool> isSetupComplete() async {
    final db = await AppDatabase.instance.database;
    final r = await db.rawQuery("SELECT COUNT(*) c FROM users WHERE role='OWNER'");
    return (r.first['c'] as int) > 0;
  }

  Future<void> createOwner(String name, String username, String pin, {String? storeName}) async {
    final db = await AppDatabase.instance.database;
    await db.insert('users', {
      'branch_id': 1, 'name': name, 'username': username,
      'pin_hash': hashPin(pin), 'role': 'OWNER',
      'created_at': DateTime.now().toIso8601String(),
    });
    if (storeName != null && storeName.isNotEmpty) {
      await db.insert('settings', {'key': 'store_name', 'value': storeName},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await AuditService.instance.log('setup.owner_created', details: username);
  }

  Future<AppUser?> authenticate(String username, String pin) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('users',
        where: 'username = ? AND pin_hash = ? AND is_active = 1',
        whereArgs: [username, hashPin(pin)]);
    final ok = rows.isNotEmpty;
    await db.insert('login_history', {
      'user_id': rows.isNotEmpty ? rows.first['id'] : null,
      'success': ok ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    if (!ok) return null;
    final user = AppUser.fromMap(rows.first);
    await db.rawUpdate('UPDATE users SET last_login_at = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), user.id]);
    AuditService.instance.currentUserId = user.id;
    await AuditService.instance.log('login', details: username);
    return user;
  }

  Future<List<AppUser>> listUsers() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('users', where: 'is_active = 1', orderBy: 'name');
    return rows.map(AppUser.fromMap).toList();
  }

  Future<int> addUser(String name, String username, String pin, String role) async {
    final db = await AppDatabase.instance.database;
    final id = await db.insert('users', {
      'branch_id': 1, 'name': name, 'username': username,
      'pin_hash': hashPin(pin), 'role': role,
      'created_at': DateTime.now().toIso8601String(),
    });
    await AuditService.instance.log('user.created', entity: 'user', entityId: id, details: '$username ($role)');
    return id;
  }

  Future<void> resetPin(int userId, String newPin) async {
    final db = await AppDatabase.instance.database;
    await db.rawUpdate('UPDATE users SET pin_hash = ? WHERE id = ?', [hashPin(newPin), userId]);
    await AuditService.instance.log('user.pin_reset', entity: 'user', entityId: userId);
  }

  Future<void> deactivateUser(int userId) async {
    final db = await AppDatabase.instance.database;
    await db.rawUpdate('UPDATE users SET is_active = 0 WHERE id = ?', [userId]);
    await AuditService.instance.log('user.deactivated', entity: 'user', entityId: userId);
  }
}
