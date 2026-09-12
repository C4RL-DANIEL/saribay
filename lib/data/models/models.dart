/// Data models mapping to the SQLite schema.
library;

class Product {
  int? id;
  String? sku;
  String name;
  int? categoryId;
  int? brandId;
  int? supplierId;
  String? imagePath;
  String description;
  String unit;
  double costPrice;
  double sellingPrice;
  double wholesalePrice;
  double? promoPrice;
  double stock;
  double minStock;
  double maxStock;
  String? expirationDate;
  bool isActive;
  String? categoryName; // joined
  List<String> barcodes;
  List<ProductUnit> units;

  Product({
    this.id,
    this.sku,
    required this.name,
    this.categoryId,
    this.brandId,
    this.supplierId,
    this.imagePath,
    this.description = '',
    this.unit = 'piece',
    this.costPrice = 0,
    this.sellingPrice = 0,
    this.wholesalePrice = 0,
    this.promoPrice,
    this.stock = 0,
    this.minStock = 0,
    this.maxStock = 0,
    this.expirationDate,
    this.isActive = true,
    this.categoryName,
    this.barcodes = const [],
    this.units = const [],
  });

  double get effectivePrice => (promoPrice != null && promoPrice! > 0 && promoPrice! < sellingPrice)
      ? promoPrice!
      : sellingPrice;

  bool get isLowStock => minStock > 0 && stock <= minStock;
  bool get isOutOfStock => stock <= 0;
  double get profitPerUnit => effectivePrice - costPrice;
  double get margin => effectivePrice <= 0 ? 0 : (profitPerUnit / effectivePrice) * 100;

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as int?,
        sku: m['sku'] as String?,
        name: (m['name'] as String?) ?? '',
        categoryId: m['category_id'] as int?,
        brandId: m['brand_id'] as int?,
        supplierId: m['supplier_id'] as int?,
        imagePath: m['image_path'] as String?,
        description: (m['description'] as String?) ?? '',
        unit: (m['unit'] as String?) ?? 'piece',
        costPrice: (m['cost_price'] as num?)?.toDouble() ?? 0,
        sellingPrice: (m['selling_price'] as num?)?.toDouble() ?? 0,
        wholesalePrice: (m['wholesale_price'] as num?)?.toDouble() ?? 0,
        promoPrice: (m['promo_price'] as num?)?.toDouble(),
        stock: (m['stock'] as num?)?.toDouble() ?? 0,
        minStock: (m['min_stock'] as num?)?.toDouble() ?? 0,
        maxStock: (m['max_stock'] as num?)?.toDouble() ?? 0,
        expirationDate: m['expiration_date'] as String?,
        isActive: (m['is_active'] as int?) == 1,
        categoryName: m['category_name'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'sku': sku,
        'name': name,
        'category_id': categoryId,
        'brand_id': brandId,
        'supplier_id': supplierId,
        'image_path': imagePath,
        'description': description,
        'unit': unit,
        'cost_price': costPrice,
        'selling_price': sellingPrice,
        'wholesale_price': wholesalePrice,
        'promo_price': promoPrice,
        'stock': stock,
        'min_stock': minStock,
        'max_stock': maxStock,
        'expiration_date': expirationDate,
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      };
}

class ProductUnit {
  int? id;
  String unitName;
  double quantityInBase;
  String? barcode;
  double? sellingPrice;
  ProductUnit({this.id, required this.unitName, required this.quantityInBase, this.barcode, this.sellingPrice});

  factory ProductUnit.fromMap(Map<String, dynamic> m) => ProductUnit(
        id: m['id'] as int?,
        unitName: m['unit_name'] as String,
        quantityInBase: (m['quantity_in_base'] as num).toDouble(),
        barcode: m['barcode'] as String?,
        sellingPrice: (m['selling_price'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap(int productId) => {
        if (id != null) 'id': id,
        'product_id': productId,
        'unit_name': unitName,
        'quantity_in_base': quantityInBase,
        'barcode': barcode,
        'selling_price': sellingPrice,
      };
}

class Category {
  int? id;
  String name;
  String? description;
  Category({this.id, required this.name, this.description});
  factory Category.fromMap(Map<String, dynamic> m) =>
      Category(id: m['id'] as int?, name: m['name'] as String, description: m['description'] as String?);
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'description': description};
}

class Customer {
  int? id;
  String name;
  String? phone;
  String? address;
  String? notes;
  double loyaltyPoints;
  double creditLimit;
  double utangBalance;
  double totalSpent;
  String? birthday;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    this.loyaltyPoints = 0,
    this.creditLimit = 0,
    this.utangBalance = 0,
    this.totalSpent = 0,
    this.birthday,
  });

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
        id: m['id'] as int?,
        name: m['name'] as String,
        phone: m['phone'] as String?,
        address: m['address'] as String?,
        notes: m['notes'] as String?,
        loyaltyPoints: (m['loyalty_points'] as num?)?.toDouble() ?? 0,
        creditLimit: (m['credit_limit'] as num?)?.toDouble() ?? 0,
        utangBalance: (m['utang_balance'] as num?)?.toDouble() ?? 0,
        totalSpent: (m['total_spent'] as num?)?.toDouble() ?? 0,
        birthday: m['birthday'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'notes': notes,
        'loyalty_points': loyaltyPoints,
        'credit_limit': creditLimit,
        'utang_balance': utangBalance,
        'total_spent': totalSpent,
        'birthday': birthday,
      };
}

