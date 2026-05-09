import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// This line is crucial for code generation.
// It tells build_runner to generate a part file for this file.
part 'order_provider.g.dart';

final _orderLimit = 10;

@Riverpod(
  keepAlive: true,
) // `keepAlive: true` makes the provider persist across hot restarts
class OrderNotifier extends _$OrderNotifier {
  int _page = 1;
  int _limit = _orderLimit;
  String? _order;

  @override
  CustomAsyncValue<OrderPagination> build() {
    return CustomAsyncValue.initial();
  }

  Future<void> loadOrders({String? order}) async {
    try {
      _page = 1;
      _limit = _orderLimit;
      _order = order;

      state = CustomAsyncValue.loading();
      final response = await ref
          .read(dioProvider)
          .get(
            "/api/order/list",
            queryParameters: {
              "page": _page,
              "limit": _limit,
              "order": _order == "asc" ? "asc" : "desc",
            },
          );

      final data = response.data;
      if (data['success'] != true || data['data']?['orders'] is! List) {
        throw Exception("Failed to get response data");
      }
      final orders = List.generate(data['data']['orders'].length, (index) {
        final map = data['data']['orders'][index];
        return Order.fromApiResponseMap(map);
      });
      state = CustomAsyncValue.done(
        OrderPagination(
          orders: orders,
          total: ParseUtils.parseInt(data['data']['total']) ?? _limit,
          page: ParseUtils.parseInt(data['data']['page']) ?? 1,
          limit: ParseUtils.parseInt(data['data']['limit']) ?? _limit,
          totalPages: ParseUtils.parseInt(data['data']['totalPages']) ?? 1,
        ),
      );
    } on DioException catch (e) {
      log('Error loading orders: $e');
      state = CustomAsyncValue.error(getDioExceptionMessage(e));
    } catch (e) {
      log('Error loading orders: $e');
      state = CustomAsyncValue.error('Error loading orders: $e');
    }
  }

  Future<void> fetchMoreOrders() async {
    if (!state.isDone || _page >= (state.data?.totalPages ?? double.infinity)) {
      return;
    }
    _page++;
    try {
      state = CustomAsyncValue.fetching(state.data);
      final response = await ref
          .read(dioProvider)
          .get(
            "/api/order/list",
            queryParameters: {"page": _page, "limit": _limit, "order": _order},
          );

      final data = response.data;
      if (data['success'] != true || data['data']?['orders'] is! List) {
        throw Exception("Failed to get response data");
      }
      final orders = List.generate(data['data']['orders'].length, (index) {
        final map = data['data']['orders'][index];
        return Order.fromApiResponseMap(map);
      });

      state = CustomAsyncValue.done(
        OrderPagination(
          orders: [...(state.data?.orders ?? []), ...orders],
          total: ParseUtils.parseInt(data['data']['total']) ?? _limit,
          page: ParseUtils.parseInt(data['data']['page']) ?? 1,
          limit: ParseUtils.parseInt(data['data']['limit']) ?? _limit,
          totalPages: ParseUtils.parseInt(data['data']['totalPages']) ?? 1,
        ),
      );
    } catch (e) {
      log('Error loading orders: $e');
      state = state.data != null
          ? CustomAsyncValue.done(state.data!)
          : CustomAsyncValue.error(
              e is DioException
                  ? getDioExceptionMessage(e)
                  : 'Error loading orders: $e',
            );
    }
  }

  Future<Result<Order>> createOrder({
    required double subTotal,
    required double totalAmount,
    required int discountCoin,
    required double shippingCost,
    required double shippingCostDeduction,
    required double transactionFee,
    double? transactionFeeRateAtSale,
    String? userLevelAtSale,
    int? userMaxDiscountAtSale,
    required List<CartItem> cartItems,
    required Map<String, dynamic> shippingInfo,
  }) async {
    try {
      final response = await ref
          .read(dioProvider)
          .post(
            "/api/order",
            data: {
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
                  'quantity': item.quantity,
                  'unitPriceAtSale': item.product.price,
                  'productNameAtSale': item.product.name,
                };
              }).toList(),
              "shippingInfo": shippingInfo,
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
    required String status,
    dynamic metadata,
  }) async {
    try {
      final response = await ref
          .read(dioProvider)
          .put(
            "/api/order/$orderId",
            data: {"status": status, "metadata": metadata},
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
}
