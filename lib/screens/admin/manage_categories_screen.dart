import 'package:flutter/material.dart';
import '../../models/category_model.dart';
import '../../services/category_service.dart';
import 'category_form_dialog.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final CategoryService _categoryService = CategoryService();
  List<CategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final data = await _categoryService.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = data;
      _isLoading = false;
    });
  }

  Future<void> _openCategoryDialog([CategoryModel? category]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CategoryFormDialog(category: category),
    );

    if (result == true) {
      _loadCategories();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(category == null
              ? 'Thêm danh mục thành công!'
              : 'Cập nhật danh mục thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteCategory(CategoryModel category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa danh mục'),
        content: Text(
          'Bạn có chắc chắn muốn xóa danh mục "${category.name}"?\n'
          'Các sản phẩm thuộc danh mục này sẽ chuyển sang trạng thái "Chưa phân loại".',
        ),
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
      final res = await _categoryService.deleteCategory(category.id);
      if (!mounted) return;
      if (res['success'] == true) {
        _loadCategories();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa danh mục thành công!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Không thể xóa danh mục.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Danh Mục (CRUD)'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCategoryDialog(),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm Danh Mục'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCategories,
              child: _categories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'Chưa có danh mục nào.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _openCategoryDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Tạo Danh Mục Đầu Tiên'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _categories.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        return Card(
                          elevation: 1.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo.shade50,
                              foregroundColor: Colors.indigo.shade700,
                              child: Text(
                                cat.name.isNotEmpty ? cat.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              cat.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(
                              cat.description?.isNotEmpty == true
                                  ? cat.description!
                                  : 'Không có mô tả',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Chỉnh sửa',
                                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                  onPressed: () => _openCategoryDialog(cat),
                                ),
                                IconButton(
                                  tooltip: 'Xóa',
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _deleteCategory(cat),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
