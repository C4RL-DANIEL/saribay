import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/product_repository.dart';
import 'product_form_screen.dart';

/// Product list with search and filter.
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});
  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String _search = '';
  int? _catId;
  List<Product> _products = [];
  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _categories = await ProductRepository.instance.categories();
    _products = await ProductRepository.instance.list(search: _search, categoryId: _catId);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen()));
              _load();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) { _search = v; _load(); },
            ),
          ),
          if (_categories.isNotEmpty)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('All', style: TextStyle(fontSize: 12)),
                      selected: _catId == null,
                      onSelected: (_) { setState(() => _catId = null); _load(); },
                    ),
                  ),
                  ..._categories.map((c) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(c.name, style: const TextStyle(fontSize: 12)),
                      selected: _catId == c.id,
                      onSelected: (_) { setState(() => _catId = c.id); _load(); },
                    ),
                  )),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(child: Text('No products found'))
                    : ListView.builder(
                        itemCount: _products.length,
                        itemBuilder: (ctx, i) {
                          final p = _products[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: p.isLowStock
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                              child: Text(p.stock.toStringAsFixed(0),
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            title: Text(p.name),
                            subtitle: Text('${p.categoryName ?? "No category"} · Stock: ${p.stock.toStringAsFixed(0)}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('₱${p.sellingPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (p.isLowStock)
                                  const Text('LOW', style: TextStyle(color: Colors.orange, fontSize: 10)),
                              ],
                            ),
                            onTap: () async {
                              await Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)));
                              _load();
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
