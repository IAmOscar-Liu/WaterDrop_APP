import 'dart:developer';

import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// This line is crucial for code generation.
// It tells build_runner to generate a part file for this file.
part 'product_category_provider.g.dart';

@Riverpod(keepAlive: true)
class ProductCategory extends _$ProductCategory {
  @override
  List<Category> build() {
    return [];
  }

  void loadProductCategory() async {
    try {
      final response = await ref
          .read(dioProvider)
          .get("/api/product/categories/list");

      final data = response.data;
      if (data['success'] != true || data['data'] is! List) {
        throw Exception("Failed to get response data");
      }

      final productCategories = List.generate(
        data['data'].length,
        (index) => Category.fromApiResponseMap(data['data'][index]),
      );
      state = productCategories;
    } catch (e) {
      log('Error loading product category: $e');
    }
  }
}
