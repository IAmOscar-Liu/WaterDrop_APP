// lib/provider/product_provider.dart
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'product_provider.g.dart';

final _customLimit = 10;

@Riverpod()
class ProductNotifier extends _$ProductNotifier {
  int _page = 1;
  int _limit = _customLimit;
  String? _categoryId;
  String? _search;
  int? _minPrice;
  int? _maxPrice;

  @override
  CustomAsyncValue<ProductPagination> build() {
    // Start with an empty list - products will be loaded from API
    return CustomAsyncValue.initial();
  }

  void reset() {
    state = CustomAsyncValue.initial();
  }

  /// Loads products from the API
  Future<void> loadProducts({
    String? categoryId,
    String? search,
    int? minPrice,
    int? maxPrice,
  }) async {
    try {
      _page = 1;
      _limit = _customLimit;
      _categoryId = categoryId;
      _search = search;
      _minPrice = minPrice;
      _maxPrice = maxPrice;

      state = CustomAsyncValue.loading();
      final response = await ref
          .read(dioProvider)
          .get(
            "/api/product/list",
            queryParameters: {
              "page": _page,
              "limit": _limit,
              "categoryId": _categoryId,
              "search": _search,
              "minPrice": _minPrice,
              "maxPrice": _maxPrice,
            },
          );

      final data = response.data;
      if (data['success'] != true || data['data']?['products'] is! List) {
        throw Exception("Failed to get response data");
      }
      final products = List.generate(data['data']['products'].length, (index) {
        final map = data['data']['products'][index];
        return Product.fromApiResponseMap(map);
      });

      state = CustomAsyncValue.done(
        ProductPagination(
          products: products,
          total: ParseUtils.parseInt(data['data']['total']) ?? _limit,
          page: ParseUtils.parseInt(data['data']['page']) ?? 1,
          limit: ParseUtils.parseInt(data['data']['limit']) ?? _limit,
          totalPages: ParseUtils.parseInt(data['data']['totalPages']) ?? 1,
        ),
      );
    } on DioException catch (e) {
      log('Error loading products: $e');
      state = CustomAsyncValue.error(getDioExceptionMessage(e));
    } catch (e) {
      log('Error loading products: $e');
      state = CustomAsyncValue.error('Error loading products: $e');
    }
  }

  Future<void> fetchMoreProducts() async {
    if (!state.isDone || _page >= (state.data?.totalPages ?? double.infinity)) {
      return;
    }
    _page++;
    try {
      state = CustomAsyncValue.fetching(state.data);
      final response = await ref
          .read(dioProvider)
          .get(
            "/api/product/list",
            queryParameters: {
              "page": _page,
              "limit": _limit,
              "categoryId": _categoryId,
              "search": _search,
              "minPrice": _minPrice,
              "maxPrice": _maxPrice,
            },
          );

      final data = response.data;
      if (data['success'] != true || data['data']?['products'] is! List) {
        throw Exception("Failed to get response data");
      }
      final products = List.generate(data['data']['products'].length, (index) {
        final map = data['data']['products'][index];
        return Product.fromApiResponseMap(map);
      });

      state = CustomAsyncValue.done(
        ProductPagination(
          products: [...(state.data?.products ?? []), ...products],
          total: ParseUtils.parseInt(data['data']['total']) ?? _limit,
          page: ParseUtils.parseInt(data['data']['page']) ?? 1,
          limit: ParseUtils.parseInt(data['data']['limit']) ?? _limit,
          totalPages: ParseUtils.parseInt(data['data']['totalPages']) ?? 1,
        ),
      );
    } catch (e) {
      log('Error loading products: $e');
      state = state.data != null
          ? CustomAsyncValue.done(state.data!)
          : CustomAsyncValue.error(
              e is DioException
                  ? getDioExceptionMessage(e)
                  : 'Error loading products: $e',
            );
    }
  }
}

/// Computed provider that calculates the total value of all products
@riverpod
double totalProductValue(TotalProductValueRef ref) {
  final products = ref.watch(productNotifierProvider).data?.products ?? [];
  return products.fold(0.0, (sum, product) => sum + product.price);
}
