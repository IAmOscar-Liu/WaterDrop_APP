// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$totalProductValueHash() => r'551ecf74d9c1797bb2bb6c8122b26a23ddd0da7c';

/// Computed provider that calculates the total value of all products
///
/// Copied from [totalProductValue].
@ProviderFor(totalProductValue)
final totalProductValueProvider = AutoDisposeProvider<double>.internal(
  totalProductValue,
  name: r'totalProductValueProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$totalProductValueHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TotalProductValueRef = AutoDisposeProviderRef<double>;
String _$productNotifierHash() => r'cc39fbafcc81de93d02e03488db93c5a3edb97e8';

/// See also [ProductNotifier].
@ProviderFor(ProductNotifier)
final productNotifierProvider =
    NotifierProvider<
      ProductNotifier,
      CustomAsyncValue<ProductPagination>
    >.internal(
      ProductNotifier.new,
      name: r'productNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$productNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ProductNotifier = Notifier<CustomAsyncValue<ProductPagination>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
