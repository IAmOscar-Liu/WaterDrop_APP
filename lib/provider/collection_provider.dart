import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/collection.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'collection_provider.g.dart';

final _customLimit = 10;

@Riverpod()
class CollectionNotifier extends _$CollectionNotifier {
  int _page = 1;
  int _limit = _customLimit;
  String? _search;

  @override
  CustomAsyncValue<CollectionPagination> build() {
    // Start with an empty list - products will be loaded from API
    return CustomAsyncValue.initial();
  }

  void reset() {
    state = CustomAsyncValue.initial();
  }

  Future<void> loadCollections({
    String? categoryId,
    String? search,
    int? minPrice,
    int? maxPrice,
  }) async {
    try {
      _page = 1;
      _limit = _customLimit;
      _search = search;

      state = CustomAsyncValue.loading();
      final response = await ref
          .read(dioProvider)
          .get(
            "/api/collection/list",
            queryParameters: {
              "page": _page,
              "limit": _limit,
              "search": _search,
            },
          );

      final data = response.data;
      if (data['success'] != true || data['data']?['collections'] is! List) {
        throw Exception("Failed to get response data");
      }
      final collections = List.generate(data['data']['collections'].length, (
        index,
      ) {
        final map = data['data']['collections'][index];
        return Collection.fromApiResponseMap(map);
      });

      state = CustomAsyncValue.done(
        CollectionPagination(
          collections: collections,
          total: ParseUtils.parseInt(data['data']['total']) ?? _limit,
          page: ParseUtils.parseInt(data['data']['page']) ?? 1,
          limit: ParseUtils.parseInt(data['data']['limit']) ?? _limit,
          totalPages: ParseUtils.parseInt(data['data']['totalPages']) ?? 1,
        ),
      );
    } on DioException catch (e) {
      log('Error loading collections: $e');
      state = CustomAsyncValue.error(getDioExceptionMessage(e));
    } catch (e) {
      log('Error loading collections: $e');
      state = CustomAsyncValue.error('Error loading collections: $e');
    }
  }

  Future<void> fetchMoreCollections() async {
    if (!state.isDone || _page >= (state.data?.totalPages ?? double.infinity)) {
      return;
    }
    _page++;
    try {
      state = CustomAsyncValue.fetching(state.data);
      final response = await ref
          .read(dioProvider)
          .get(
            "/api/collection/list",
            queryParameters: {
              "page": _page,
              "limit": _limit,
              "search": _search,
            },
          );

      final data = response.data;
      if (data['success'] != true || data['data']?['collections'] is! List) {
        throw Exception("Failed to get response data");
      }
      final collections = List.generate(data['data']['collections'].length, (
        index,
      ) {
        final map = data['data']['collections'][index];
        return Collection.fromApiResponseMap(map);
      });

      state = CustomAsyncValue.done(
        CollectionPagination(
          collections: [...(state.data?.collections ?? []), ...collections],
          total: ParseUtils.parseInt(data['data']['total']) ?? _limit,
          page: ParseUtils.parseInt(data['data']['page']) ?? 1,
          limit: ParseUtils.parseInt(data['data']['limit']) ?? _limit,
          totalPages: ParseUtils.parseInt(data['data']['totalPages']) ?? 1,
        ),
      );
    } catch (e) {
      log('Error loading collections: $e');
      state = state.data != null
          ? CustomAsyncValue.done(state.data!)
          : CustomAsyncValue.error(
              e is DioException
                  ? getDioExceptionMessage(e)
                  : 'Error loading collections: $e',
            );
    }
  }

  Future<Result<String>> addCollection(
    String productId, {
    String? productName,
  }) async {
    if (state.isProcessing) return Result.failure("processing");

    try {
      state = CustomAsyncValue.processing(
        state.data == null ? CollectionPagination.zero() : state.data!,
      );

      final response = await ref
          .read(dioProvider)
          .post("/api/collection", data: {"productId": productId});

      if (response.data['success'] != true) {
        throw Exception('無法加入我的收藏');
      }

      return Result.success(
        productName != null ? "「$productName」已加入我的收藏" : "商品已加入購物車",
      );
    } catch (e) {
      log('Failed to add collection: $e');
      return Result.failure(
        e is DioException
            ? getDioExceptionMessage(e)
            : 'Failed to add collection: $e',
      );
    } finally {
      state = CustomAsyncValue.done(
        state.data == null ? CollectionPagination.zero() : state.data!,
      );
    }
  }

  Future<Result<String>> removeCollection(
    String productId, {
    String? productName,
  }) async {
    if (state.isProcessing) return Result.failure("processing");

    try {
      state = CustomAsyncValue.processing(
        state.data == null ? CollectionPagination.zero() : state.data!,
      );

      final response = await ref
          .read(dioProvider)
          .delete("/api/collection", data: {"productId": productId});

      if (response.data['success'] != true) {
        throw Exception('無法刪除我的收藏');
      }

      return Result.success(
        productName != null ? "「$productName」已移除我的收藏" : "商品已移除我的收藏",
      );
    } catch (e) {
      log('Failed to add collection: $e');
      return Result.failure(
        e is DioException
            ? getDioExceptionMessage(e)
            : 'Failed to add collection: $e',
      );
    } finally {
      state = CustomAsyncValue.done(
        state.data == null ? CollectionPagination.zero() : state.data!,
      );
    }
  }
}
