import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/post_model.dart';
import '../../services/auth_service.dart';
import '../../services/post_service.dart';
import 'post_form_dialog.dart';

class PostsFeedScreen extends StatefulWidget {
  final bool isStandalone;
  const PostsFeedScreen({super.key, this.isStandalone = true});

  @override
  State<PostsFeedScreen> createState() => _PostsFeedScreenState();
}

class _PostsFeedScreenState extends State<PostsFeedScreen> {
  final PostService _postService = PostService();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  List<PostModel> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    final data = await _postService.getPosts();
    if (!mounted) return;
    setState(() {
      _posts = data;
      _isLoading = false;
    });
  }

  Future<void> _openPostDialog([PostModel? post]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PostFormDialog(post: post),
    );

    if (result == true) {
      _loadPosts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(post == null ? 'Đăng bài thành công!' : 'Cập nhật bài viết thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _likePost(PostModel post) async {
    // Optimistic UI update
    setState(() {
      post.likes++;
    });

    final res = await _postService.likePost(post.id);
    if (!mounted) return;
    if (res['success'] == true) {
      final updated = res['data'] as PostModel?;
      if (updated != null) {
        setState(() {
          post.likes = updated.likes;
        });
      }
    } else {
      // Revert if error
      setState(() {
        post.likes--;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Không thể thích bài viết.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deletePost(PostModel post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa bài viết'),
        content: const Text('Bạn có chắc chắn muốn xóa bài viết này không?'),
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
      final res = await _postService.deletePost(post.id);
      if (!mounted) return;
      if (res['success'] == true) {
        _loadPosts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa bài viết thành công!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Không thể xóa bài viết.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  bool _canModify(PostModel post) {
    final user = AuthService().currentUser;
    if (user == null) return false;
    if (user.isAdmin) return true;
    return user.username.toLowerCase() == (post.author ?? '').toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadPosts,
            child: _posts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.feed_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'Chưa có bài viết nào trên bảng tin.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _openPostDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Đăng Bài Viết Đầu Tiên'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _posts.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      final canEdit = _canModify(post);

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Author & Date Header
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.indigo.shade600,
                                    foregroundColor: Colors.white,
                                    child: Text(
                                      (post.author?.isNotEmpty == true
                                              ? post.author![0]
                                              : 'U')
                                          .toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          post.author ?? 'Người dùng',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          _dateFormat.format(post.createdAt),
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (canEdit)
                                    PopupMenuButton<String>(
                                      onSelected: (action) {
                                        if (action == 'edit') {
                                          _openPostDialog(post);
                                        } else if (action == 'delete') {
                                          _deletePost(post);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 18, color: Colors.blue),
                                              SizedBox(width: 8),
                                              Text('Chỉnh sửa'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete, size: 18, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Xóa bài'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Post Content
                              Text(
                                post.content,
                                style: const TextStyle(fontSize: 15, height: 1.4),
                              ),

                              // Post Image if present
                              if (post.image != null && post.image!.startsWith('http')) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    post.image!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 200,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 100,
                                      color: Colors.grey.shade100,
                                      child: const Center(
                                        child: Icon(Icons.broken_image, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 8),

                              // Actions: Like button
                              Row(
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _likePost(post),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      child: Row(
                                        children: [
                                          Icon(
                                            post.likes > 0 ? Icons.favorite : Icons.favorite_border,
                                            color: post.likes > 0 ? Colors.red : Colors.grey.shade600,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${post.likes} Thích',
                                            style: TextStyle(
                                              color: post.likes > 0 ? Colors.red.shade700 : Colors.grey.shade700,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Đồng bộ API',
                                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          );

    if (!widget.isStandalone) {
      return Scaffold(
        body: content,
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openPostDialog(),
          backgroundColor: Colors.indigo.shade600,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng Tin & Bài Viết'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPostDialog(),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Đăng Bài Viết'),
      ),
      body: content,
    );
  }
}
