// lib/cart_provider.dart
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_ad_ecommerce/utils/list_utils.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// This line is crucial for code generation.
// It tells build_runner to generate a part file for this file.
part 'cart_provider.g.dart';

@Riverpod(
  keepAlive: true,
) // `keepAlive: true` makes the provider persist across hot restarts
class Cart extends _$Cart {
  // bool _isAddingCartItem = false;
  // bool _isUpdatingItemQuantity = false;

  // The initial state of our cart is an empty list of CartItem.
  @override
  CustomAsyncValue<List<CartItem>> build() {
    return CustomAsyncValue.initial();
  }

  Future<void> loadCartItems({bool? keepPreviousData = false}) async {
    try {
      state = (state.isDone && keepPreviousData == true)
          ? CustomAsyncValue.fetching(state.data)
          : CustomAsyncValue.loading();
      // state = CustomAsyncValue.loading();
      final response = await ref.read(dioProvider).get("api/cart/list");

      final data = response.data;
      if (data['success'] != true || data['data'] is! List) {
        throw Exception("Failed to get response data");
      }
      final cartItems = List.generate(data['data'].length, (index) {
        return CartItem.fromApiResponseMap(data['data'][index]);
      });

      state = CustomAsyncValue.done(cartItems);
    } catch (e) {
      log('Error loading treasureBoxes: $e');
      state = CustomAsyncValue.error('Error loading cartItems: $e');
    }
  }

  /// Adds a product to the cart.
  /// If the product is already in the cart, its quantity is incremented.
  Future<Result<String>> addCartItem(
    String productId, {
    String? productVariantId,
    String? productName,
  }) async {
    if (state.isProcessing || state.isFetching) return Result.success();
    final target = (state.data ?? []).firstWhereOrNull(
      (item) =>
          item.productId == productId &&
          (productVariantId == null ||
              item.productVariantId == productVariantId),
    );
    final targetVariantId = productVariantId ?? target?.productVariantId;
    if (targetVariantId == null || targetVariantId.isEmpty) {
      return Result.failure('請選擇商品規格');
    }

    try {
      state = CustomAsyncValue.processing(state.data ?? []);

      final response = await ref
          .read(dioProvider)
          .post(
            "/api/cart/item",
            data: {
              "productId": productId,
              "productVariantId": targetVariantId,
              "quantity": target == null ? 1 : target.quantity + 1,
            },
          );

      if (response.data['success'] != true) {
        throw Exception('找不到此商品');
      }

      return Result.success(
        productName != null ? "「$productName」已加入購物車" : "商品已加入購物車",
      );
    } on DioException catch (e) {
      log('Failed to add cart item: $e');
      return Result.failure(getDioExceptionMessage(e));
    } catch (e) {
      log('Failed to add cart item: $e');
      return Result.failure('Error: $e');
    } finally {
      state = CustomAsyncValue.done(state.data ?? []);
      loadCartItems(keepPreviousData: true);
    }
  }

  Future<Result<bool>> updateItemQuantity(
    String productId, {
    String? productVariantId,
    required int quantity,
  }) async {
    if (state.isProcessing || state.isFetching || state.data == null) {
      return Result.failure('processing');
    }

    final target = state.data!.firstWhereOrNull(
      (item) =>
          item.productId == productId &&
          (productVariantId == null ||
              item.productVariantId == productVariantId),
    );
    if (target == null) {
      return Result.failure('target not available');
    }
    final targetVariantId = productVariantId ?? target.productVariantId;
    if (targetVariantId.isEmpty) {
      return Result.failure('請選擇商品規格');
    }

    try {
      // state = CustomAsyncValue.processing(state.data!);
      state = CustomAsyncValue.processing(
        state.data!
            .map(
              (item) => _isSameCartLine(item, productId, targetVariantId)
                  ? item.copyWith(quantity: quantity)
                  : item,
            )
            .toList(),
      );

      final response = await ref
          .read(dioProvider)
          .post(
            "/api/cart/item",
            data: {
              "productId": productId,
              "productVariantId": targetVariantId,
              "quantity": quantity,
            },
          );
      if (response.data['success'] != true) {
        throw Exception('Request failed');
      }

      return Result.success(true);
    } catch (e) {
      log('Failed to update item quantity: $e');
      return Result.failure('$e');
    } finally {
      state = CustomAsyncValue.done(state.data!);
      loadCartItems(keepPreviousData: true);
    }
  }

