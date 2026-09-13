import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money.dart';
import '../../data/db/database.dart';

/// Receipt generation and sharing service.
class ReceiptService {
  ReceiptService._();
  static final ReceiptService instance = ReceiptService._();

  /// Generate receipt text for a sale
  Future<String> generateReceiptText(int saleId) async {
    final db = await AppDatabase.instance.database;
    
    // Get sale details
    final sales = await db.query('sales', where: 'id = ?', whereArgs: [saleId]);
    if (sales.isEmpty) return 'Sale not found';
    final sale = sales.first;
    
    // Get sale items
    final items = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
    
    // Get store settings
    final settings = await db.query('settings');
    final settingsMap = {for (var r in settings) r['key'] as String: r['value'] as String? ?? ''};
    
    final storeName = settingsMap['store_name'] ?? 'Sari-Sari Store';
    final storeAddress = settingsMap['store_address'] ?? '';
    final storePhone = settingsMap['store_phone'] ?? '';
    
    // Build receipt text
    final buffer = StringBuffer();
    buffer.writeln('================================');
    buffer.writeln(storeName.toUpperCase());
    if (storeAddress.isNotEmpty) buffer.writeln(storeAddress);
    if (storePhone.isNotEmpty) buffer.writeln(storePhone);
    buffer.writeln('================================');
    buffer.writeln('');
    buffer.writeln('Receipt #: ${sale['receipt_no']}');
    buffer.writeln('Date: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.parse(sale['created_at'] as String))}');
    buffer.writeln('Cashier: ${sale['user_id'] ?? 'N/A'}');
    buffer.writeln('');
    buffer.writeln('--------------------------------');
    buffer.writeln('ITEM                    QTY    PRICE');
    buffer.writeln('--------------------------------');
    
    for (final item in items) {
      final name = (item['product_name'] as String).padRight(20);
      final qty = (item['quantity'] as num).toStringAsFixed(0).padLeft(3);
      final price = peso(item['total'] as num?).padLeft(8);
      buffer.writeln('$name $qty $price');
    }
    
    buffer.writeln('--------------------------------');
    buffer.writeln('SUBTOTAL:${peso(sale['subtotal'] as num?).padLeft(12)}');
    if (((sale['discount'] as num?)?.toDouble() ?? 0) > 0) {
      buffer.writeln('DISCOUNT:${peso(sale['discount'] as num?).padLeft(12)}');
    }
    buffer.writeln('TOTAL:   ${peso(sale['total'] as num?).padLeft(12)}');
    buffer.writeln('');
    buffer.writeln('PAID:    ${peso(sale['amount_paid'] as num?).padLeft(12)}');
    if (((sale['change_amount'] as num?)?.toDouble() ?? 0) > 0) {
      buffer.writeln('CHANGE:  ${peso(sale['change_amount'] as num?).padLeft(12)}');
    }
    buffer.writeln('');
    buffer.writeln('Payment: ${sale['is_credit'] == 1 ? 'UTANG/CREDIT' : 'CASH'}');
    buffer.writeln('');
    buffer.writeln('================================');
    buffer.writeln('Thank you for shopping!');
    buffer.writeln('Salamat po!');
    buffer.writeln('================================');
    
    return buffer.toString();
  }

  /// Share receipt via share_plus
  Future<void> shareReceipt(int saleId) async {
    final receiptText = await generateReceiptText(saleId);
    await Share.share(receiptText, subject: 'Receipt from SariBay POS');
  }

  /// Show receipt preview dialog
  void showReceiptPreview(BuildContext context, int saleId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scroll) => FutureBuilder<String>(
          future: generateReceiptText(saleId),
          builder: (ctx, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () => shareReceipt(saleId),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Receipt content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scroll,
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      snap.data!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                // Close button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
