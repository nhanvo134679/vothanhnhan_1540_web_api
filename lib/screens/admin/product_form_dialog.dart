import 'package:flutter/material.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';

class ProductFormDialog extends StatefulWidget {
  final ProductModel? product;

  const ProductFormDialog({super.key, this.product});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageController = TextEditingController();
  final _descController = TextEditingController();

  int? _selectedCategoryId;
  List<CategoryModel> _categories = [];
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;

  bool get isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _nameController.text = widget.product!.name;
      _priceController.text = widget.product!.price.toStringAsFixed(0);
      _imageController.text = widget.product!.image ?? '';
      _descController.text = widget.product!.description ?? '';
      _selectedCategoryId = widget.product!.categoryId;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final list = await CategoryService().getCategories();
    if (!mounted) return;
    setState(() {
      _categories = list;
      _isLoadingCategories = false;
      // If selected category is not in list, keep or reset
      if (_selectedCategoryId != null &&
          !_categories.any((c) => c.id == _selectedCategoryId)) {
        _selectedCategoryId = null;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    setState(() => _isSubmitting = true);

    final service = ProductService();
    Map<String, dynamic> result;

    if (isEdit) {
      result = await service.updateProduct(
        id: widget.product!.id,
        name: _nameController.text.trim(),
        price: price,
        image: _imageController.text.trim().isNotEmpty ? _imageController.text.trim() : null,
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        categoryId: _selectedCategoryId,
      );
    } else {
      result = await service.addProduct(
        name: _nameController.text.trim(),
        price: price,
        image: _imageController.text.trim().isNotEmpty ? _imageController.text.trim() : null,
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        categoryId: _selectedCategoryId,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Thao tác sản phẩm thất bại.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEdit ? 'Sửa Sản Phẩm' : 'Thêm Sản Phẩm Mới'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên sản phẩm *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng nhập tên sản phẩm';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Price
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giá bán (VNĐ) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                    hintText: '100000',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng nhập giá';
                    }
                    if (double.tryParse(val.trim()) == null || double.parse(val.trim()) < 0) {
                      return 'Giá phải là số hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Category selector
                _isLoadingCategories
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: LinearProgressIndicator(),
                      )
                    : DropdownButtonFormField<int?>(
                        initialValue: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Danh mục sản phẩm',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Chưa phân loại (Không chọn)'),
                          ),
                          ..._categories.map((c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(c.name),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedCategoryId = val);
                        },
                      ),
                const SizedBox(height: 14),

                // Image URL
                TextFormField(
                  controller: _imageController,
                  decoration: const InputDecoration(
                    labelText: 'URL hình ảnh sản phẩm',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.image_outlined),
                    hintText: 'https://example.com/image.jpg',
                  ),
                ),
                const SizedBox(height: 14),

                // Description
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả chi tiết',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isEdit ? 'Cập Nhật' : 'Thêm Mới'),
        ),
      ],
    );
  }
}