  Future<Result<bool>> updateCartItem(
    CartItem cartItem, {
    required int quantity,
    required String productVariantId,
  }) async {
    if (state.isProcessing || state.isFetching || state.data == null) {
      return Result.failure('processing');
    }
    if (quantity < 1) {
      return Result.failure('數量最少為1');
    }
    if (productVariantId.isEmpty) {
      return Result.failure('請選擇商品規格');
    }

    final currentItems = state.data!;
    final source = currentItems.firstWhereOrNull(
      (item) => item.id == cartItem.id,
    );
    if (source == null) {
      return Result.failure('target not available');
    }

    final isVariantChanged = source.productVariantId != productVariantId;
    final isQuantityChanged = source.quantity != quantity;
    if (!isVariantChanged && !isQuantityChanged) {
      return Result.success(true);
    }

    try {
      state = CustomAsyncValue.processing(
        _optimisticUpdateCartItem(
          currentItems,
          source,
          quantity: quantity,
          productVariantId: productVariantId,
        ),
      );

      if (isQuantityChanged) {
        final quantityResponse = await ref
            .read(dioProvider)
            .post(
              "/api/cart/item",
              data: {
                "productId": source.productId,
                "productVariantId": source.productVariantId,
                "quantity": quantity,
              },
            );
        if (quantityResponse.data['success'] != true) {
          throw Exception('Request failed');
        }
      }

      if (isVariantChanged) {
        final variantResponse = await ref
            .read(dioProvider)
            .put(
              "/api/cart/item/${source.id}/variant",
              data: {"productVariantId": productVariantId},
            );
        if (variantResponse.data['success'] != true) {
          throw Exception('Request failed');
        }
      }

      return Result.success(true);
    } catch (e) {
      log('Failed to update cart item: $e');
      return Result.failure('$e');
    } finally {
      state = CustomAsyncValue.done(state.data!);
      loadCartItems(keepPreviousData: true);
    }
  }

  Future<Result<bool>> toggleCartItem(
    String productId,
    bool checked, {
    String? productVariantId,
  }) async {
    if (state.isProcessing || state.isFetching || state.data == null) {
      return Result.failure('processing');
    }

    final target = state.data!.firstWhereOrNull(
      (item) =>
          item.productId == productId &&
          (productVariantId == null ||
              item.productVariantId == productVariantId),
    );
    if (target == null) {
      return Result.failure('target not available');
    }
    final targetVariantId = productVariantId ?? target.productVariantId;
    if (targetVariantId.isEmpty) {
      return Result.failure('請選擇商品規格');
    }

    try {
      state = CustomAsyncValue.processing(
        state.data!
            .map(
              (item) => _isSameCartLine(item, productId, targetVariantId)
                  ? item.copyWith(checked: checked)
                  : item,
            )
            .toList(),
      );

      final response = await ref
          .read(dioProvider)
          .put(
            "/api/cart/item/toggle",
            data: {
              "productId": productId,
              "productVariantId": targetVariantId,
              "checked": checked,
            },
          );
      if (response.data['success'] != true) {
        throw Exception('Request failed');
      }
      return Result.success(true);
    } catch (e) {
      log('Failed to toggle item: $e');
      return Result.failure('$e');
    } finally {
      state = CustomAsyncValue.done(state.data!);
      loadCartItems(keepPreviousData: true);
    }
  }

