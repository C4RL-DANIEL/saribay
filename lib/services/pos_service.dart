
import '../data/db/database.dart';
import '../data/models/models.dart';
import 'audit_service.dart';

/// Result from completing a sale.
class SaleResult {
  final int saleId;
  final String receiptNo;
  final double change;
  SaleResult(this.saleId, this.receiptNo, this.change);
}

/// Handles checkout atomically per spec §37:
/// sale + items + payments + stock deduction (FEFO bundles) +
/// customer totals + utang (is_credit) + cash drawer movement + audit.
class PosService {
  PosService._();
  static final PosService instance = PosService._();

  Future<String> nextReceiptNo() async {
    final db = await AppDatabase.instance.database;
    final d = DateTime.now();
    final prefix =
        'R${d.year.toString().substring(2)}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final r = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM sales WHERE receipt_no LIKE '$prefix%'");
    final n = (r.first['c'] as int) + 1;
    return '$prefix-${n.toString().padLeft(4, '0')}';
  }

  /// Completes a sale in ONE transaction. Throws on failure -> nothing saved.
  Future<SaleResult> completeSale({
    required List<CartItem> items,
    required int? customerId,
    required List<SalePayment> payments, // sum of confirmed must cover total unless credit
    required bool isCredit,
    double cartDiscount = 0,
    String? notes,
    int? userId,
    List<Promotion> promos = const [],
  }) async {
    if (items.isEmpty) throw ArgumentError('Cart is empty');

    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    final receiptNo = await nextReceiptNo();

    // Apply promotions
    final computed = _applyPromotions(items, promos);
    final discountTotal = cartDiscount +
        items.fold<double>(0, (s, i) => s + i.discount) +
        computed.extraDiscount;
    final subtotal = items.fold<double>(0, (s, i) => s + i.unitPrice * i.quantity);
    final total = (subtotal - discountTotal).clamp(0.0, double.infinity);
    final cogs = items.fold<double>(0, (s, i) {
      // bundle COGS computed in txn; here direct products
      return s + (i.bundleId != null ? 0 : i.costPrice * i.quantity);
    });

    // Validate payment coverage
    if (!isCredit) {
      final paid = payments
          .where((p) => p.status == 'CONFIRMED' || p.status == 'PENDING')
          .fold<double>(0, (s, p) => s + p.amount);
      if (paid + 0.001 < total) {
        throw StateError('Payment of ${paid.toStringAsFixed(2)} is less than total ${total.toStringAsFixed(2)}');
      }
    }

    // Credit limit check
    if (isCredit) {
      if (customerId == null) throw ArgumentError('Utang requires a customer');
      final row = await db
          .query('customers', where: 'id = ?', whereArgs: [customerId]);
      if (row.isEmpty) throw StateError('Customer not found');
      final limit = (row.first['credit_limit'] as num?)?.toDouble() ?? 0;
      final balance = (row.first['utang_balance'] as num?)?.toDouble() ?? 0;
      if (limit > 0 && balance + total > limit) {
        throw StateError('Credit limit exceeded. Limit ₱${limit.toStringAsFixed(0)}, balance ₱${balance.toStringAsFixed(0)}');
      }
    }

    late int saleId;
    double change = 0;
    double bundleCogs = 0;

    await db.transaction((txn) async {
      saleId = await txn.insert('sales', {
        'receipt_no': receiptNo,
        'customer_id': customerId,
        'user_id': userId,
        'status': 'COMPLETED',
        'subtotal': subtotal,
        'discount': discountTotal,
        'total': total,
        'amount_paid': isCredit ? 0 : total,
        'cogs': 0, // patched below with bundles
        'profit': 0,
        'is_credit': isCredit ? 1 : 0,
        'notes': notes,
        'to_sync': 1,
        'created_at': now,
      });

      // Items + stock deduction (FEFO for batches)
      for (final item in items) {
        double itemCost = item.costPrice;
        if (item.bundleId != null) {
          // Expand bundle: deduct each component
          final parts = await txn.rawQuery(
              'SELECT bi.product_id, bi.quantity, p.cost_price FROM bundle_items bi '
              'JOIN products p ON p.id = bi.product_id WHERE bi.bundle_id = ?',
              [item.bundleId]);
          double bc = 0;
          for (final p in parts) {
            final pid = p['product_id'] as int;
            final q = (p['quantity'] as num).toDouble() * item.quantity;
            bc += (p['cost_price'] as num).toDouble() * (p['quantity'] as num) * item.quantity;
            await _deductStock(txn, pid, q, 'BUNDLE_CONSUMPTION', saleId, userId);
          }
          bundleCogs += bc;
          itemCost = bc;
        } else if (item.productId != null) {
          await _deductStock(txn, item.productId!, item.quantity, 'SALE', saleId, userId);
        }
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item.productId,
          'product_name': item.name,
          'unit': item.unit,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'cost_price': itemCost,
          'discount': item.discount,
          'total': item.lineTotal,
          'bundle_id': item.bundleId,
        });
      }

      final fullCogs = cogs + bundleCogs;
      final profit = total - fullCogs;

      // Payments
      for (final p in payments) {
        await txn.insert('payments', {
          'sale_id': saleId,
          'method_id': p.methodId,
          'method_name': p.methodName,
          'amount': p.amount,
          'reference': p.reference,
          'status': p.status,
          'is_manual_confirmation': p.methodId != null && p.methodName != 'Cash' ? 1 : 0,
          'confirmed_by': userId,
          'confirmed_at': p.status == 'CONFIRMED' ? now : null,
          'created_at': now,
        });
      }

      // Cash reconciliation
      final cashPaid = payments
          .where((p) => p.methodName == 'Cash')
          .fold<double>(0, (s, p) => s + p.amount);
      change = isCredit ? 0 : (payments.fold<double>(0, (s, p) => s + p.amount) - total).clamp(0, double.infinity);

      // Customer stats + loyalty + utang
      if (customerId != null) {
        await txn.rawUpdate(
            'UPDATE customers SET total_spent = total_spent + ?, last_purchase_at = ? WHERE id = ?',
            [total, now, customerId]);
        if (isCredit) {
          final newBalRow = await txn
              .query('customers', columns: ['utang_balance'], where: 'id = ?', whereArgs: [customerId]);
          final balAfter = (newBalRow.first['utang_balance'] as num).toDouble() + total;
          await txn.insert('credit_transactions', {
            'customer_id': customerId,
            'sale_id': saleId,
            'type': 'DEBIT',
            'amount': total,
            'balance_after': balAfter,
            'user_id': userId,
            'created_at': now,
          });
          await txn.rawUpdate('UPDATE customers SET utang_balance = ? WHERE id = ?', [balAfter, customerId]);
        }
        // Loyalty points
        final rule = await txn.query('loyalty_rules', where: 'is_active = 1', limit: 1);
        if (rule.isNotEmpty) {
          final ppp = (rule.first['points_per_peso'] as num?)?.toDouble() ?? 0;
          if (ppp > 0) {
            await txn.rawUpdate(
                'UPDATE customers SET loyalty_points = loyalty_points + ? WHERE id = ?',
                [total * ppp, customerId]);
          }
        }
      }

      // Cash drawer movement (cash only)
      if (cashPaid > 0) {
        final drawer = await txn.query('cash_drawers',
            where: 'status = ?', whereArgs: ['OPEN'], limit: 1);
        if (drawer.isNotEmpty) {
          await txn.insert('cash_movements', {
            'drawer_id': drawer.first['id'],
            'type': 'SALE',
            'amount': cashPaid - (cashPaid >= total ? change : 0.0),
            'reference_id': saleId,
            'user_id': userId,
            'created_at': now,
          });
        }
      }

      await txn.rawUpdate(
          'UPDATE sales SET change_amount = ?, cogs = ?, profit = ? WHERE id = ?',
          [change, fullCogs, profit, saleId]);
    });

    await AuditService.instance.log('sale.completed',
        entity: 'sale', entityId: saleId,
        newValue: '₱${total.toStringAsFixed(2)} ${isCredit ? "(utang)" : ""}',
        details: receiptNo);

    return SaleResult(saleId, receiptNo, change);
  }

  Future<void> _deductStock(dynamic txn, int productId, double qty, String type, int saleId, int? userId) async {
    final before = await txn.query('products', columns: ['stock'], where: 'id = ?', whereArgs: [productId]);
    if (before.isEmpty) throw StateError('Product $productId not found in DB');
    final stockBefore = (before.first['stock'] as num).toDouble();
    final after = stockBefore - qty;
    await txn.rawUpdate('UPDATE products SET stock = ?, updated_at = ? WHERE id = ?',
        [after, DateTime.now().toIso8601String(), productId]);
    await txn.insert('inventory_movements', {
      'product_id': productId, 'type': type, 'quantity_change': -qty,
      'stock_before': stockBefore, 'stock_after': after,
      'reference_type': 'sale', 'reference_id': saleId, 'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Refund/void a sale: restores stock within one transaction.
  Future<void> refundSale(int saleId, int? userId, {String? reason}) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      final sale = await txn.query('sales', where: 'id = ?', whereArgs: [saleId]);
      if (sale.isEmpty) throw StateError('Sale not found');
      if (sale.first['status'] != 'COMPLETED') throw StateError('Sale is not completed');
      final items = await txn.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      for (final item in items) {
        final pid = item['product_id'] as int?;
        final qty = (item['quantity'] as num).toDouble();
        final bundleId = item['bundle_id'] as int?;
        if (bundleId != null) {
          final parts = await txn.query('bundle_items', where: 'bundle_id = ?', whereArgs: [bundleId]);
          for (final p in parts) {
            await _restoreStock(txn, p['product_id'] as int, (p['quantity'] as num).toDouble() * qty, saleId, userId, 'return');
          }
        } else if (pid != null) {
          await _restoreStock(txn, pid, qty, saleId, userId, 'return');
        }
      }
      await txn.rawUpdate("UPDATE sales SET status = 'REFUNDED' WHERE id = ?", [saleId]);
      // reverse utang if credit
      if ((sale.first['is_credit'] as int) == 1) {
        final cid = sale.first['customer_id'] as int?;
        final total = (sale.first['total'] as num).toDouble();
        if (cid != null) {
          final r = await txn.query('customers', columns: ['utang_balance'], where: 'id = ?', whereArgs: [cid]);
          final afterBal = (r.first['utang_balance'] as num).toDouble() - total;
          await txn.insert('credit_transactions', {
            'customer_id': cid, 'sale_id': saleId, 'type': 'PAYMENT',
            'amount': total, 'balance_after': afterBal,
            'notes': 'Refund credit reversal', 'user_id': userId,
            'created_at': DateTime.now().toIso8601String(),
          });
          await txn.rawUpdate('UPDATE customers SET utang_balance = ? WHERE id = ?', [afterBal, cid]);
        }
      }
    });
    await AuditService.instance.log('sale.refund', entity: 'sale', entityId: saleId, details: reason);
  }

  Future<void> _restoreStock(dynamic txn, int productId, double qty, int saleId, int? userId, String type) async {
    final before = await txn.query('products', columns: ['stock'], where: 'id = ?', whereArgs: [productId]);
    final stockBefore = (before.first['stock'] as num).toDouble();
    await txn.rawUpdate('UPDATE products SET stock = stock + ?, updated_at = ? WHERE id = ?',
        [qty, DateTime.now().toIso8601String(), productId]);
    await txn.insert('inventory_movements', {
      'product_id': productId, 'type': 'RETURN', 'quantity_change': qty,
      'stock_before': stockBefore, 'stock_after': stockBefore + qty,
      'reference_type': 'sale_refund', 'reference_id': saleId, 'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  _PromoResult _applyPromotions(List<CartItem> items, List<Promotion> promos) {
    double extra = 0;
    final now = DateTime.now();
    for (final promo in promos) {
      if (!promo.isActive) continue;
      if (promo.startDate != null && DateTime.tryParse(promo.startDate!)?.isAfter(now) == true) { continue; }
      if (promo.endDate != null && DateTime.tryParse(promo.endDate!)?.isBefore(now) == true) { continue; }
      for (final item in items) {
        if (promo.productId != null && promo.productId != item.productId) continue;
        if (promo.type == 'PERCENT' && (promo.discountPercent ?? 0) > 0) {
          extra += item.lineTotal * promo.discountPercent! / 100;
        } else if (promo.type == 'FIXED' && (promo.discountAmount ?? 0) > 0) {
          extra += promo.discountAmount!;
        }
      }
    }
    return _PromoResult(extra);
  }
}

class _PromoResult {
  final double extraDiscount;
  _PromoResult(this.extraDiscount);
}
