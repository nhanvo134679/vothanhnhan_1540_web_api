import '../models/product_model.dart';
import 'api_service.dart';

class ProductService {
  final ApiService _api = ApiService();

  Future<List<ProductModel>> getProducts() async {
    final response = await _api.get('/api/ProductApi');
    if (response.isSuccess && response.data is List) {
      return (response.data as List)
          .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<ProductModel?> getProductById(int id) async {
    final response = await _api.get('/api/ProductApi/$id');
    if (response.isSuccess && response.data is Map<String, dynamic>) {
      return ProductModel.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  }

  Future<List<ProductModel>> searchProducts(String name) async {
    final response = await _api.get('/api/ProductApi/search', queryParams: {'name': name});
    if (response.isSuccess && response.data is List) {
      return (response.data as List)
          .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> addProduct({
    required String name,
    required double price,
    String? image,
    String? description,
    int? categoryId,
  }) async {
    final response = await _api.post('/api/ProductApi', body: {
      'name': name,
      'price': price,
      'image': image,
      'description': description,
      'categoryId': categoryId,
    });

    if (response.isSuccess) {
      return {
        'success': true,
        'message': 'Thêm sản phẩm thành công!',
        'data': response.data != null ? ProductModel.fromJson(response.data) : null,
      };
    } else {
      return {
        'success': false,
        'message': response.errorMessage ?? 'Không thể thêm sản phẩm.',
      };
    }
  }

  Future<Map<String, dynamic>> updateProduct({
    required int id,
    required String name,
    required double price,
    String? image,
    String? description,
    int? categoryId,
  }) async {
    final response = await _api.put('/api/ProductApi/$id', body: {
      'id': id,
      'name': name,
      'price': price,
      'image': image,
      'description': description,
      'categoryId': categoryId,
    });

    if (response.isSuccess) {
      return {
        'success': true,
        'message': 'Cập nhật sản phẩm thành công!',
      };
    } else {
      return {
        'success': false,
        'message': response.errorMessage ?? 'Không thể cập nhật sản phẩm.',
      };
    }
  }

  Future<Map<String, dynamic>> deleteProduct(int id) async {
    final response = await _api.delete('/api/ProductApi/$id');
    if (response.isSuccess) {
      return {
        'success': true,
        'message': 'Xóa sản phẩm thành công!',
      };
    } else {
      return {
        'success': false,
        'message': response.errorMessage ?? 'Không thể xóa sản phẩm.',
      };
    }
  }
}
