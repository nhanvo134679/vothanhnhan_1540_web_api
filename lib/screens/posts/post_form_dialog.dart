import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';

class PostFormDialog extends StatefulWidget {
  final PostModel? post;

  const PostFormDialog({super.key, this.post});

  @override
  State<PostFormDialog> createState() => _PostFormDialogState();
}

class _PostFormDialogState extends State<PostFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _imageController = TextEditingController();
  bool _isLoading = false;

  bool get isEdit => widget.post != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _contentController.text = widget.post!.content;
      _imageController.text = widget.post!.image ?? '';
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final service = PostService();
    Map<String, dynamic> result;

    if (isEdit) {
      result = await service.updatePost(
        id: widget.post!.id,
        content: _contentController.text.trim(),
        image: _imageController.text.trim().isNotEmpty ? _imageController.text.trim() : null,
        likes: widget.post!.likes,
      );
    } else {
      result = await service.addPost(
        content: _contentController.text.trim(),
        image: _imageController.text.trim().isNotEmpty ? _imageController.text.trim() : null,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Thao tác bài viết thất bại.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEdit ? 'Chỉnh Sửa Bài Viết' : 'Tạo Bài Viết Mới'),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Nội dung bài viết *',
                  hintText: 'Bạn đang nghĩ gì thế?...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập nội dung bài viết';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _imageController,
                decoration: const InputDecoration(
                  labelText: 'URL hình ảnh đính kèm (tùy chọn)',
                  hintText: 'https://example.com/photo.jpg',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.image_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isEdit ? 'Cập Nhật' : 'Đăng Bài'),
        ),
      ],
    );
  }
}
