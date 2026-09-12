import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/product_repository.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _wholesaleCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  int? _categoryId;
  String _unit = 'piece';
  List<Category> _categories = [];
  bool _saving = false;

  static const _units = ['piece','pack','box','bottle','sachet','can','kilogram','gram','liter','milliliter'];

  @override
  void initState() {
    super.initState();
    _loadCats();
    if (widget.product != null) {
      final p = widget.product!;
      _nameCtrl.text = p.name;
      _skuCtrl.text = p.sku ?? '';
      _descCtrl.text = p.description;
      _costCtrl.text = p.costPrice.toStringAsFixed(2);
      _priceCtrl.text = p.sellingPrice.toStringAsFixed(2);
      _wholesaleCtrl.text = p.wholesalePrice.toStringAsFixed(2);
      _stockCtrl.text = p.stock.toStringAsFixed(0);
      _minCtrl.text = p.minStock.toStringAsFixed(0);
      _maxCtrl.text = p.maxStock.toStringAsFixed(0);
      _categoryId = p.categoryId;
      _unit = p.unit;
    }
  }

  Future<void> _loadCats() async {
    _categories = await ProductRepository.instance.categories();
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final p = Product(
        id: widget.product?.id,
        name: _nameCtrl.text.trim(),
        sku: _skuCtrl.text.trim().isNotEmpty ? _skuCtrl.text.trim() : null,
        description: _descCtrl.text.trim(),
        categoryId: _categoryId,
        unit: _unit,
        costPrice: double.tryParse(_costCtrl.text) ?? 0,
        sellingPrice: double.tryParse(_priceCtrl.text) ?? 0,
        wholesalePrice: double.tryParse(_wholesaleCtrl.text) ?? 0,
        stock: double.tryParse(_stockCtrl.text) ?? 0,
        minStock: double.tryParse(_minCtrl.text) ?? 0,
        maxStock: double.tryParse(_maxCtrl.text) ?? 0,
      );
      final barcodes = _barcodeCtrl.text.trim().isNotEmpty
          ? _barcodeCtrl.text.split(',').map((s) => s.trim()).toList()
          : <String>[];
      await ProductRepository.instance.save(p, barcodes: barcodes);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.product == null ? 'Add Product' : 'Edit Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Product Name *'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _skuCtrl, decoration: const InputDecoration(labelText: 'SKU'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _barcodeCtrl, decoration: const InputDecoration(labelText: 'Barcodes (comma-separated)'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _categoryId,
                    items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _unit,
                    items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setState(() => _unit = v ?? 'piece'),
                    decoration: const InputDecoration(labelText: 'Unit'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _costCtrl, decoration: const InputDecoration(labelText: 'Cost Price (₱)'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _priceCtrl, decoration: const InputDecoration(labelText: 'Selling Price (₱)'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _wholesaleCtrl, decoration: const InputDecoration(labelText: 'Wholesale Price (₱)'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _stockCtrl, decoration: const InputDecoration(labelText: 'Stock Qty'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _minCtrl, decoration: const InputDecoration(labelText: 'Min Stock'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _maxCtrl, decoration: const InputDecoration(labelText: 'Max Stock'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
