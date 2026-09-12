import '../../data/db/database.dart';
import '../../core/utils/money.dart';

/// Gathers real store data to feed into the AI as context.
class StoreDataService {
  StoreDataService._();
  static final StoreDataService instance = StoreDataService._();

  /// Build a comprehensive store data snapshot for the AI.
  Future<String> buildContext() async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final parts = <String>[];

    // Store info
    final settings = await db.query('settings');
    final storeName = settings
        .where((r) => r['key'] == 'store_name')
        .map((r) => r['value'])
        .firstOrNull ?? 'Unknown Store';
    parts.add('Store: $storeName');
    parts.add('Date: $today');
    parts.add('Currency: PHP (₱)');
    parts.add('');

    // Products summary
    final products = await db.rawQuery(
        "SELECT COUNT(*) as total, "
        "SUM(CASE WHEN stock <= 0 THEN 1 ELSE 0 END) as out_of_stock, "
        "SUM(CASE WHEN min_stock > 0 AND stock <= min_stock THEN 1 ELSE 0 END) as low_stock, "
        "COALESCE(SUM(stock * cost_price), 0) as inventory_value "
        "FROM products WHERE is_deleted = 0 AND is_active = 1");
    final p = products.first;
    parts.add('PRODUCTS:');
    parts.add('- Total: ${p['total']}');
    parts.add('- Out of stock: ${p['out_of_stock']}');
    parts.add('- Low stock: ${p['low_stock']}');
    parts.add('- Inventory value (at cost): ${peso(p['inventory_value'] as num?)}');
    parts.add('');

    // Top 10 products by stock
    final topProducts = await db.rawQuery(
        "SELECT name, stock, selling_price, cost_price FROM products "
        "WHERE is_deleted = 0 AND is_active = 1 ORDER BY stock DESC LIMIT 10");
    if (topProducts.isNotEmpty) {
      parts.add('TOP PRODUCTS:');
      for (final tp in topProducts) {
        parts.add('- ${tp['name']}: stock ${tp['stock']}, sell ₱${tp['selling_price']}, cost ₱${tp['cost_price']}');
      }
      parts.add('');
    }

    // Sales today
    final salesToday = await db.rawQuery(
        "SELECT COUNT(*) as cnt, COALESCE(SUM(total),0) as total, COALESCE(SUM(profit),0) as profit "
        "FROM sales WHERE status = 'COMPLETED' AND date(created_at) = ?", [today]);
    final st = salesToday.first;
    parts.add('SALES TODAY:');
    parts.add('- Transactions: ${st['cnt']}');
    parts.add('- Revenue: ${peso(st['total'] as num?)}');
    parts.add('- Profit: ${peso(st['profit'] as num?)}');
    parts.add('');

    // Sales this week
    final salesWeek = await db.rawQuery(
        "SELECT COUNT(*) as cnt, COALESCE(SUM(total),0) as total, COALESCE(SUM(profit),0) as profit "
        "FROM sales WHERE status = 'COMPLETED' AND created_at >= datetime('now', '-7 days')");
    final sw = salesWeek.first;
    parts.add('SALES THIS WEEK (7 days):');
    parts.add('- Transactions: ${sw['cnt']}');
    parts.add('- Revenue: ${peso(sw['total'] as num?)}');
    parts.add('- Profit: ${peso(sw['profit'] as num?)}');
    parts.add('');

    // Sales last week
    final salesLastWeek = await db.rawQuery(
        "SELECT COALESCE(SUM(total),0) as total, COALESCE(SUM(profit),0) as profit "
        "FROM sales WHERE status = 'COMPLETED' AND created_at >= datetime('now', '-14 days') AND created_at < datetime('now', '-7 days')");
    final slw = salesLastWeek.first;
    parts.add('SALES LAST WEEK:');
    parts.add('- Revenue: ${peso(slw['total'] as num?)}');
    parts.add('- Profit: ${peso(slw['profit'] as num?)}');
    parts.add('');

    // Best sellers (30 days)
    final bestSellers = await db.rawQuery(
        "SELECT si.product_name, SUM(si.quantity) as qty, SUM(si.total) as revenue "
        "FROM sale_items si JOIN sales s ON s.id = si.sale_id "
        "WHERE s.status = 'COMPLETED' AND s.created_at >= datetime('now', '-30 days') "
        "GROUP BY si.product_name ORDER BY qty DESC LIMIT 10");
    if (bestSellers.isNotEmpty) {
      parts.add('BEST SELLERS (30 days):');
      for (final bs in bestSellers) {
        parts.add('- ${bs['product_name']}: ${bs['qty']} sold, ${peso(bs['revenue'] as num?)}');
      }
      parts.add('');
    }

