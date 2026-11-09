// lib/cart_provider.dart
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/checkout_validation.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/product_availability.dart';
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
  Future<void> _workTail = Future.value();
  int _pendingWork = 0;
  int _workRevision = 0;
  bool _disposed = false;
  List<CartItem>? _confirmedItems;
  Object? _loadError;
  final _optimisticChanges =
      <Object, List<CartItem> Function(List<CartItem>)>{};

  /// Serializes writes and reads together so an older GET cannot undo a write.
  /// Pending edits are replayed over each confirmed snapshot for immediate UI.
  Future<T> _enqueue<T>(
    Future<T> Function() work, {
    List<CartItem> Function(List<CartItem>)? optimistic,
  }) {
    if (_pendingWork == 0) _confirmedItems = state.data;
    final key = Object();
    _pendingWork++;
    _workRevision++;
    if (optimistic != null) _optimisticChanges[key] = optimistic;
    final future = _workTail.then((_) async {
      try {
        return await work();
      } finally {
        _optimisticChanges.remove(key);
        _pendingWork--;
        _publishCartState();
      }
    });
    // A failed operation must not prevent later queued work from running.
    _workTail = future.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _publishCartState();
    return future;
  }

  void _publishCartState() {
    if (_disposed) return;
    var items = _confirmedItems;
    if (_pendingWork > 0) {
      if (items == null) {
        state = CustomAsyncValue.loading();
        return;
      }
      for (final change in _optimisticChanges.values) {
        items = change(items!);
      }
      state = CustomAsyncValue.processing(items!);
    } else if (_loadError != null) {
      state = CustomAsyncValue.error(_loadError, previousData: items);
    } else {
      state = CustomAsyncValue.done(items ?? []);
    }
  }

  Future<Result<T>> _mutate<T>(
    Future<Result<T>> Function(List<CartItem>) work, {
    List<CartItem> Function(List<CartItem>)? optimistic,
  }) => _enqueue(() async {
    try {
      if (_confirmedItems == null || _loadError != null) {
        await _fetchCartItems();
      }
      if (_confirmedItems == null || _loadError != null) {
        return Result.failure<T>('無法確認購物車狀態，請稍後再試');
      }
      return await work(_confirmedItems!);
    } catch (e) {
      log('Failed to update cart: $e');
      return Result.failure<T>(
        e is DioException ? productMutationErrorMessage(e) : '修改購物車失敗，請稍後再試',
      );
    } finally {
      // Reconcile failures too, including partially completed variant changes.
      await _fetchCartItems();
    }
  }, optimistic: optimistic);

  // The initial state of our cart is an empty list of CartItem.
  @override
  CustomAsyncValue<List<CartItem>> build() {
    ref.onDispose(() => _disposed = true);
    return CustomAsyncValue.initial();
  }

  /// Validate one frozen selection against a single authoritative server snapshot.
  Future<Result<List<CartItem>>> validateCheckoutItems(
    List<CartItem> items,
  ) async {
    if (_pendingWork > 0) return Result.failure('購物車更新中，請稍候再結帳');
    if (items.isEmpty) return Result.failure('請先選擇要結帳的商品');
    if (items.length > 4) return Result.failure('單筆訂單商品種類不能超過4種');
    if (items.any(
      (item) =>
          item.variant == null ||
          !item.variant!.price.isFinite ||
          item.variant!.price < 0,
    )) {
      return Result.failure('無法確認商品價格，請重新整理購物車後再試');
    }
    final selection = List<CartItem>.unmodifiable(items);
    final revision = _workRevision + 1;
    var accountChanged = false;
    // Remember transitions too, including logging out and back into the same account.
    final accountSubscription = ref.listen(
      accountNotifierProvider.select(
        (account) => (account.id, account.oauthId),
      ),
      (_, _) => accountChanged = true,
    );
    bool isCurrent() =>
        !_disposed && !accountChanged && _workRevision == revision;
    const changedMessage = '帳號或購物車內容已變更，請重新確認後再結帳';
    CheckoutValidation? validation;
    try {
      final result = await _enqueue<Result<List<CartItem>>>(() async {
        if (!isCurrent()) return Result.failure(changedMessage);
        try {
          final response = await ref
              .read(dioProvider)
              .post(
                '/api/cart/validate-checkout',
                data: {
                  'items': selection
                      .map(
                        (item) => {
                          'cartItemId': item.id,
                          'productVariantId': item.productVariantId,
                          'quantity': item.quantity,
                          'expectedUnitPrice': item.variant!.price,
                        },
                      )
                      .toList(),
                },
              );
          if (!isCurrent()) return Result.failure(changedMessage);
          validation = CheckoutValidation.fromResponse(
            response.data,
            selection,
          );
          _confirmedItems = validation!.cartItems;
          _loadError = null;
          if (!validation!.canCheckout) {
            return Result.failure(validation!.message);
          }
          return Result.success(validation!.selectedItems);
        } catch (e) {
          log('Failed to validate checkout: $e');
          return Result.failure(
            isCurrent() ? '無法確認購物車狀態，請稍後再試' : changedMessage,
          );
        }
      });
      if (!isCurrent()) return Result.failure(changedMessage);
      final unavailable = validation?.unavailableItems ?? <CartItem>[];
      if (unavailable.isNotEmpty) {
        final cleanup = await _removeUnavailableCheckoutItems(
          unavailable,
          isSessionCurrent: () => !_disposed && !accountChanged,
        );
        return Result.failure('${result.error}\n$cleanup');
      }
      return result;
    } finally {
      accountSubscription.close();
    }
  }

  /// Remove confirmed unavailable selections using the same API as manual removal.
  /// Refresh once after all attempts and only report success if those rows are gone.
  Future<String> _removeUnavailableCheckoutItems(
    List<CartItem> items, {
    required bool Function() isSessionCurrent,
  }) async {
    await _enqueue<void>(() async {
      for (final item in items) {
        if (!isSessionCurrent()) return;
        try {
          await _deleteCartItem(item.productId, item.productVariantId);
        } catch (e) {
          // The final cart snapshot determines success, including after a 404.
          log('Failed to remove unavailable cart item ${item.id}: $e');
        }
      }
      if (isSessionCurrent()) {
        await _fetchCartItems(canApply: isSessionCurrent);
      }
    });
    if (!isSessionCurrent()) return '帳號已變更，請重新確認購物車。';
    if (!state.isDone) {
      return '無法確認購物車更新結果，請重新整理後再試。';
    }
    final remaining = state.data ?? <CartItem>[];
    if (items.any(
      (removed) => remaining.any(
        (item) =>
            item.id == removed.id ||
            _isSameCartLine(item, removed.productId, removed.productVariantId),
      ),
    )) {
      return '部分無法購買的商品尚未移除，請重試或手動移除後再結帳。';
    }
    return '無法購買的商品已從購物車移除，請確認後再結帳。';
  }

  Future<void> _deleteCartItem(
    String productId,
    String productVariantId,
  ) async {
    final response = await ref
        .read(dioProvider)
        .post(
          '/api/cart/item',
          data: {
            'productId': productId,
            'productVariantId': productVariantId,
            'quantity': 0,
          },
        );
    if (response.data is! Map || response.data['success'] != true) {
      throw Exception('Failed to remove cart item');
    }
  }

  Future<void> loadCartItems({bool? keepPreviousData = false}) =>
      _enqueue(_fetchCartItems);

  Future<void> _fetchCartItems({bool Function()? canApply}) async {
    try {
      final response = await ref.read(dioProvider).get("api/cart/list");
      if (_disposed || (canApply != null && !canApply())) return;
      final data = response.data;
      if (data['success'] != true || data['data'] is! List) {
        throw Exception("Failed to get response data");
      }
      _confirmedItems = List.generate(data['data'].length, (index) {
        return CartItem.fromApiResponseMap(data['data'][index]);
      });
      _loadError = null;
    } catch (e) {
      log('Error loading cartItems: $e');
      if (!_disposed && (canApply == null || canApply())) _loadError = e;
    }
  }

  Future<void> _setQuantity(
    String productId,
    String variantId,
    int quantity,
  ) async {
    final response = await ref
        .read(dioProvider)
        .post(
          '/api/cart/item',
          data: {
            'productId': productId,
            'productVariantId': variantId,
            'quantity': quantity,
          },
        );
    if (response.data['success'] != true) throw Exception('Request failed');
  }

  Future<Result<String>> addCartItem(
    String productId, {
    String? productVariantId,
    String? productName,
  }) => _mutate((items) async {
    final target = items.firstWhereOrNull(
      (item) =>
          item.productId == productId &&
          (productVariantId == null ||
              item.productVariantId == productVariantId),
    );
    final variantId = productVariantId ?? target?.productVariantId;
    if (variantId == null || variantId.isEmpty) {
      return Result.failure('請選擇商品規格');
    }
    await _setQuantity(productId, variantId, (target?.quantity ?? 0) + 1);
    return Result.success(
      productName != null ? "「$productName」已加入購物車" : "商品已加入購物車",
    );
  });

  Future<Result<bool>> updateItemQuantity(
    String productId, {
    String? productVariantId,
    required int quantity,
  }) {
    if (quantity == 0) {
      return removeItem(productId, productVariantId: productVariantId);
    }
    final target = (state.data ?? <CartItem>[]).firstWhereOrNull(
      (item) =>
          item.productId == productId &&
          (productVariantId == null ||
              item.productVariantId == productVariantId),
    );
    if (target == null) return Future.value(Result.failure('商品已不在購物車中'));
    return updateCartItem(
      target,
      quantity: quantity,
      productVariantId: target.productVariantId,
    );
  }

  Future<Result<bool>> updateCartItem(
    CartItem cartItem, {
    required int quantity,
    required String productVariantId,
  }) {
    if (quantity < 1) return Future.value(Result.failure('數量最少為1'));
    if (productVariantId.isEmpty) {
      return Future.value(Result.failure('請選擇商品規格'));
    }
    return _mutate(
      (items) async {
        final source = items.firstWhereOrNull((item) => item.id == cartItem.id);
        if (source == null) return Result.failure('商品已不在購物車中');
        if (source.quantity != quantity) {
          await _setQuantity(
            source.productId,
            source.productVariantId,
            quantity,
          );
        }
        if (source.productVariantId != productVariantId) {
          final response = await ref
              .read(dioProvider)
              .put(
                '/api/cart/item/${source.id}/variant',
                data: {'productVariantId': productVariantId},
              );
          if (response.data['success'] != true) {
            throw Exception('Request failed');
          }
        }
        return Result.success(true);
      },
      optimistic: (items) {
        final source = items.firstWhereOrNull((item) => item.id == cartItem.id);
        return source == null
            ? items
            : _optimisticUpdateCartItem(
                items,
                source,
                quantity: quantity,
                productVariantId: productVariantId,
              );
      },
    );
  }

  Future<Result<bool>> toggleCartItem(
    String productId,
    bool checked, {
    String? productVariantId,
  }) => _mutate(
    (items) async {
      final target = items.firstWhereOrNull(
        (item) =>
            item.productId == productId &&
            (productVariantId == null ||
                item.productVariantId == productVariantId),
      );
      if (target == null) return Result.failure('商品已不在購物車中');
      final response = await ref
          .read(dioProvider)
          .put(
            '/api/cart/item/toggle',
            data: {
              'productId': productId,
              'productVariantId': target.productVariantId,
              'checked': checked,
            },
          );
      if (response.data['success'] != true) throw Exception('Request failed');
      return Result.success(true);
    },
    optimistic: (items) => items
        .map(
          (item) =>
              item.productId == productId &&
                  (productVariantId == null ||
                      item.productVariantId == productVariantId)
              ? item.copyWith(checked: checked)
              : item,
        )
        .toList(),
  );

  Future<Result<bool>> removeItem(
    String productId, {
    String? productVariantId,
  }) => _mutate(
    (items) async {
      final target = items.firstWhereOrNull(
        (item) =>
            item.productId == productId &&
            (productVariantId == null ||
                item.productVariantId == productVariantId),
      );
      // Repeated taps on an already removed row are harmless.
      if (target == null) return Result.success(true);
      await _deleteCartItem(productId, target.productVariantId);
      return Result.success(true);
    },
    optimistic: (items) => items
        .where(
          (item) =>
              !(item.productId == productId &&
                  (productVariantId == null ||
                      item.productVariantId == productVariantId)),
        )
        .toList(),
  );

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