  Future<Result<bool>> removeItem(
    String productId, {
    String? productVariantId,
  }) async {
    if (state.isProcessing || state.isFetching || state.data == null) {
      return Result.failure('processing');
    }

    final target = state.data!.firstWhereOrNull(
      (item) =>
          item.productId == productId &&
          (productVariantId == null ||
              item.productVariantId == productVariantId),
    );
    if (target == null) {
      return Result.failure('target not available');
    }
    final targetVariantId = productVariantId ?? target.productVariantId;
    if (targetVariantId.isEmpty) {
      return Result.failure('請選擇商品規格');
    }

    try {
      // state = CustomAsyncValue.processing(state.data!);
      state = CustomAsyncValue.processing(
        state.data!
            .where((item) => !_isSameCartLine(item, productId, targetVariantId))
            .toList(),
      );

      final response = await ref
          .read(dioProvider)
          .post(
            "/api/cart/item",
            data: {
              "productId": productId,
              "productVariantId": targetVariantId,
              "quantity": 0,
            },
          );
      if (response.data['success'] != true) {
        throw Exception('Request failed');
      }

      return Result.success(true);
    } on DioException catch (e) {
      log('Failed to remove item: $e');
      return Result.failure(getDioExceptionMessage(e));
    } catch (e) {
      log('Failed to remove item: $e');
      return Result.failure('$e');
    } finally {
      state = CustomAsyncValue.done(state.data!);
      loadCartItems(keepPreviousData: true);
    }
  }

  Future<Result<bool>> updateItemVariant(
    CartItem cartItem, {
    required String productVariantId,
  }) async {
    return updateCartItem(
      cartItem,
      quantity: cartItem.quantity,
      productVariantId: productVariantId,
    );
  }

  bool _isSameCartLine(
    CartItem item,
    String productId,
    String productVariantId,
  ) {
    return item.productId == productId &&
        item.productVariantId == productVariantId;
  }

  List<CartItem> _optimisticUpdateCartItem(
    List<CartItem> items,
    CartItem source, {
    required int quantity,
    required String productVariantId,
  }) {
    if (source.productVariantId == productVariantId) {
      return items
          .map(
            (item) =>
                item.id == source.id ? item.copyWith(quantity: quantity) : item,
          )
          .toList();
    }

    final target = items.firstWhereOrNull(
      (item) =>
          item.id != source.id &&
          item.productId == source.productId &&
          item.productVariantId == productVariantId,
    );
    if (target == null) {
      final nextVariant = source.product.variants.firstWhereOrNull(
        (variant) => variant.id == productVariantId,
      );
      return items
          .map(
            (item) => item.id == source.id
                ? item.copyWith(
                    quantity: quantity,
                    productVariantId: productVariantId,
                    variant: nextVariant ?? item.variant,
                  )
                : item,
          )
          .toList();
    }

    return items
        .where((item) => item.id != source.id)
        .map(
          (item) => item.id == target.id
              ? item.copyWith(
                  quantity: target.quantity + quantity,
                  checked: target.checked || source.checked,
                )
              : item,
        )
        .toList();
  }

  // /// Clears all items from the cart.
  // void clearCart() {
  //   state = [];
  // }
}

// ----------------------------------------------------
// NEW: Separate providers for derived state
// These can be in the same file or a separate 'cart_selectors.dart' file
// if you prefer. For simplicity, I'll keep them here.

@riverpod // Using @riverpod for simple providers (not Notifier or AsyncNotifier)
int cartTotalItems(CartTotalItemsRef ref) {
  final cartItems = (ref.watch(cartProvider).data ?? [])
      .where((item) => item.checked)
      .toList(); // Watch the main cart state
  return cartItems.length;
}

@riverpod // Using @riverpod for simple providers (not Notifier or AsyncNotifier)
int cartTotalQuantity(CartTotalQuantityRef ref) {
  final cartItems = (ref.watch(cartProvider).data ?? [])
      .where((item) => item.checked)
      .toList(); // Watch the main cart state
  return cartItems.fold(0, (sum, item) => sum + item.quantity);
}

@riverpod
double cartTotalPrice(CartTotalPriceRef ref) {
  final cartItems = (ref.watch(cartProvider).data ?? [])
      .where((item) => item.checked)
      .toList(); // Watch the main cart state
  return cartItems.fold(0.0, (sum, item) => sum + item.lineTotal);
}
