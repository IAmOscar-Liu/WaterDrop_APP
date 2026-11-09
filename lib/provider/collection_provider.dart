import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/models/collection.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/product_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:flutter_ad_ecommerce/utils/product_availability.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'collection_provider.g.dart';

const _customLimit = AppConstants.paginationPageSize;

@Riverpod()
class CollectionNotifier extends _$CollectionNotifier {
  int _page = 1;
  int _generation = 0;
  int _limit = _customLimit;
  String? _search;

  @override
  CustomAsyncValue<CollectionPagination> build() {
    ref.onDispose(() => _generation++);
    // Start with an empty list - products will be loaded from API
    return CustomAsyncValue.initial();
  }

  void reset() {
    _generation++;
    _page = 1;
    state = CustomAsyncValue.initial();
  }

  Future<void> loadCollections({
    String? categoryId,
    String? search,
    int? minPrice,
    int? maxPrice,
  }) async {
    final previousData = search == _search ? state.data : null;
    final generation = ++_generation;
    try {
      _page = 1;
      _limit = _customLimit;
      _search = search;

      state = previousData == null
          ? CustomAsyncValue.loading()
          : CustomAsyncValue.fetching(previousData);
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

      if (generation != _generation) return;
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
      if (generation != _generation) return;
      log('Error loading collections: $e');
      state = previousData == null
          ? CustomAsyncValue.error(AppFailure.from(e))
          : CustomAsyncValue.retained(previousData, e);
    } catch (e) {
      if (generation != _generation) return;
      log('Error loading collections: $e');
      state = previousData == null
          ? CustomAsyncValue.error(AppFailure.from(e))
          : CustomAsyncValue.retained(previousData, e);
    }
  }

  Future<void> fetchMoreCollections() async {
    if (!state.isDone || _page >= (state.data?.totalPages ?? double.infinity)) {
      return;
    }
    final generation = _generation;
    final nextPage = _page + 1;
    try {
      state = CustomAsyncValue.fetching(state.data);
      final response = await ref
          .read(dioProvider)
          .get(
            "/api/collection/list",
            queryParameters: {
              "page": nextPage,
              "limit": _limit,
              "search": _search,
            },
          );

      if (generation != _generation) return;
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

      _page = nextPage;
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
      if (generation != _generation) return;
      log('Error loading collections: $e');
      state = state.data != null
          ? CustomAsyncValue.retained(state.data!, e, pagination: true)
          : CustomAsyncValue.error(
              e is DioException
                  ? getDioExceptionMessage(e)
                  : AppFailure.from(e),
            );
    }
  }

  Future<Result<String>> addCollection(
    String productId, {
    String? productName,
  }) async {
    if (state.isProcessing) return Result.failure("processing");
    final keepAlive = ref.keepAlive();

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

      ref
          .read(productNotifierProvider.notifier)
          .setProductCollected(productId, true);
      return Result.success(
        productName != null ? "「$productName」已加入我的收藏" : "商品已加入我的收藏",
      );
    } catch (e) {
      log('Failed to add collection: $e');
      if (e is DioException && isProductAvailabilityError(e)) {
        await loadCollections(search: _search);
      }
      return Result.failure(
        e is DioException ? productMutationErrorMessage(e) : AppFailure.from(e),
      );
    } finally {
      state = CustomAsyncValue.done(
        state.data == null ? CollectionPagination.zero() : state.data!,
      );
      keepAlive.close();
    }
  }

  Future<Result<String>> removeCollection(
    String productId, {
    String? productName,
  }) async {
    if (state.isProcessing) return Result.failure("processing");
    final keepAlive = ref.keepAlive();

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

      ref
          .read(productNotifierProvider.notifier)
          .setProductCollected(productId, false);
      return Result.success(
        productName != null ? "「$productName」已移除我的收藏" : "商品已移除我的收藏",
      );
    } catch (e) {
      log('Failed to remove collection: $e');
      if (e is DioException &&
          e.response?.statusCode == 404 &&
          (AppFailure.from(e).code == 'RESOURCE_NOT_FOUND' ||
              (e.response?.data is Map &&
                  e.response!.data['message'] == 'Collection not found'))) {
        // Product deletion may have already removed the saved record.
        // Refresh cached results and let the caller clear its saved state.
        final current = state.data;
        if (current != null) {
          final remaining = current.collections
              .where((item) => item.productId != productId)
              .toList();
          state = CustomAsyncValue.done(
            current.copyWith(
              collections: remaining,
              total:
                  (current.total -
                          (current.collections.length - remaining.length))
                      .clamp(0, current.total),
            ),
          );
        }
        await loadCollections(search: _search);
        ref
            .read(productNotifierProvider.notifier)
            .setProductCollected(productId, false);
        return Result.success('此商品已不在我的收藏中');
      }
      return Result.failure(
        e is DioException ? getDioExceptionMessage(e) : AppFailure.from(e),
      );
    } finally {
      if (state.isProcessing) {
        state = CustomAsyncValue.done(
          state.data == null ? CollectionPagination.zero() : state.data!,
        );
      }
      keepAlive.close();
    }
  }
}
