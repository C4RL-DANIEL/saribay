import 'package:flutter/foundation.dart';

import '../data/db/database.dart';
import '../data/models/models.dart';
import '../services/audit_service.dart';

/// Holds the currently authenticated user and permission checks.
class SessionProvider extends ChangeNotifier {
  AppUser? _user;
  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;

  Set<String> _perms = {};
  int _branchId = 1;
  int get branchId => _branchId;

  Future<void> login(AppUser user) async {
    _user = user;
    _branchId = user.branchId ?? 1;
    try {
      await _loadPermissions();
    } catch (e) {
      // Permissions load failed — continue with empty permissions
      _perms = {};
    }
    notifyListeners();
  }

  Future<void> _loadPermissions() async {
    if (_user == null) { _perms = {}; return; }
    if (_user!.role == 'OWNER') { _perms = {'*'}; return; }
    final db = await AppDatabase.instance.database;
    final rows = await db.query('permissions',
        where: 'role = ? AND allowed = 1', whereArgs: [_user!.role]);
    _perms = rows.map((r) => r['permission_key'] as String).toSet();
  }

  bool can(String permission) {
    if (_user == null) return false;
    if (_perms.contains('*')) return true;
    return _perms.contains(permission);
  }

  Future<void> logout({String reason = 'manual'}) async {
    if (_user != null) {
      await AuditService.instance.log('logout', details: reason);
    }
    _user = null;
    _perms = {};
    notifyListeners();
  }
}

/// Standard permission keys.
class Perms {
  static const refund = 'pos.refund';
  static const voidSale = 'pos.void';
  static const priceOverride = 'pos.price_override';
  static const discount = 'pos.discount';
  static const stockAdjust = 'inventory.adjust';
  static const approveCount = 'inventory.approve_count';
  static const deleteProduct = 'product.delete';
  static const manageUsers = 'users.manage';
  static const viewReports = 'reports.view';
  static const cashDrawerClose = 'cashdrawer.close';
  static const backupRestore = 'backup.restore';
  static const manageSuppliers = 'suppliers.manage';
  static const manageSettings = 'settings.manage';
}

/// Default role permission matrix.
Map<String, List<String>> defaultRolePermissions() => {
  'OWNER': ['*'],
  'MANAGER': [
    Perms.refund, Perms.voidSale, Perms.priceOverride, Perms.discount,
    Perms.stockAdjust, Perms.approveCount, Perms.viewReports,
    Perms.cashDrawerClose, Perms.manageSuppliers, Perms.deleteProduct,
  ],
  'CASHIER': ['pos.sell'],
  'STOCK_CLERK': ['inventory.view', Perms.stockAdjust],
};
