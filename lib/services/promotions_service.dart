import '../../data/db/database.dart';
import '../../data/models/models.dart';

/// Promotions and discounts service.
class PromotionsService {
  PromotionsService._();
  static final PromotionsService instance = PromotionsService._();

  /// Get active promotions
  Future<List<Promotion>> getActivePromotions() async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final rows = await db.rawQuery('''
      SELECT * FROM promotions 
      WHERE is_active = 1 
        AND (start_date IS NULL OR start_date <= ?)
        AND (end_date IS NULL OR end_date >= ?)
    ''', [now.toIso8601String(), now.toIso8601String()]);
    return rows.map((r) => Promotion.fromMap(r)).toList();
  }

  /// Apply promotions to cart items
  Future<double> applyPromotions(List<CartItem> items, int? customerId) async {
    double totalDiscount = 0;
    final promotions = await getActivePromotions();
    
    for (final promo in promotions) {
      if (promo.type == 'PERCENT' && promo.discountPercent != null) {
        // Apply percentage discount to matching items
        for (final item in items) {
          if (promo.productId == null || promo.productId == item.productId) {
            totalDiscount += item.unitPrice * item.quantity * (promo.discountPercent! / 100);
          }
        }
      } else if (promo.type == 'FIXED' && promo.discountAmount != null) {
        // Apply fixed discount
        totalDiscount += promo.discountAmount!;
      } else if (promo.type == 'BUY_X_GET_Y' && promo.buyQty != null && promo.getQty != null) {
        // Buy X Get Y logic
        for (final item in items) {
          if (promo.productId == null || promo.productId == item.productId) {
            final sets = (item.quantity / (promo.buyQty! + promo.getQty!)).floor();
            totalDiscount += sets * promo.getQty! * item.unitPrice;
          }
        }
      }
    }
    
    return totalDiscount;
  }

  /// Check if a product has a promotional price
  Future<double?> getPromotionalPrice(int productId) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final rows = await db.rawQuery('''
      SELECT * FROM promotions 
      WHERE is_active = 1 
        AND product_id = ?
        AND (start_date IS NULL OR start_date <= ?)
        AND (end_date IS NULL OR end_date >= ?)
      LIMIT 1
    ''', [productId, now.toIso8601String(), now.toIso8601String()]);
    
    if (rows.isEmpty) return null;
    final promo = Promotion.fromMap(rows.first);
    
    if (promo.type == 'PERCENT') {
      // Get product price and apply percentage
      final product = await db.query('products', where: 'id = ?', whereArgs: [productId]);
      if (product.isNotEmpty) {
        final price = (product.first['selling_price'] as num?)?.toDouble() ?? 0;
        return price * (1 - (promo.discountPercent ?? 0) / 100);
      }
    } else if (promo.type == 'FIXED') {
      final product = await db.query('products', where: 'id = ?', whereArgs: [productId]);
      if (product.isNotEmpty) {
        final price = (product.first['selling_price'] as num?)?.toDouble() ?? 0;
        return (price - (promo.discountAmount ?? 0)).clamp(0, double.infinity);
      }
    }
    
    return null;
  }

  /// Calculate loyalty points for a purchase
  Future<int> calculateLoyaltyPoints(double totalAmount, int? customerId) async {
    if (customerId == null) return 0;
    
    final db = await AppDatabase.instance.database;
    
    // Get customer loyalty info
    final customer = await db.query('customers', where: 'id = ?', whereArgs: [customerId]);
    if (customer.isEmpty) return 0;
    
    // Get loyalty rules
    final rules = await db.query('loyalty_rules', where: 'is_active = 1', limit: 1);
    if (rules.isEmpty) return 0;
    
    final pointsPerPeso = (rules.first['points_per_peso'] as num?)?.toDouble() ?? 0;
    return (totalAmount * pointsPerPeso).floor();
  }

  /// Add loyalty points to customer
  Future<void> addLoyaltyPoints(int customerId, int points) async {
    if (points <= 0) return;
    
    final db = await AppDatabase.instance.database;
    await db.rawUpdate(
      'UPDATE customers SET loyalty_points = loyalty_points + ? WHERE id = ?',
      [points, customerId],
    );
  }

  /// Check for low stock products
  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    final db = await AppDatabase.instance.database;
    return await db.rawQuery('''
      SELECT p.*, c.name as category_name 
      FROM products p 
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE p.is_deleted = 0 AND p.min_stock > 0 AND p.stock <= p.min_stock
      ORDER BY p.stock ASC
    ''');
  }

  /// Get products that are about to expire (within 7 days)
  Future<List<Map<String, dynamic>>> getExpiringProducts({int days = 7}) async {
    final db = await AppDatabase.instance.database;
    final expiryDate = DateTime.now().add(Duration(days: days)).toIso8601String();
    return await db.rawQuery('''
      SELECT p.*, c.name as category_name 
      FROM products p 
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE p.is_deleted = 0 
        AND p.expiration_date IS NOT NULL 
        AND p.expiration_date <= ?
      ORDER BY p.expiration_date ASC
    ''', [expiryDate]);
  }
}
