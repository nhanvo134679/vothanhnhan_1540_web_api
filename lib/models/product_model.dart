import 'category_model.dart';

class ProductModel {
  final int id;
  final String name;
  final double price;
  final String? image;
  final String? description;
  final int? categoryId;
  final CategoryModel? category;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    this.image,
    this.description,
    this.categoryId,
    this.category,
  });

  String get categoryName => category?.name ?? (categoryId != null ? 'Danh mục #$categoryId' : 'Chưa phân loại');

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      price: json['price'] != null ? (double.tryParse(json['price'].toString()) ?? 0.0) : 0.0,
      image: json['image']?.toString(),
      description: json['description']?.toString(),
      categoryId: json['categoryId'] != null ? int.tryParse(json['categoryId'].toString()) : null,
      category: json['category'] != null ? CategoryModel.fromJson(json['category']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'image': image,
      'description': description,
      'categoryId': categoryId,
    };
  }
}
