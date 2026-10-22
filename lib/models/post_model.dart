class PostModel {
  final int id;
  final String? author;
  final String content;
  final String? image;
  int likes;
  final DateTime createdAt;

  PostModel({
    required this.id,
    this.author,
    required this.content,
    this.image,
    this.likes = 0,
    required this.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return PostModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      author: json['author']?.toString() ?? 'Khách',
      content: json['content']?.toString() ?? '',
      image: json['image']?.toString(),
      likes: json['likes'] is int ? json['likes'] : int.tryParse(json['likes'].toString()) ?? 0,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': author,
      'content': content,
      'image': image,
      'likes': likes,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
