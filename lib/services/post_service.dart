import '../models/post_model.dart';
import 'api_service.dart';

class PostService {
  final ApiService _api = ApiService();

  Future<List<PostModel>> getPosts() async {
    final response = await _api.get('/api/PostApi');
    if (response.isSuccess && response.data is List) {
      return (response.data as List)
          .map((item) => PostModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<PostModel?> getPostById(int id) async {
    final response = await _api.get('/api/PostApi/$id');
    if (response.isSuccess && response.data is Map<String, dynamic>) {
      return PostModel.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  }

  Future<Map<String, dynamic>> addPost({
    required String content,
    String? image,
  }) async {
    final response = await _api.post('/api/PostApi', body: {
      'content': content,
      'image': image,
    });

    if (response.isSuccess) {
      return {
        'success': true,
        'message': 'Đăng bài viết thành công!',
        'data': response.data != null ? PostModel.fromJson(response.data) : null,
      };
    } else {
      return {
        'success': false,
        'message': response.errorMessage ?? 'Không thể đăng bài viết.',
      };
    }
  }

  Future<Map<String, dynamic>> updatePost({
    required int id,
    required String content,
    String? image,
    int? likes,
  }) async {
    final response = await _api.put('/api/PostApi/$id', body: {
      'id': id,
      'content': content,
      'image': image,
      'likes': likes ?? 0,
    });

    if (response.isSuccess) {
      return {
        'success': true,
        'message': 'Cập nhật bài viết thành công!',
      };
    } else {
      return {
        'success': false,
        'message': response.errorMessage ?? 'Không thể cập nhật bài viết.',
      };
    }
  }

  Future<Map<String, dynamic>> likePost(int id) async {
    final response = await _api.post('/api/PostApi/$id/like');
    if (response.isSuccess && response.data is Map<String, dynamic>) {
      return {
        'success': true,
        'data': PostModel.fromJson(response.data as Map<String, dynamic>),
      };
    } else {
      return {
        'success': false,
        'message': response.errorMessage ?? 'Không thể thích bài viết.',
      };
    }
  }

  Future<Map<String, dynamic>> deletePost(int id) async {
    final response = await _api.delete('/api/PostApi/$id');
    if (response.isSuccess) {
      return {
        'success': true,
        'message': 'Xóa bài viết thành công!',
      };
    } else {
      return {
        'success': false,
        'message': response.errorMessage ?? 'Không thể xóa bài viết.',
      };
    }
  }
}