    // Slow movers
    final slowMovers = await db.rawQuery(
        "SELECT p.name, COALESCE(SUM(si.quantity),0) as sold "
        "FROM products p LEFT JOIN sale_items si ON si.product_id = p.id "
        "LEFT JOIN sales s ON s.id = si.sale_id AND s.status = 'COMPLETED' AND s.created_at >= datetime('now', '-30 days') "
        "WHERE p.is_deleted = 0 AND p.is_active = 1 "
        "GROUP BY p.id ORDER BY sold ASC LIMIT 5");
    if (slowMovers.isNotEmpty) {
      parts.add('SLOW MOVERS (30 days):');
      for (final sm in slowMovers) {
        parts.add('- ${sm['name']}: ${sm['sold']} sold');
      }
      parts.add('');
    }

    // Low stock items
    final lowStock = await db.rawQuery(
        "SELECT name, stock, min_stock FROM products "
        "WHERE is_deleted = 0 AND min_stock > 0 AND stock <= min_stock ORDER BY stock");
    if (lowStock.isNotEmpty) {
      parts.add('LOW STOCK ITEMS:');
      for (final ls in lowStock) {
        parts.add('- ${ls['name']}: ${ls['stock']} left (min: ${ls['min_stock']})');
      }
      parts.add('');
    }

    // Utang / credit
    final utang = await db.rawQuery(
        "SELECT name, utang_balance, credit_limit FROM customers "
        "WHERE utang_balance > 0 ORDER BY utang_balance DESC");
    if (utang.isNotEmpty) {
      final totalUtang = utang.fold<double>(0, (s, r) => s + (r['utang_balance'] as num).toDouble());
      parts.add('OUTSTANDING UTANG: ${peso(totalUtang)}');
      for (final u in utang) {
        parts.add('- ${u['name']}: ${peso(u['utang_balance'] as num?)} (limit: ${peso(u['credit_limit'] as num?)})');
      }
      parts.add('');
    }

    // Expenses this month
    final expenses = await db.rawQuery(
        "SELECT category, SUM(amount) as total FROM expenses "
        "WHERE expense_date >= datetime('now', '-30 days') GROUP BY category ORDER BY total DESC");
    if (expenses.isNotEmpty) {
      parts.add('EXPENSES (30 days):');
      for (final e in expenses) {
        parts.add('- ${e['category']}: ${peso(e['total'] as num?)}');
      }
      parts.add('');
    }

    // Customers
    final customerCount = await db.rawQuery("SELECT COUNT(*) as c FROM customers WHERE is_active = 1");
    final topCustomers = await db.rawQuery(
        "SELECT name, total_spent, utang_balance FROM customers ORDER BY total_spent DESC LIMIT 5");
    parts.add('CUSTOMERS: ${customerCount.first['c']} active');
    if (topCustomers.isNotEmpty) {
      parts.add('Top customers:');
      for (final c in topCustomers) {
        parts.add('- ${c['name']}: ${peso(c['total_spent'] as num?)} spent, ${peso(c['utang_balance'] as num?)} utang');
      }
      parts.add('');
    }

    // Payment methods breakdown
    final payments = await db.rawQuery(
        "SELECT method_name, COUNT(*) as cnt, SUM(amount) as total "
        "FROM payments WHERE status = 'CONFIRMED' AND created_at >= datetime('now', '-30 days') "
        "GROUP BY method_name ORDER BY total DESC");
    if (payments.isNotEmpty) {
      parts.add('PAYMENT METHODS (30 days):');
      for (final pm in payments) {
        parts.add('- ${pm['method_name']}: ${peso(pm['total'] as num?)} (${pm['cnt']} txns)');
      }
      parts.add('');
    }

    // Anomalies
    final refunds = await db.rawQuery(
        "SELECT COUNT(*) as c FROM sales WHERE status = 'REFUNDED' AND created_at >= datetime('now', '-7 days')");
    final largeDiscounts = await db.rawQuery(
        "SELECT COUNT(*) as c FROM sales WHERE discount > total * 0.2 AND status = 'COMPLETED' AND created_at >= datetime('now', '-7 days')");
    final cashVariance = await db.rawQuery(
        "SELECT COUNT(*) as c FROM cash_drawers WHERE ABS(variance) > 100 AND created_at >= datetime('now', '-30 days')");

    parts.add('ANOMALY INDICATORS:');
    parts.add('- Refunds this week: ${refunds.first['c']}');
    parts.add('- Large discounts (>20%): ${largeDiscounts.first['c']}');
    parts.add('- Cash variance >₱100: ${cashVariance.first['c']}');
    parts.add('');

    return parts.join('\n');
  }
}
