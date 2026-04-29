// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$totalProductValueHash() => r'a474e99a6b57ced0cc4a50d3ad529c73199d90db';

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
String _$productNotifierHash() => r'b3fd222af1b03d794d2b515619a0f0c62d290d32';

/// See also [ProductNotifier].
@ProviderFor(ProductNotifier)
final productNotifierProvider =
    AutoDisposeNotifierProvider<
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

typedef _$ProductNotifier =
    AutoDisposeNotifier<CustomAsyncValue<ProductPagination>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
