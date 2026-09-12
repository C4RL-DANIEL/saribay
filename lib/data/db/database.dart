import 'dart:async';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Offline-first SQLite database for SariBay.
/// Version 1: full schema for all modules (per master spec §36).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'saribay.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final docs = await getApplicationDocumentsDirectory();
    final path = join(docs.path, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _create,
      onUpgrade: _upgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
      },
    );
    return _db!;
  }

  Future<void> _upgrade(Database db, int oldV, int newV) async {
    // Place future migrations here; keep transactional & additive.
  }

  Future<void> _create(Database db, int version) async {
    await db.transaction((txn) async {
      txn.execute('''
      CREATE TABLE branches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )''');

      txn.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER REFERENCES branches(id),
        name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        pin_hash TEXT NOT NULL,
        role TEXT NOT NULL CHECK(role IN ('OWNER','MANAGER','CASHIER','STOCK_CLERK')),
        is_active INTEGER NOT NULL DEFAULT 1,
        biometric_enabled INTEGER NOT NULL DEFAULT 0,
        last_login_at TEXT,
        created_at TEXT NOT NULL
      )''');

      txn.execute('''
      CREATE TABLE permissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        permission_key TEXT NOT NULL,
        allowed INTEGER NOT NULL DEFAULT 0,
        UNIQUE(role, permission_key)
      )''');

      txn.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0
      )''');

      txn.execute('''
      CREATE TABLE brands (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1
      )''');

      txn.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contact_person TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        outstanding_balance REAL NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )''');

      txn.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku TEXT,
        name TEXT NOT NULL,
        category_id INTEGER REFERENCES categories(id),
        brand_id INTEGER REFERENCES brands(id),
        supplier_id INTEGER REFERENCES suppliers(id),
        image_path TEXT,
        description TEXT,
        unit TEXT NOT NULL DEFAULT 'piece',
        cost_price REAL NOT NULL DEFAULT 0,
        selling_price REAL NOT NULL DEFAULT 0,
        wholesale_price REAL NOT NULL DEFAULT 0,
        promo_price REAL,
        stock REAL NOT NULL DEFAULT 0,
        min_stock REAL NOT NULL DEFAULT 0,
        max_stock REAL NOT NULL DEFAULT 0,
        expiration_date TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        to_sync INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');
      txn.execute('CREATE INDEX idx_products_name ON products(name)');
      txn.execute('CREATE INDEX idx_products_category ON products(category_id)');
      txn.execute('CREATE INDEX idx_products_stock ON products(stock)');

      txn.execute('''
      CREATE TABLE barcodes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
        barcode TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )''');
      txn.execute('CREATE INDEX idx_barcodes_code ON barcodes(barcode)');

      txn.execute('''
      CREATE TABLE product_units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
        unit_name TEXT NOT NULL,
        quantity_in_base REAL NOT NULL,
        barcode TEXT,
        selling_price REAL,
        UNIQUE(product_id, unit_name)
      )''');

      txn.execute('''
      CREATE TABLE stock_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id),
        batch_number TEXT,
        quantity REAL NOT NULL,
        cost_price REAL NOT NULL DEFAULT 0,
        expiration_date TEXT,
        received_at TEXT NOT NULL,
        remaining REAL NOT NULL
      )''');
      txn.execute('CREATE INDEX idx_batches_product ON stock_batches(product_id)');

      txn.execute('''
      CREATE TABLE inventory_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id),
        type TEXT NOT NULL CHECK(type IN ('SALE','RETURN','PURCHASE','ADJUSTMENT','TRANSFER_IN','TRANSFER_OUT','DAMAGED','EXPIRED','COUNT','BUNDLE_CONSUMPTION')),
        quantity_change REAL NOT NULL,
        stock_before REAL NOT NULL,
        stock_after REAL NOT NULL,
        reference_type TEXT,
        reference_id INTEGER,
        branch_id INTEGER,
        user_id INTEGER,
        reason TEXT,
        created_at TEXT NOT NULL
      )''');
      txn.execute('CREATE INDEX idx_movements_product ON inventory_movements(product_id)');
      txn.execute('CREATE INDEX idx_movements_date ON inventory_movements(created_at)');

      txn.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        notes TEXT,
        loyalty_points REAL NOT NULL DEFAULT 0,
        credit_limit REAL NOT NULL DEFAULT 0,
        utang_balance REAL NOT NULL DEFAULT 0,
        total_spent REAL NOT NULL DEFAULT 0,
        last_purchase_at TEXT,
        birthday TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        to_sync INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )''');
      txn.execute('CREATE INDEX idx_customers_name ON customers(name)');

      txn.execute('''
      CREATE TABLE credit_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL REFERENCES customers(id),
        sale_id INTEGER,
        type TEXT NOT NULL CHECK(type IN ('DEBIT','PAYMENT')),
        amount REAL NOT NULL,
        balance_after REAL NOT NULL,
        due_date TEXT,
        notes TEXT,
        user_id INTEGER,
        created_at TEXT NOT NULL
      )''');
      txn.execute('CREATE INDEX idx_credit_customer ON credit_transactions(customer_id)');

      txn.execute('''
      CREATE TABLE loyalty_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        points_per_peso REAL NOT NULL DEFAULT 0,
        peso_per_point REAL NOT NULL DEFAULT 0,
        min_redeem_points REAL NOT NULL DEFAULT 0,
        birthday_bonus REAL NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1
      )''');

      txn.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_no TEXT NOT NULL UNIQUE,
        branch_id INTEGER,
        customer_id INTEGER REFERENCES customers(id),
        user_id INTEGER,
        status TEXT NOT NULL CHECK(status IN ('COMPLETED','VOIDED','REFUNDED','HELD')),
        subtotal REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        amount_paid REAL NOT NULL DEFAULT 0,
        change_amount REAL NOT NULL DEFAULT 0,
        cogs REAL NOT NULL DEFAULT 0,
        profit REAL NOT NULL DEFAULT 0,
        is_credit INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        hold_id INTEGER,
        refunded_sale_id INTEGER,
        to_sync INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )''');
      txn.execute('CREATE INDEX idx_sales_date ON sales(created_at)');
      txn.execute('CREATE INDEX idx_sales_customer ON sales(customer_id)');
      txn.execute('CREATE INDEX idx_sales_status ON sales(status)');

      txn.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
        product_id INTEGER REFERENCES products(id),
        product_name TEXT NOT NULL,
        unit TEXT NOT NULL DEFAULT 'piece',
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        cost_price REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        bundle_id INTEGER
      )''');
      txn.execute('CREATE INDEX idx_sale_items_sale ON sale_items(sale_id)');
      txn.execute('CREATE INDEX idx_sale_items_product ON sale_items(product_id)');

      txn.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
        method_id INTEGER REFERENCES payment_methods(id),
        method_name TEXT NOT NULL,
        amount REAL NOT NULL,
        reference TEXT,
        proof_path TEXT,
        status TEXT NOT NULL CHECK(status IN ('PENDING','CONFIRMED','CANCELLED','FAILED')),
        is_manual_confirmation INTEGER NOT NULL DEFAULT 0,
        confirmed_by INTEGER,
        confirmed_at TEXT,
        created_at TEXT NOT NULL
      )''');

      txn.execute('''
      CREATE TABLE payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL CHECK(type IN ('CASH','QR','BANK','OTHER')),
        account_name TEXT,
        account_number TEXT,
        qr_image_path TEXT,
        instructions TEXT,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0
      )''');

      txn.execute('''
      CREATE TABLE held_sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT,
        cart_json TEXT NOT NULL,
        customer_id INTEGER,
        user_id INTEGER,
        created_at TEXT NOT NULL
      )''');

      txn.execute('''
      CREATE TABLE purchase_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        po_number TEXT NOT NULL UNIQUE,
        supplier_id INTEGER NOT NULL REFERENCES suppliers(id),
        status TEXT NOT NULL CHECK(status IN ('DRAFT','ORDERED','PARTIAL','RECEIVED','CANCELLED')),
        total_cost REAL NOT NULL DEFAULT 0,
        paid_amount REAL NOT NULL DEFAULT 0,
        expected_date TEXT,
        notes TEXT,
        user_id INTEGER,
        created_at TEXT NOT NULL
      )''');

      txn.execute('''
      CREATE TABLE purchase_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_order_id INTEGER NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
        product_id INTEGER NOT NULL REFERENCES products(id),
        quantity REAL NOT NULL,
        received_quantity REAL NOT NULL DEFAULT 0,
        unit_cost REAL NOT NULL,
        total REAL NOT NULL
      )''');

      txn.execute('''
      CREATE TABLE supplier_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL REFERENCES suppliers(id),
        purchase_order_id INTEGER,
        amount REAL NOT NULL,
        method TEXT,
        reference TEXT,
        notes TEXT,
        user_id INTEGER,
        created_at TEXT NOT NULL
      )''');

      txn.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        payment_method TEXT,
        branch_id INTEGER,
        user_id INTEGER,
        expense_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )''');
      txn.execute('CREATE INDEX idx_expenses_date ON expenses(expense_date)');

      txn.execute('''
      CREATE TABLE cash_drawers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER,
        opened_by INTEGER,
        opening_amount REAL NOT NULL DEFAULT 0,
        opened_at TEXT NOT NULL,
        closed_by INTEGER,
        closed_at TEXT,
        expected_cash REAL,
        actual_cash REAL,
        variance REAL,
        variance_reason TEXT,
        status TEXT NOT NULL CHECK(status IN ('OPEN','CLOSED'))
      )''');

      txn.execute('''
      CREATE TABLE cash_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        drawer_id INTEGER NOT NULL REFERENCES cash_drawers(id) ON DELETE CASCADE,
        type TEXT NOT NULL CHECK(type IN ('OPEN','SALE','REFUND','CASH_IN','CASH_OUT','EXPENSE','CLOSE')),
        amount REAL NOT NULL,
        reason TEXT,
        reference_id INTEGER,
        user_id INTEGER,
        created_at TEXT NOT NULL
      )''');

      txn.execute('''
      CREATE TABLE promotions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('BUY_X_GET_Y','PERCENT','FIXED','QUANTITY','BUNDLE','HAPPY_HOUR','SCHEDULED')),
        buy_qty REAL,
        get_qty REAL,
        discount_percent REAL,
        discount_amount REAL,
        min_quantity REAL,
        product_id INTEGER REFERENCES products(id),
        category_id INTEGER REFERENCES categories(id),
        customer_id INTEGER REFERENCES customers(id),
        start_date TEXT,
        end_date TEXT,
        start_time TEXT,
        end_time TEXT,
        days_of_week TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )''');

      txn.execute('''
      CREATE TABLE bundles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sku TEXT,
        price REAL NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )''');

      txn.execute('''
      CREATE TABLE bundle_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bundle_id INTEGER NOT NULL REFERENCES bundles(id) ON DELETE CASCADE,
        product_id INTEGER NOT NULL REFERENCES products(id),
        quantity REAL NOT NULL
      )''');

      txn.execute('''
      CREATE TABLE stock_counts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id),
        system_stock REAL NOT NULL,
        counted_stock REAL NOT NULL,
        difference REAL NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('PENDING','APPROVED','REJECTED')),
        reason TEXT,
        counted_by INTEGER,
        approved_by INTEGER,
        created_at TEXT NOT NULL
      )''');

      txn.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        data_json TEXT,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )''');

      txn.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        action TEXT NOT NULL,
        entity TEXT,
        entity_id INTEGER,
        previous_value TEXT,
        new_value TEXT,
        branch_id INTEGER,
        created_at TEXT NOT NULL
      )''');
      txn.execute('CREATE INDEX idx_audit_date ON audit_logs(created_at)');

      txn.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        payload TEXT,
        status TEXT NOT NULL CHECK(status IN ('PENDING','SYNCING','FAILED','DONE')) DEFAULT 'PENDING',
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');

      txn.execute('''
      CREATE TABLE backups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_path TEXT,
        type TEXT NOT NULL CHECK(type IN ('AUTO','MANUAL')),
        size_bytes INTEGER,
        status TEXT NOT NULL CHECK(status IN ('SUCCESS','FAILED')),
        error TEXT,
        created_at TEXT NOT NULL
      )''');

      txn.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )''');

      txn.execute('''
      CREATE TABLE login_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        success INTEGER NOT NULL,
        device_info TEXT,
        created_at TEXT NOT NULL
      )''');
    });

    await _seedDefaults(db);
  }

  Future<void> _seedDefaults(Database db) async {
    final now = DateTime.now().toIso8601String();
    // Default branch
    await db.insert('branches', {
      'name': 'Main Branch',
      'is_active': 1,
      'created_at': now,
    });
    // Base payment method: Cash
    await db.insert('payment_methods', {
      'name': 'Cash',
      'type': 'CASH',
      'is_enabled': 1,
      'sort_order': 0,
    });
    // Default settings
    final defaults = {
      'store_name': 'My Sari-Sari Store',
      'store_address': '',
      'store_phone': '',
      'store_logo_path': '',
      'currency': 'PHP',
      'currency_symbol': '\u20B1',
      'tax_enabled': '0',
      'tax_percent': '12',
      'receipt_footer': 'Salamat po!',
      'offline_mode': '1',
      'auto_backup': '0',
      'seeded_demo': '0',
    };
    for (final e in defaults.entries) {
      await db.insert('settings', {'key': e.key, 'value': e.value});
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
