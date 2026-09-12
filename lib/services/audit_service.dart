import '../data/db/database.dart';

/// Records every sensitive action: user, action, object, before/after, timestamp.
class AuditService {
  AuditService._();
  static final AuditService instance = AuditService._();

  int? currentUserId;

  Future<void> log(String action, {
    String? entity, int? entityId,
    String? previousValue, String? newValue, String? details,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.insert('audit_logs', {
      'user_id': currentUserId,
      'action': action,
      'entity': entity,
      'entity_id': entityId,
      'previous_value': previousValue,
      'new_value': newValue ?? details,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> recent({int limit = 200}) async {
    final db = await AppDatabase.instance.database;
    return db.rawQuery('''
      SELECT a.*, u.name AS user_name FROM audit_logs a
      LEFT JOIN users u ON u.id = a.user_id
      ORDER BY a.id DESC LIMIT ?
    ''', [limit]);
  }
}
