import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/money.dart';
import '../../../data/db/database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../providers/cart_provider.dart';
import '../scanner/scanner_screen.dart';
import 'hold_list_screen.dart';
import 'payment_screen.dart';

/// Main POS / checkout screen.
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchCtrl = TextEditingController();
  List<Product> _products = [];
  int? _selectedCategoryId;
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
  }

  Future<void> _loadCategories() async {
    final cats = await ProductRepository.instance.categories();
    setState(() => _categories = cats);
  }

  Future<void> _loadProducts({String? search}) async {
    final prods = await ProductRepository.instance.list(search: search, categoryId: _selectedCategoryId);
    setState(() => _products = prods);
  }

  void _addToCart(Product p) {
    context.read<CartProvider>().addProduct(p);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${p.name} added'), duration: const Duration(milliseconds: 600)),
    );
  }

  Future<void> _checkout() async {
    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PaymentScreen(total: cart.total)),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale completed!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final wide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              final barcode = await Navigator.push<String>(
                  context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
              if (barcode != null) {
                final p = await ProductRepository.instance.findByBarcode(barcode);
                if (p != null) {
                  _addToCart(p);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Barcode not found: $barcode')),
                    );
                  }
                }
              }
            },
            tooltip: 'Scan',
          ),
          IconButton(
            icon: const Icon(Icons.pause_circle_outline),
            onPressed: () async {
              final cart = context.read<CartProvider>();
              if (cart.items.isNotEmpty) {
                await cart.hold(null);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sale held')));
              }
            },
            tooltip: 'Hold',
          ),
          TextButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const HoldListScreen())),
            child: const Text('Held'),
          ),
        ],
      ),
      body: Row(
        children: [
          // Product search & grid
          Expanded(
            flex: wide ? 3 : 1,
            child: Column(
              children: [
                // Search + category filter
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search products or scan barcode...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () async {
                          final barcode = await Navigator.push<String>(
                              context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
                          if (barcode != null) {
                            final p = await ProductRepository.instance.findByBarcode(barcode);
                            if (p != null) _addToCart(p);
                            else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Not found: $barcode')));
                            }
                          }
                        },
                      ),
                    ),
                    onChanged: (v) => _loadProducts(search: v),
                  ),
                ),
                // Category chips
                if (_categories.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: const Text('All'),
                            selected: _selectedCategoryId == null,
                            onSelected: (_) {
                              setState(() => _selectedCategoryId = null);
                              _loadProducts(search: _searchCtrl.text);
                            },
                          ),
                        ),
                        ..._categories.map((c) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(c.name),
                            selected: _selectedCategoryId == c.id,
                            onSelected: (_) {
                              setState(() => _selectedCategoryId = c.id);
                              _loadProducts(search: _searchCtrl.text);
                            },
                          ),
                        )),
                      ],
                    ),
                  ),
                // Product grid
                Expanded(
                  child: _products.isEmpty
                      ? const Center(child: Text('No products. Add products first.'))
                      : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 160,
                      childAspectRatio: 0.85,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (ctx, i) {
                      final p = _products[i];
                      return Card(
                        child: InkWell(
                          onTap: () => _addToCart(p),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Center(
                                    child: p.imagePath != null
                                        ? Image.asset(p.imagePath!, fit: BoxFit.cover)
                                        : Icon(Icons.inventory_2, size: 48, color: Theme.of(context).colorScheme.primary),
                                  ),
                                ),
                                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                Text(peso(p.effectivePrice), style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary)),
                                Text('Stock: ${p.stock.toStringAsFixed(0)}',
                                    style: TextStyle(fontSize: 11, color: p.isLowStock ? Colors.orange : Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (wide) const VerticalDivider(width: 1),
          // Cart panel
          if (wide)
            SizedBox(
              width: 360,
              child: _buildCartPanel(context, cart),
            ),
        ],
      ),
      // Bottom cart summary (phone mode)
      bottomNavigationBar: !wide
          ? _buildCartBar(context, cart)
          : null,
      floatingActionButton: !wide
          ? FloatingActionButton.extended(
        onPressed: _checkout,
        icon: const Icon(Icons.shopping_cart),
        label: Text('Checkout ${peso(cart.total)}'),
      )
          : null,
    );
  }

  Widget _buildCartPanel(BuildContext context, CartProvider cart) {
    return Column(
      children: [
        // Cart header
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              const Icon(Icons.shopping_cart),
              const SizedBox(width: 8),
              Text('Cart (${cart.count})', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (cart.customerName != null)
                Chip(label: Text(cart.customerName!, style: const TextStyle(fontSize: 11))),
              TextButton(
                onPressed: () => _showCustomerPicker(context),
                child: Text(cart.customerName != null ? 'Change' : 'Select Customer'),
              ),
            ],
          ),
        ),
        // Cart items
        Expanded(
          child: cart.items.isEmpty
              ? const Center(child: Text('Tap products to add'))
              : ListView.builder(
            itemCount: cart.items.length,
            itemBuilder: (ctx, i) {
              final item = cart.items[i];
              return ListTile(
                title: Text(item.name, style: const TextStyle(fontSize: 13)),
                subtitle: Text('${peso(item.unitPrice)} × ${item.quantity.toStringAsFixed(0)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(peso(item.lineTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => cart.removeAt(i),
                    ),
                  ],
                ),
                onTap: () => _showCartItemEdit(context, i, item),
              );
            },
          ),
        ),
        // Summary
        Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [const Text('Subtotal'), Text(peso(cart.subtotal))]),
              if (cart.discountTotal > 0)
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [const Text('Discount'), Text('-${peso(cart.discountTotal)}')]),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(peso(cart.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _checkout,
                  icon: const Icon(Icons.check),
                  label: const Text('Checkout'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCartBar(BuildContext context, CartProvider cart) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('Cart (${cart.count}): ${peso(cart.total)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          OutlinedButton(onPressed: _checkout, child: const Text('Checkout')),
        ],
      ),
    );
  }

  void _showCartItemEdit(BuildContext context, int index, CartItem item) {
    final qtyCtrl = TextEditingController(text: item.quantity.toStringAsFixed(0));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Qty: '),
              Expanded(
                child: TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final q = double.tryParse(qtyCtrl.text) ?? 1;
                    context.read<CartProvider>().setQty(index, q);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Update'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    context.read<CartProvider>().removeAt(index);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Remove'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _showCustomerPicker(BuildContext context) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('customers', where: 'is_active = 1', orderBy: 'name');
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Select Customer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            title: const Text('No customer'),
            onTap: () {
              context.read<CartProvider>().setCustomer(null, null);
              Navigator.pop(ctx);
            },
          ),
          ...rows.map((r) => ListTile(
            title: Text(r['name'] as String),
            subtitle: Text('Utang: ${peso(r['utang_balance'] as num?)}'),
            onTap: () {
              context.read<CartProvider>().setCustomer(r['id'] as int, r['name'] as String);
              Navigator.pop(ctx);
            },
          )),
        ],
      ),
    );
  }
}
