import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../data/models/models.dart';
import '../../../data/repositories/product_repository.dart';
import '../../widgets/animated_widgets.dart';

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
  String? _imagePath;

  static const _units = ['piece', 'pack', 'box', 'bottle', 'sachet', 'can', 'kilogram', 'gram', 'liter', 'milliliter'];

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
      _imagePath = p.imagePath;
    }
  }

  Future<void> _loadCats() async {
    _categories = await ProductRepository.instance.categories();
    setState(() {});
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Image Source'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
          ),
        ],
      ),
    );

    if (source == null) return;

    final pickedFile = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (pickedFile != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}${p.extension(pickedFile.path)}';
      final savedFile = await File(pickedFile.path).copy('${appDir.path}/$fileName');
      setState(() => _imagePath = savedFile.path);
    }
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
        imagePath: _imagePath,
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
              // Product image
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _imagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_imagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 48),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 32, color: Colors.grey.shade600),
                              const SizedBox(height: 4),
                              Text('Add Photo', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Product name
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
              AnimatedButton(
                onPressed: _saving ? null : _save,
                icon: Icons.save,
                isLoading: _saving,
                child: const Text('Save Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
