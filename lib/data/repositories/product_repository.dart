import '../../data/db/database.dart';
import '../../data/models/models.dart';

class ProductRepository {
  ProductRepository._();
  static final ProductRepository instance = ProductRepository._();

  Future<List<Product>> list({String? search, int? categoryId, bool lowStockOnly = false, int? limit, int offset = 0}) async {
    final db = await AppDatabase.instance.database;
    final where = <String>['p.is_deleted = 0', 'p.is_active = 1'];
    final args = <Object?>[];
    if (search != null && search.isNotEmpty) {
      where.add('(p.name LIKE ? OR p.sku LIKE ?)');
      args..add('%$search%')..add('%$search%');
    }
    if (categoryId != null) { where.add('p.category_id = ?'); args.add(categoryId); }
    if (lowStockOnly) where.add('p.min_stock > 0 AND p.stock <= p.min_stock');
    final rows = await db.rawQuery('''
      SELECT p.*, c.name AS category_name FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE ${where.join(' AND ')}
      ORDER BY p.name ${limit != null ? 'LIMIT $limit OFFSET $offset' : ''}
    ''', args);
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> findByBarcode(String barcode) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name AS category_name FROM barcodes b
      JOIN products p ON p.id = b.product_id
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE b.barcode = ? AND p.is_deleted = 0
    ''', [barcode]);
    if (rows.isNotEmpty) return Product.fromMap(rows.first);
    // also check unit-level barcodes
    final u = await db.rawQuery('''
      SELECT p.*, c.name AS category_name FROM product_units pu
      JOIN products p ON p.id = pu.product_id
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE pu.barcode = ? AND p.is_deleted = 0
    ''', [barcode]);
    if (u.isNotEmpty) return Product.fromMap(u.first);
    return null;
  }

  Future<Product?> byId(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name AS category_name FROM products p
      LEFT JOIN categories c ON c.id = p.category_id WHERE p.id = ?''', [id]);
    if (rows.isEmpty) return null;
    final p = Product.fromMap(rows.first);
    p.barcodes = (await db.query('barcodes', where: 'product_id = ?', whereArgs: [id]))
        .map((r) => r['barcode'] as String).toList();
    p.units = (await db.query('product_units', where: 'product_id = ?', whereArgs: [id]))
        .map(ProductUnit.fromMap).toList();
    return p;
  }

  Future<int> save(Product p, {List<String> barcodes = const [], List<ProductUnit> units = const []}) async {
    final db = await AppDatabase.instance.database;
    int id = 0;
    await db.transaction((txn) async {
      final map = p.toMap()..remove('id');
      if (p.id == null) {
        map['created_at'] = DateTime.now().toIso8601String();
        id = await txn.insert('products', map);
      } else {
        id = p.id!;
        await txn.update('products', map, where: 'id = ?', whereArgs: [id]);
      }
      await txn.delete('barcodes', where: 'product_id = ?', whereArgs: [id]);
      final now = DateTime.now().toIso8601String();
      for (final b in barcodes.where((b) => b.trim().isNotEmpty)) {
        await txn.insert('barcodes', {'product_id': id, 'barcode': b.trim(), 'created_at': now});
      }
      await txn.delete('product_units', where: 'product_id = ?', whereArgs: [id]);
      for (final u in units) {
        await txn.insert('product_units', u.toMap(id)..remove('id'));
      }
    });
    return id;
  }

  Future<void> softDelete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.rawUpdate('UPDATE products SET is_deleted = 1 WHERE id = ?', [id]);
  }

  Future<List<Category>> categories() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('categories', where: 'is_active = 1', orderBy: 'name');
    return rows.map(Category.fromMap).toList();
  }

  Future<int> addCategory(String name) async {
    final db = await AppDatabase.instance.database;
    final existing = await db.query('categories', where: 'name = ?', whereArgs: [name]);
    if (existing.isNotEmpty) return existing.first['id'] as int;
    return db.insert('categories', {'name': name, 'sort_order': 0});
    // ignore: dead_code
    // (now unused var kept intentionally minimal)
  }

  Future<List<Map<String, Object?>>> lowStock() async {
    final db = await AppDatabase.instance.database;
    return db.rawQuery('''
      SELECT * FROM products WHERE is_deleted = 0 AND min_stock > 0 AND stock <= min_stock
      ORDER BY (stock * 1.0 / CASE WHEN min_stock <= 0 THEN 1 ELSE min_stock END)
    ''');
  }

  Future<List<Map<String, Object?>>> expiringWithin(int days) async {
    final db = await AppDatabase.instance.database;
    final lim = DateTime.now().add(Duration(days: days)).toIso8601String();
    return db.query('products',
        where: 'expiration_date IS NOT NULL AND expiration_date != "" AND expiration_date <= ? AND is_deleted = 0',
        whereArgs: [lim], orderBy: 'expiration_date');
  }
}
