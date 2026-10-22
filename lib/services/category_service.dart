import '../models/category_model.dart';
import 'api_service.dart';

class CategoryService {
  final ApiService _api = ApiService();

  Future<List<CategoryModel>> getCategories() async {
    final response = await _api.get('/api/CategoryApi');
    if (response.isSuccess && response.data is List) {
      return (response.data as List)
          .map((item) => CategoryModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<CategoryModel?> getCategoryById(int id) async {
    final response = await _api.get('/api/CategoryApi/$id');
    if (response.isSuccess && response.data is Map<String, dynamic>) {
      return CategoryModel.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  }

  Future<Map<String, dynamic>> addCategory({
    required String name,
    String? description,
  }) async {
    final response = await _api.post('/api/CategoryApi', body: {
      'name': name,
      'description': description,
    });

    if (response.isSuccess) {
      return {
        'success': true,
        'message': 'Thêm danh mục thành công!',
        'data': response.data != null ? CategoryModel.fromJson(response.data) : null,
      };
    } else {
      return {
        'success': false,
        'message': response.errorMessage ?? 'Không thể thêm danh mục.',
      };
    }
  }

  Future<Map<String, dynamic>> updateCategory({
    required int id,
    required String name,
    String? description,
  }) async {
    final response = await _api.put('/api/CategoryApi/$id', body: {
      'id': id,
      'name': name,
      'description': description,
    });

    if (response.isSuccess) {
      return {
        'success': true,
        'message': 'Cập nhật danh mục thành công!',
      };
    } else {
      return {
        'success': false,
        'message': response.errorMessage ?? 'Không thể cập nhật danh mục.',
      };
    }
  }

  Future<Map<String, dynamic>> deleteCategory(int id) async {
    final response = await _api.delete('/api/CategoryApi/$id');
    if (response.isSuccess) {
      return {
        'success': true,
        'message': 'Xóa danh mục thành công!',
      };
    } else {
      return {
        'success': false,
        'message': response.errorMessage ?? 'Không thể xóa danh mục.',
      };
    }
  }
}