class Supplier {
  int? id;
  String name;
  String? contactPerson;
  String? phone;
  String? email;
  String? address;
  String? notes;
  double outstandingBalance;

  Supplier({
    this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.outstandingBalance = 0,
  });

  factory Supplier.fromMap(Map<String, dynamic> m) => Supplier(
        id: m['id'] as int?,
        name: m['name'] as String,
        contactPerson: m['contact_person'] as String?,
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        address: m['address'] as String?,
        notes: m['notes'] as String?,
        outstandingBalance: (m['outstanding_balance'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'contact_person': contactPerson,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
        'outstanding_balance': outstandingBalance,
      };
}

class CartItem {
  final int? productId; // null for custom line
  final int? bundleId;
  final String name;
  String unit;
  double quantity;
  double unitPrice;
  double costPrice;
  double discount;

  CartItem({
    this.productId,
    this.bundleId,
    required this.name,
    this.unit = 'piece',
    this.quantity = 1,
    required this.unitPrice,
    this.costPrice = 0,
    this.discount = 0,
  });

  double get lineTotal => (unitPrice * quantity) - discount;

  CartItem copy() => CartItem(
        productId: productId,
        bundleId: bundleId,
        name: name,
        unit: unit,
        quantity: quantity,
        unitPrice: unitPrice,
        costPrice: costPrice,
        discount: discount,
      );
}

class SalePayment {
  int? methodId;
  String methodName;
  double amount;
  String? reference;
  String status; // PENDING, CONFIRMED (manual), etc.
  SalePayment({this.methodId, required this.methodName, required this.amount, this.reference, this.status = 'CONFIRMED'});
}

class AppUser {
  int? id;
  String name;
  String username;
  String role; // OWNER, MANAGER, CASHIER, STOCK_CLERK
  bool isActive;
  int? branchId;
  AppUser({this.id, required this.name, required this.username, required this.role, this.isActive = true, this.branchId});
  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'] as int?,
        name: m['name'] as String,
        username: m['username'] as String,
        role: m['role'] as String,
        branchId: m['branch_id'] as int?,
        isActive: (m['is_active'] as int?) == 1,
      );
}

class Bundle {
  int? id;
  String name;
  String? sku;
  double price;
  List<BundleItem> items;
  Bundle({this.id, required this.name, this.sku, required this.price, this.items = const []});
  factory Bundle.fromMap(Map<String, dynamic> m) => Bundle(
        id: m['id'] as int?, name: m['name'] as String,
        sku: m['sku'] as String?, price: (m['price'] as num).toDouble(),
      );
}

class BundleItem {
  int productId;
  double quantity;
  String? productName;
  BundleItem({required this.productId, required this.quantity, this.productName});
}

class Promotion {
  int? id;
  String name;
  String type; // BUY_X_GET_Y, PERCENT, FIXED, QUANTITY, HAPPY_HOUR, SCHEDULED
  double? buyQty, getQty, discountPercent, discountAmount, minQuantity;
  int? productId, categoryId, customerId;
  String? startDate, endDate, startTime, endTime, daysOfWeek;
  bool isActive;

  Promotion({
    this.id, required this.name, required this.type,
    this.buyQty, this.getQty, this.discountPercent, this.discountAmount, this.minQuantity,
    this.productId, this.categoryId, this.customerId,
    this.startDate, this.endDate, this.startTime, this.endTime, this.daysOfWeek,
    this.isActive = true,
  });

  factory Promotion.fromMap(Map<String, dynamic> m) => Promotion(
        id: m['id'] as int?, name: m['name'] as String, type: m['type'] as String,
        buyQty: (m['buy_qty'] as num?)?.toDouble(), getQty: (m['get_qty'] as num?)?.toDouble(),
        discountPercent: (m['discount_percent'] as num?)?.toDouble(),
        discountAmount: (m['discount_amount'] as num?)?.toDouble(),
        minQuantity: (m['min_quantity'] as num?)?.toDouble(),
        productId: m['product_id'] as int?, categoryId: m['category_id'] as int?,
        customerId: m['customer_id'] as int?,
        startDate: m['start_date'] as String?, endDate: m['end_date'] as String?,
        startTime: m['start_time'] as String?, endTime: m['end_time'] as String?,
        daysOfWeek: m['days_of_week'] as String?,
        isActive: (m['is_active'] as int?) == 1,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id, 'name': name, 'type': type,
        'buy_qty': buyQty, 'get_qty': getQty, 'discount_percent': discountPercent,
        'discount_amount': discountAmount, 'min_quantity': minQuantity,
        'product_id': productId, 'category_id': categoryId, 'customer_id': customerId,
        'start_date': startDate, 'end_date': endDate, 'start_time': startTime,
        'end_time': endTime, 'days_of_week': daysOfWeek, 'is_active': isActive ? 1 : 0,
      };
}

class Expense {
  int? id;
  String category;
  double amount;
  String? description;
  String? paymentMethod;
  String expenseDate;
  Expense({this.id, required this.category, required this.amount, this.description, this.paymentMethod, required this.expenseDate});
  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] as int?, category: m['category'] as String,
        amount: (m['amount'] as num).toDouble(), description: m['description'] as String?,
        paymentMethod: m['payment_method'] as String?, expenseDate: m['expense_date'] as String,
      );
}
