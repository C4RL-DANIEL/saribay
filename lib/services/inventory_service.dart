import '../data/db/database.dart';
import 'audit_service.dart';

/// Atomic inventory operations with movement tracking & audit.
class InventoryService {
  InventoryService._();
  static final InventoryService instance = InventoryService._();

  /// Changes product stock atomically; creates movement + audit row.
  Future<void> adjustStock({
    required int productId,
    required double change, // negative = decrease
    required String type,   // SALE, PURCHASE, ADJUSTMENT, ...
    int? referenceId,
    String? referenceType,
    String? reason,
    int? userId,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      final rows = await txn.query('products',
          columns: ['stock', 'name'], where: 'id = ?', whereArgs: [productId]);
      if (rows.isEmpty) throw StateError('Product $productId not found');
      final before = (rows.first['stock'] as num).toDouble();
      final after = before + change;
      await txn.rawUpdate(
          'UPDATE products SET stock = ?, updated_at = ? WHERE id = ?',
          [after, DateTime.now().toIso8601String(), productId]);
      await txn.insert('inventory_movements', {
        'product_id': productId,
        'type': type,
        'quantity_change': change,
        'stock_before': before,
        'stock_after': after,
        'reference_type': referenceType,
        'reference_id': referenceId,
        'user_id': userId,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    await AuditService.instance.log('stock_change',
        entity: 'product', entityId: productId,
        details: '$type ${change > 0 ? "+" : ""}$change ($reason)');
  }

  /// Convert pack quantities to base units for unit conversion (case/piece).
  double toBaseUnits(List<Map<String, Object?>> units, double qty, String unitName) {
    for (final u in units) {
      if (u['unit_name'] == unitName) {
        return qty * (u['quantity_in_base'] as num).toDouble();
      }
    }
    return qty; // base unit already
  }
}
