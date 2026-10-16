// lib/provider/product_provider.dart
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'product_provider.g.dart';

const _customLimit = AppConstants.paginationPageSize;
const productListApiCacheKey = 'products';

@Riverpod(keepAlive: true)
class ProductNotifier extends _$ProductNotifier {
  int _page = 1;
  int _limit = _customLimit;
  String? _categoryId;
  String? _search;
  int? _minPrice;
  int? _maxPrice;
  int _generation = 0;
  int _collectionRevision = 0;
  final _collectionChanges = <String, ({int revision, bool collected})>{};

  @override
  CustomAsyncValue<ProductPagination> build() {
    ref.onDispose(() => _generation++);
    // Start with an empty list - products will be loaded from API
    return CustomAsyncValue.initial();
  }

  void reset() {
    _generation++;
    _collectionChanges.clear();
    _page = 1;
    _categoryId = _search = null;
    _minPrice = _maxPrice = null;
    state = CustomAsyncValue.initial();
  }

  /// Loads products from the API
  Future<void> loadProducts({
    String? categoryId,
    String? search,
    int? minPrice,
    int? maxPrice,
    bool reuseExisting = false,
  }) async {
    final sameQuery =
        categoryId == _categoryId &&
        search == _search &&
        minPrice == _minPrice &&
        maxPrice == _maxPrice;
    if (sameQuery &&
        (state.isLoading ||
            (reuseExisting && (state.isDone || state.isFetching)))) {
      return;
    }
    final generation = ++_generation;
    final collectionRevision = _collectionRevision;
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
              "status": "active",
              "page": _page,
              "limit": _limit,
              "categoryId": _categoryId,
              "search": _search,
              "minPrice": _minPrice,
              "maxPrice": _maxPrice,
            },
          );

      if (generation != _generation) return;
      final data = response.data;
      if (data['success'] != true || data['data']?['products'] is! List) {
        throw Exception("Failed to get response data");
      }
      final products = List.generate(data['data']['products'].length, (index) {
        final map = data['data']['products'][index];
        return _mergeCollectionStatus(
          Product.fromApiResponseMap(map),
          collectionRevision,
        );
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
      if (generation != _generation) return;
      log('Error loading products: $e');
      state = CustomAsyncValue.error(getDioExceptionMessage(e));
    } catch (e) {
      if (generation != _generation) return;
      log('Error loading products: $e');
      state = CustomAsyncValue.error('Error loading products: $e');
    }
  }

  Future<void> refreshProducts() {
    return loadProducts(
      categoryId: _categoryId,
      search: _search,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
    );
  }

  void setProductCollected(String productId, bool collected) {
    _collectionChanges[productId] = (
      revision: ++_collectionRevision,
      collected: collected,
    );
    final data = state.data;
    if (data == null) return;
    final updated = data.copyWith(
      products: [
        for (final product in data.products)
          product.id == productId
              ? product.copyWith(isCollected: collected)
              : product,
      ],
    );
    state = state.isFetching
        ? CustomAsyncValue.fetching(updated)
        : CustomAsyncValue.done(updated);
  }

  Product _mergeCollectionStatus(Product product, int requestRevision) {
    final change = _collectionChanges[product.id];
    // Do not let a response started before a successful mutation undo it.
    if (change != null && change.revision > requestRevision) {
      return product.copyWith(isCollected: change.collected);
    }
    return product;
  }

  Future<void> fetchMoreProducts() async {
    if (!state.isDone || _page >= (state.data?.totalPages ?? double.infinity)) {
      return;
    }
    final generation = _generation;
    final collectionRevision = _collectionRevision;
    final nextPage = _page + 1;
    try {
      state = CustomAsyncValue.fetching(state.data);
      final response = await ref
          .read(dioProvider)
          .get(
            "/api/product/list",
            queryParameters: {
              "status": "active",
              "page": nextPage,
              "limit": _limit,
              "categoryId": _categoryId,
              "search": _search,
              "minPrice": _minPrice,
              "maxPrice": _maxPrice,
            },
          );

      if (generation != _generation) return;
      final data = response.data;
      if (data['success'] != true || data['data']?['products'] is! List) {
        throw Exception("Failed to get response data");
      }
      final products = List.generate(data['data']['products'].length, (index) {
        final map = data['data']['products'][index];
        return _mergeCollectionStatus(
          Product.fromApiResponseMap(map),
          collectionRevision,
        );
      });

      _page = nextPage;
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
      if (generation != _generation) return;
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
double totalProductValue(Ref ref) {
  final products = ref.watch(productNotifierProvider).data?.products ?? [];
  return products.fold(0.0, (sum, product) => sum + product.price);
}
