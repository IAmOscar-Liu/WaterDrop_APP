import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';

class Collection {
  final String id;
  final String userId;
  final String productId;
  final DateTime createdAt;

  final Product product;

  Collection({
    required this.id,
    required this.userId,
    required this.productId,
    required this.createdAt,
    required this.product,
  });

  factory Collection.fromApiResponseMap(Map<String, dynamic> map) {
    return Collection(
      id: ParseUtils.parseString(map['id']) ?? "",
      userId: ParseUtils.parseString(map['userId']) ?? "",
      productId: ParseUtils.parseString(map['productId']) ?? "",
      createdAt: ParseUtils.parseDateTime(map['createdAt']) ?? DateTime.now(),
      product: Product.fromApiResponseMap(map['product']),
    );
  }

  Collection copyWith({
    String? id,
    String? userId,
    String? productId,
    DateTime? createdAt,
    Product? product,
  }) {
    return Collection(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      createdAt: createdAt ?? this.createdAt,
      product: product ?? this.product,
    );
  }
}

class CollectionPagination {
  List<Collection> collections;
  int total;
  int page;
  int limit;
  int totalPages;
  CollectionPagination({
    required this.collections,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  CollectionPagination copyWith({
    List<Collection>? collections,
    int? total,
    int? page,
    int? limit,
    int? totalPages,
  }) {
    return CollectionPagination(
      collections: collections ?? this.collections,
      total: total ?? this.total,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      totalPages: totalPages ?? this.totalPages,
    );
  }

  factory CollectionPagination.zero() {
    return CollectionPagination(
      collections: [],
      total: 0,
      page: 1,
      limit: 10,
      totalPages: 0,
    );
  }
}
