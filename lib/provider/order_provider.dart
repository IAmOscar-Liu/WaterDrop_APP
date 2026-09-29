import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/cart_provider.dart';
import 'package:flutter_ad_ecommerce/provider/product_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// This line is crucial for code generation.
// It tells build_runner to generate a part file for this file.
part 'order_provider.g.dart';

final _orderLimit = 10;

@Riverpod(keepAlive: true)
class OrderNotifier extends _$OrderNotifier {
  int _page = 1;
  String _order = 'desc';
  DateTime? _startDate;
  DateTime? _endDate;
  int _queryGeneration = 0;

  @override
  CustomAsyncValue<OrderPagination> build() {
    ref.onDispose(() => _queryGeneration++);
    return CustomAsyncValue.initial();
  }

  Map<String, dynamic> _queryParameters(int page) => {
    'page': page,
    'limit': _orderLimit,
    'order': _order,
    if (_startDate != null) 'startDate': _startDate!.toIso8601String(),
    if (_endDate != null) 'endDate': _endDate!.toIso8601String(),
  };

  OrderPagination _parsePage(dynamic responseData, int requestedPage) {
    if (responseData['success'] != true ||
        responseData['data']?['orders'] is! List) {
      throw Exception('Failed to get response data');
    }
    final data = responseData['data'];
    return OrderPagination(
      orders: [for (final map in data['orders']) Order.fromApiResponseMap(map)],
      total: ParseUtils.parseInt(data['total']) ?? _orderLimit,
      page: ParseUtils.parseInt(data['page']) ?? requestedPage,
      limit: ParseUtils.parseInt(data['limit']) ?? _orderLimit,
      totalPages: ParseUtils.parseInt(data['totalPages']) ?? 1,
    );
  }

