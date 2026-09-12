import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/db/database.dart';
import '../data/models/models.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> items = [];
  int? customerId;
  String? customerName;
  double cartDiscount = 0;
  String? notes;

  int get count => items.fold(0, (s, i) => s + i.quantity.round());
  double get subtotal => items.fold(0.0, (s, i) => s + i.unitPrice * i.quantity);
  double get discountTotal =>
      cartDiscount + items.fold(0.0, (s, i) => s + i.discount);
  double get total => (subtotal - discountTotal).clamp(0.0, double.infinity);

  void addProduct(Product p, {String? unit, double? price}) {
    final existing = items.indexWhere((i) => i.productId == p.id && i.bundleId == null);
    if (existing >= 0) {
      items[existing].quantity += 1;
    } else {
      items.add(CartItem(
        productId: p.id,
        name: p.name,
        unit: unit ?? p.unit,
        unitPrice: price ?? p.effectivePrice,
        costPrice: p.costPrice,
      ));
    }
    notifyListeners();
  }

  void addBundle(Bundle b) {
    items.add(CartItem(bundleId: b.id, name: b.name, unitPrice: b.price));
    notifyListeners();
  }

  void setQty(int index, double qty) {
    if (index < 0 || index >= items.length) return;
    if (qty <= 0) { items.removeAt(index); } else { items[index].quantity = qty; }
    notifyListeners();
  }

  void setPrice(int index, double price) { items[index].unitPrice = price; notifyListeners(); }
  void setItemDiscount(int index, double d) { items[index].discount = d; notifyListeners(); }
  void removeAt(int index) { items.removeAt(index); notifyListeners(); }
  void setCustomer(int? id, String? name) { customerId = id; customerName = name; notifyListeners(); }

  void clear() {
    items.clear();
    customerId = null; customerName = null;
    cartDiscount = 0; notes = null;
    notifyListeners();
  }

  // --- Hold / resume ---
  Future<int> hold(String? label) async {
    final db = await AppDatabase.instance.database;
    final payload = items.map((i) => {
      'productId': i.productId, 'bundleId': i.bundleId, 'name': i.name,
      'unit': i.unit, 'quantity': i.quantity, 'unitPrice': i.unitPrice,
      'costPrice': i.costPrice, 'discount': i.discount,
    }).toList();
    final id = await db.insert('held_sales', {
      'label': label, 'cart_json': jsonEncode(payload),
      'customer_id': customerId, 'created_at': DateTime.now().toIso8601String(),
    });
    clear();
    return id;
  }

  Future<void> resume(Map<String, dynamic> held) async {
    clear();
    final list = jsonDecode(held['cart_json'] as String) as List;
    for (final m in list) {
      items.add(CartItem(
        productId: m['productId'], bundleId: m['bundleId'], name: m['name'],
        unit: m['unit'], quantity: (m['quantity'] as num).toDouble(),
        unitPrice: (m['unitPrice'] as num).toDouble(),
        costPrice: (m['costPrice'] as num?)?.toDouble() ?? 0,
        discount: (m['discount'] as num?)?.toDouble() ?? 0,
      ));
    }
    setCustomer(held['customer_id'] as int?, null);
    notifyListeners();
  }
}
