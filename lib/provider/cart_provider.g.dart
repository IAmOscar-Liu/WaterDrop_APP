// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$cartTotalItemsHash() => r'6ddf32c6ef0ee7b239cb4e967f3e13c9b61273e5';

/// See also [cartTotalItems].
@ProviderFor(cartTotalItems)
final cartTotalItemsProvider = AutoDisposeProvider<int>.internal(
  cartTotalItems,
  name: r'cartTotalItemsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cartTotalItemsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CartTotalItemsRef = AutoDisposeProviderRef<int>;
String _$cartTotalQuantityHash() => r'13a9b029b5811683a503f1126372a140210d0728';

/// See also [cartTotalQuantity].
@ProviderFor(cartTotalQuantity)
final cartTotalQuantityProvider = AutoDisposeProvider<int>.internal(
  cartTotalQuantity,
  name: r'cartTotalQuantityProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cartTotalQuantityHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CartTotalQuantityRef = AutoDisposeProviderRef<int>;
String _$cartTotalPriceHash() => r'dda2af5808f13096f371f89ce4ccd9ffd1201b0a';

/// See also [cartTotalPrice].
@ProviderFor(cartTotalPrice)
final cartTotalPriceProvider = AutoDisposeProvider<double>.internal(
  cartTotalPrice,
  name: r'cartTotalPriceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cartTotalPriceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CartTotalPriceRef = AutoDisposeProviderRef<double>;
String _$cartHash() => r'63ff4d3fe6afcb5f029fb3dc65bc9fae6ef4d568';

/// See also [Cart].
@ProviderFor(Cart)
final cartProvider =
    NotifierProvider<Cart, CustomAsyncValue<List<CartItem>>>.internal(
      Cart.new,
      name: r'cartProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$cartHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$Cart = Notifier<CustomAsyncValue<List<CartItem>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