  /// Replaces the active query. [startDate] is inclusive; [endDate] is exclusive.
  /// Bounds are stored in UTC. Omitting them clears the date filter.
  Future<void> loadOrders({
    String? order,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final generation = ++_queryGeneration;
    _page = 1;
    _order = order == 'asc' ? 'asc' : 'desc';
    _startDate = startDate?.toUtc();
    _endDate = endDate?.toUtc();
    state = CustomAsyncValue.loading();
    try {
      final response = await ref
          .read(dioProvider)
          .get("/api/order/list", queryParameters: _queryParameters(1));
      if (generation != _queryGeneration) return;
      state = CustomAsyncValue.done(_parsePage(response.data, 1));
    } catch (e) {
      if (generation != _queryGeneration) return;
      log('Error loading orders: $e');
      state = CustomAsyncValue.error(
        e is DioException ? getDioExceptionMessage(e) : '無法載入訂單，請稍後再試',
      );
    }
  }

  /// Returns a readable error on failure, retaining the last successful page.
  Future<String?> fetchMoreOrders() async {
    if (!state.isDone || _page >= (state.data?.totalPages ?? double.infinity)) {
      return null;
    }
    final generation = _queryGeneration;
    final nextPage = _page + 1;
    final previousData = state.data!;
    try {
      state = CustomAsyncValue.fetching(previousData);
      final response = await ref
          .read(dioProvider)
          .get("/api/order/list", queryParameters: _queryParameters(nextPage));
      if (generation != _queryGeneration) return null;
      final page = _parsePage(response.data, nextPage);
      _page = nextPage;
      state = CustomAsyncValue.done(
        page.copyWith(orders: [...previousData.orders, ...page.orders]),
      );
      return null;
    } catch (e) {
      if (generation != _queryGeneration) return null;
      log('Error loading orders: $e');
      state = CustomAsyncValue.done(previousData);
      return e is DioException ? getDioExceptionMessage(e) : '無法載入更多訂單，請稍後再試';
    }
  }

  Future<Result<Order>> createOrder({
    required String idempotencyKey,
    required double subTotal,
    required double totalAmount,
    required double discountCoin,
    required double shippingCost,
    required double shippingCostDeduction,
    required double transactionFee,
    double? transactionFeeRateAtSale,
    String? userLevelAtSale,
    int? userMaxDiscountAtSale,
    required List<CartItem> cartItems,
    required Map<String, dynamic> shippingInfo,
    OrderPayment? orderPayment,
  }) async {
    try {
      final response = await ref
          .read(dioProvider)
          .post(
            "/api/order",
            data: {
              "idempotencyKey": idempotencyKey,
              "subTotal": subTotal,
              "totalAmount": totalAmount,
              "discountCoin": discountCoin,
              "shippingCost": shippingCost,
              "shippingCostDeduction": shippingCostDeduction,
              "transactionFee": transactionFee,
              "transactionFeeRateAtSale": transactionFeeRateAtSale,
              "userLevelAtSale": userLevelAtSale,
              "userMaxDiscountAtSale": userMaxDiscountAtSale,
              "items": cartItems.map((item) {
                return {
                  'productId': item.productId,
                  'productVariantId': item.productVariantId,
                  'quantity': item.quantity,
                  'unitPriceAtSale': item.unitPrice,
                  'productNameAtSale': item.product.name,
                  'variantNameAtSale': item.variant?.name,
                  'variantSkuAtSale': item.variant?.sku,
                  'variantOptionValuesAtSale': item.variant?.optionValues,
                };
              }).toList(),
              "shippingInfo": shippingInfo,
              "orderPayment": orderPayment?.wireValue,
            },
          );

      if (response.data['success'] != true) {
        throw Exception('無法新增訂單');
      }
      return Result.success(Order.fromApiResponseMap(response.data['data']));
    } on DioException catch (e) {
      log(
        '[DioException] Failed to create order: ${getDioExceptionMessage(e)}',
      );
      if (e.response?.statusCode == 400) {
        await Future.wait([
          ref.read(cartProvider.notifier).loadCartItems(keepPreviousData: true),
          ref.read(productNotifierProvider.notifier).refreshProducts(),
        ]);
        final data = e.response?.data;
        if (data is Map && data['error'] is List) {
          return Result.failure(jsonEncode(data));
        }
        final message = data is Map
            ? ParseUtils.parseString(data['message'])
            : data is String
            ? data
            : null;
        return Result.failure(
          message?.trim().isNotEmpty == true
              ? message!.trim()
              : '無法建立訂單，請確認商品、規格及結帳資料後再試。',
        );
      }
      return Result.failure(getDioExceptionMessage(e));
    } catch (e) {
      log('[Exception] Failed to create order: $e');
      return Result.failure('Error: $e');
    }
  }

  Future<Result<Order>> getOrder({required String orderId}) async {
    try {
      final response = await ref.read(dioProvider).get("/api/order/$orderId");

      if (response.data['success'] != true) {
        throw Exception('Failed to get response data');
      }
      return Result.success(Order.fromApiResponseMap(response.data['data']));
    } catch (e) {
      log('Failed to get order: $e');
      return Result.failure('Error: $e');
    }
  }

  Future<Result<Order>> updateOrder({
    required String orderId,
    required OrderStatus status,
    dynamic metadata,
  }) async {
    try {
      final response = await ref
          .read(dioProvider)
          .put(
            "/api/order/$orderId",
            data: {"status": status.wireValue, "metadata": metadata},
          );

      if (response.data['success'] != true) {
        throw Exception('Failed to get updated data');
      }
      return Result.success(Order.fromApiResponseMap(response.data['data']));
    } catch (e) {
      log('Failed to update order: $e');
      return Result.failure('Error: $e');
    }
  }

  Future<Result> createRefund({
    required String orderItemId,
    required String accountId,
    required int quantity,
    required String reason,
    String? note,
  }) async {
    try {
      final response = await ref
          .read(dioProvider)
          .post(
            "/api/refund",
            data: {
              "orderItemId": orderItemId,
              "accountId": accountId,
              "quantity": quantity,
              "reason": reason,
              "note": note,
            },
          );

      if (response.data['success'] != true) {
        throw Exception('Failed to create refund');
      }
      return Result.success();
    } catch (e) {
      log('Failed to create refund: $e');
      return Result.failure('Error: $e');
    }
  }
}
