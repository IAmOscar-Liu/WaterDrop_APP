// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:flutter_ad_ecommerce/models/advertisement.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';

class Category {
  final String id;
  final String name;

  Category({required this.id, required this.name});

  factory Category.fromApiResponseMap(Map<String, dynamic> map) {
    return Category(
      id: ParseUtils.parseString(map['id']) ?? "",
      name: ParseUtils.parseString(map['name']) ?? "",
    );
  }
}

class Seller {
  final String name;
  final String realName;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String role;

  Seller({
    required this.name,
    required this.realName,
    required this.email,
    required this.phone,
    this.avatarUrl,
    required this.role,
  });

  factory Seller.fromApiResponseMap(Map<String, dynamic> map) {
    return Seller(
      name: ParseUtils.parseString(map['name']) ?? "",
      realName: ParseUtils.parseString(map['realName']) ?? "",
      email: ParseUtils.parseString(map['email']) ?? "",
      phone: ParseUtils.parseString(map['phone']) ?? "",
      avatarUrl: ParseUtils.parseString(map['avatar_url']),
      role: ParseUtils.parseString(map['role']) ?? "",
    );
  }
}

class Product {
  final String id;
  final String sellerId;
  final String name;
  final String description;
  final double price;
  final int stock;
  final int reserve;
  final String type;
  final bool allowHomeDelivery;
  final List<String>? images;
  final Advertisement? advertisement;
  final List<Category>? categories;
  final Seller? seller;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt; // Made optional
  final Map<String, dynamic>? metadata; // New optional property for metadata

  Product({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.reserve,
    required this.type,
    required this.allowHomeDelivery,
    required this.images,
    this.advertisement,
    this.categories,
    this.seller,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  // Simple factory for demonstration, could be from JSON in a real app
  factory Product.fromApiResponseMap(Map<String, dynamic> map) {
    List<Category> categories = [];
    if (map['productsToCategories'] is List) {
      for (var item in map['productsToCategories']) {
        if (item['category'] is Map) {
          categories.add(Category.fromApiResponseMap(item['category']));
        }
      }
    }
    List<String>? images = map['images'] is List
        ? List.generate(
            map['images'].length,
            (index) => ParseUtils.parseString(map['images'][index]) ?? "",
          ).where((e) => e.isNotEmpty).toList()
        : null;
    Advertisement? advertisement = map['advertisement'] is Map
        ? Advertisement.fromApiResponse(map['advertisement'], index: 0)
        : null;
    Seller? seller = map['seller'] is Map
        ? Seller.fromApiResponseMap(map['seller'])
        : null;

    return Product(
      id: ParseUtils.parseString(map['id']) ?? "",
      sellerId: ParseUtils.parseString(map['sellerId']) ?? "",
      name: ParseUtils.parseString(map['name']) ?? "",
      price: ParseUtils.parseDouble(map['price']) ?? 0,
      description: ParseUtils.parseString(map['description']) ?? "",
      stock: ParseUtils.parseInt(map['stock']) ?? 0,
      reserve: ParseUtils.parseInt(map['reserve']) ?? 0,
      type: ParseUtils.parseString(map['type']) ?? "",
      allowHomeDelivery: map['allowHomeDelivery'] == true,
      images: images,
      advertisement: advertisement,
      categories: categories,
      seller: seller,
      status: ParseUtils.parseString(map['status']) ?? "",
      createdAt: ParseUtils.parseDateTime(map['createdAt']),
      updatedAt: ParseUtils.parseDateTime(map['updatedAt']),
      metadata: map['metadata'] is Map
          ? map['metadata']
          : null, // Handle nullable metadata
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'stock': stock,
      "reserve": reserve,
      'images': images,
      'advertisement': advertisement.toString(),
      'categories': categories.toString(),
      'seller': seller.toString(),
      'type': type,
      'allowHomeDelivery': allowHomeDelivery,
      'status': status,
      'createdAt': createdAt.toString(),
      'update': updatedAt.toString(),
      'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  // A helper method to create a new Product with updated properties
  Product copyWith({
    String? id,
    String? sellerId,
    String? name,
    String? description,
    double? price,
    int? stock,
    int? reserve,
    String? type,
    bool? allowHomeDelivery,
    List<String>? images,
    Advertisement? advertisement,
    List<Category>? categories,
    Seller? seller,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt, // Made optional
    Map<String, dynamic>? metadata, // New optional property for metadata
  }) {
    return Product(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      reserve: reserve ?? this.reserve,
      type: type ?? this.type,
      allowHomeDelivery: allowHomeDelivery ?? this.allowHomeDelivery,
      images: images ?? this.images,
      advertisement: advertisement ?? this.advertisement,
      categories: categories ?? this.categories,
      seller: seller ?? this.seller,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

class ProductPagination {
  List<Product> products;
  int total;
  int page;
  int limit;
  int totalPages;
  ProductPagination({
    required this.products,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  ProductPagination copyWith({
    List<Product>? products,
    int? total,
    int? page,
    int? limit,
    int? totalPages,
  }) {
    return ProductPagination(
      products: products ?? this.products,
      total: total ?? this.total,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}

// class CartItem {
//   final Product product;
//   int quantity; // Quantity can be mutable for updates

//   CartItem({required this.product, this.quantity = 1});

//   // Helper to create a new CartItem with updated quantity
//   CartItem copyWith({int? quantity}) {
//     return CartItem(product: product, quantity: quantity ?? this.quantity);
//   }
// }

class CartItem {
  final String id;
  final String userId;
  final String productId;
  final int quantity;
  final bool checked;
  final DateTime? createdAt;
  final Product product;

  CartItem({
    required this.id,
    required this.userId,
    required this.productId,
    required this.quantity,
    this.checked = false,
    this.createdAt,
    required this.product,
  });

  // Helper to create a new CartItem with updated quantity
  CartItem copyWith({
    String? id,
    String? userId,
    String? productId,
    int? quantity,
    bool? checked,
    DateTime? createdAt,
    Product? product,
  }) {
    return CartItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      checked: checked ?? this.checked,
      createdAt: createdAt ?? this.createdAt,
      product: product ?? this.product,
    );
  }

  // Simple factory for demonstration, could be from JSON in a real app
  factory CartItem.fromApiResponseMap(Map<String, dynamic> map) {
    return CartItem(
      id: ParseUtils.parseString(map['id']) ?? "",
      userId: ParseUtils.parseString(map['userId']) ?? "",
      productId: ParseUtils.parseString(map['productId']) ?? "",
      quantity: ParseUtils.parseInt(map['quantity']) ?? 1,
      checked: map['checked'] == true,
      createdAt: ParseUtils.parseDateTime(map['createdAt']),
      product: Product.fromApiResponseMap(map['product']),
    );
  }
}

String productStatusTranslation(String status) {
  switch (status) {
    case "active":
      return "上架中";
    default:
      return "已下架";
  }
}
