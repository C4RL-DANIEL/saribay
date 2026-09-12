import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/money.dart';
import '../../../data/models/models.dart';
import '../../../data/db/database.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/session_provider.dart';
import '../../../services/pos_service.dart';

/// Payment selection and confirmation screen.
class PaymentScreen extends StatefulWidget {
  final double total;
  const PaymentScreen({super.key, required this.total});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  List<Map<String, dynamic>> _methods = [];
  String _selectedMethod = 'Cash';
  int? _selectedMethodId;
  final _cashCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  bool _isCredit = false;
  bool _processing = false;
  double _change = 0;

  @override
  void initState() {
    super.initState();
    _loadMethods();
    _cashCtrl.text = widget.total.toStringAsFixed(0);
  }

  Future<void> _loadMethods() async {
    final db = await AppDatabase.instance.database;
    final methods = await db.query('payment_methods', where: 'is_enabled = 1');
    setState(() => _methods = methods);
  }

  void _calcChange() {
    final cash = double.tryParse(_cashCtrl.text) ?? 0;
    setState(() => _change = (cash - widget.total).clamp(0, double.infinity));
  }

  Future<void> _confirm() async {
    setState(() => _processing = true);
    try {
      final cart = context.read<CartProvider>();
      final session = context.read<SessionProvider>();
      final payments = <SalePayment>[];

      if (_selectedMethod == 'Cash') {
        final cash = double.tryParse(_cashCtrl.text) ?? 0;
        payments.add(SalePayment(methodName: 'Cash', amount: cash));
      } else if (_selectedMethod == 'Utang' || _isCredit) {
        payments.add(SalePayment(methodName: 'Utang', amount: widget.total, status: 'PENDING'));
      } else {
        // QR/e-payment
        payments.add(SalePayment(
          methodId: _selectedMethodId,
          methodName: _selectedMethod,
          amount: widget.total,
          reference: _refCtrl.text.isNotEmpty ? _refCtrl.text : null,
          status: 'CONFIRMED',
        ));
      }

      final result = await PosService.instance.completeSale(
        items: cart.items,
        customerId: _isCredit || _selectedMethod == 'Utang' ? cart.customerId : null,
        payments: payments,
        isCredit: _isCredit || _selectedMethod == 'Utang',
        cartDiscount: cart.cartDiscount,
        notes: cart.notes,
        userId: session.user?.id,
      );

      if (!mounted) return;
      cart.clear();

      // Show receipt
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _ReceiptPage(saleId: result.saleId, receiptNo: result.receiptNo, change: result.change),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Total display
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('Total Amount', style: TextStyle(fontSize: 14)),
                    Text(peso(widget.total), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Payment method selection
            const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Cash'),
                  selected: _selectedMethod == 'Cash',
                  onSelected: (_) => setState(() { _selectedMethod = 'Cash'; _isCredit = false; }),
                ),
                ChoiceChip(
                  label: const Text('Utang / Credit'),
                  selected: _selectedMethod == 'Utang' || _isCredit,
                  onSelected: (_) => setState(() { _isCredit = true; _selectedMethod = 'Utang'; }),
                ),
                ..._methods.where((m) => m['type'] != 'CASH').map((m) => ChoiceChip(
                  label: Text(m['name'] as String),
                  selected: _selectedMethod == m['name'],
                  onSelected: (_) => setState(() {
                    _selectedMethod = m['name'] as String;
                    _selectedMethodId = m['id'] as int;
                    _isCredit = false;
                  }),
                )),
              ],
            ),
            const SizedBox(height: 16),
            // Cash input
            if (_selectedMethod == 'Cash') ...[
              TextField(
                controller: _cashCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount Received (₱)', prefixIcon: Icon(Icons.money)),
                onChanged: (_) => _calcChange(),
              ),
              const SizedBox(height: 8),
              if (_change > 0)
                Text('Change: ${peso(_change)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
            // QR reference
            if (_selectedMethod != 'Cash' && _selectedMethod != 'Utang' && !_isCredit) ...[
              TextField(
                controller: _refCtrl,
                decoration: const InputDecoration(labelText: 'Payment Reference (optional)'),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Manual Confirmation Required',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 4),
                      Text('Amount: ${peso(widget.total)}'),
                      Text('Method: $_selectedMethod'),
                      const Text('Scan QR, customer pays externally, then confirm below.'),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _processing ? null : _confirm,
              icon: _processing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle),
              label: Text(_processing ? 'Processing...' : _isCredit ? 'Record Utang' : 'Confirm Payment'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple receipt page shown after a sale.
class _ReceiptPage extends StatelessWidget {
  final int saleId;
  final String receiptNo;
  final double change;
  const _ReceiptPage({required this.saleId, required this.receiptNo, required this.change});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: FutureBuilder(
        future: _load(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final sale = snap.data!;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(receiptNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Divider(),
                        ...((sale['items'] as List).map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text('${item['product_name']} × ${item['quantity']}')),
                              Text(peso(item['total'] as num?)),
                            ],
                          ),
                        ))),
                        const Divider(),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [const Text('Total'), Text(peso(sale['total'] as num?), style: const TextStyle(fontWeight: FontWeight.bold))]),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [const Text('Paid'), Text(peso(sale['amount_paid'] as num?))]),
                        if (change > 0)
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [const Text('Change'), Text(peso(change))]),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Back to POS'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _load() async {
    final db = await AppDatabase.instance.database;
    final saleRows = await db.query('sales', where: 'id = ?', whereArgs: [saleId]);
    final items = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
    final sale = Map<String, dynamic>.from(saleRows.first);
    sale['items'] = items;
    return sale;
  }
}
