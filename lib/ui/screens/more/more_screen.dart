import 'package:flutter/material.dart';

import '../customers/customer_list_screen.dart';
import '../employees/employee_screen.dart';
import '../expenses/expense_screen.dart';
import '../cash_drawer/cash_drawer_screen.dart';
import '../suppliers/supplier_list_screen.dart';
import '../purchases/purchase_list_screen.dart';
import '../notifications/notification_screen.dart';
import '../settings/settings_screen.dart';
import '../reports/report_screen.dart';
import '../ai/ai_assistant_screen.dart';
import '../promotions/promotion_screen.dart';
import '../backup/backup_screen.dart';

/// "More" hub screen with links to all feature modules.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _item(Icons.people, 'Customers', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen()))),
      _item(Icons.person_off, 'Utang / Credit', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen()))),
      _item(Icons.business, 'Suppliers', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierListScreen()))),
      _item(Icons.shopping_cart, 'Purchases', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseListScreen()))),
      _item(Icons.receipt_long, 'Sales History', () => Navigator.pop(context)), // redirects from dashboard
      _item(Icons.money_off, 'Expenses', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseScreen()))),
      _item(Icons.account_balance_wallet, 'Cash Drawer', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashDrawerScreen()))),
      _item(Icons.assessment, 'Reports', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen()))),
      _item(Icons.badge, 'Employees', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeScreen()))),
      _item(Icons.notifications, 'Notifications', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()))),
      _item(Icons.local_offer, 'Promotions', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PromotionScreen()))),
      _item(Icons.smart_toy, 'AI Assistant', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAssistantScreen()))),
      _item(Icons.backup, 'Backup & Restore', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen()))),
      _item(Icons.settings, 'Settings', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) => items[i],
      ),
    );
  }

  ListTile _item(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
