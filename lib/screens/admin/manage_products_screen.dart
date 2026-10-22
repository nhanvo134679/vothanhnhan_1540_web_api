import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import 'product_form_dialog.dart';

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final ProductService _productService = ProductService();
  final _searchController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  List<ProductModel> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final data = await _productService.getProducts();
    if (!mounted) return;
    setState(() {
      _products = data;
      _isLoading = false;
    });
  }

  Future<void> _handleSearch(String query) async {
    if (query.trim().isEmpty) {
      _loadProducts();
      return;
    }
    setState(() => _isLoading = true);
    final results = await _productService.searchProducts(query.trim());
    if (!mounted) return;
    setState(() {
      _products = results;
      _isLoading = false;
    });
  }

  Future<void> _openProductDialog([ProductModel? product]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ProductFormDialog(product: product),
    );

    if (result == true) {
      _loadProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(product == null
              ? 'Thêm sản phẩm thành công!'
              : 'Cập nhật sản phẩm thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa sản phẩm'),
        content: Text('Bạn có chắc chắn muốn xóa sản phẩm "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await _productService.deleteProduct(product.id);
      if (!mounted) return;
      if (res['success'] == true) {
        _loadProducts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa sản phẩm thành công!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Không thể xóa sản phẩm.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Sản Phẩm (CRUD)'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductDialog(),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm Sản Phẩm'),
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm sản phẩm theo tên...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadProducts();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: _handleSearch,
              onChanged: (val) {
                if (val.isEmpty) _loadProducts();
              },
            ),
          ),

          // Products List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadProducts,
                    child: _products.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'Chưa có sản phẩm nào.',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => _openProductDialog(),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Thêm Sản Phẩm Mới'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _products.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final p = _products[index];
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Image
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 70,
                                          height: 70,
                                          color: Colors.grey.shade100,
                                          child: p.image != null && p.image!.startsWith('http')
                                              ? Image.network(
                                                  p.image!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                                    Icons.image_not_supported,
                                                    color: Colors.grey,
                                                  ),
                                                )
                                              : const Icon(Icons.shopping_bag, color: Colors.indigo, size: 36),
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _currencyFormat.format(p.price),
                                              style: TextStyle(
                                                color: Colors.deepOrange.shade700,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.indigo.shade50,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                p.categoryName,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.indigo.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Actions
                                      Column(
                                        children: [
                                          IconButton(
                                            tooltip: 'Chỉnh sửa',
                                            icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                            onPressed: () => _openProductDialog(p),
                                          ),
                                          IconButton(
                                            tooltip: 'Xóa',
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                            onPressed: () => _deleteProduct(p),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
