// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'advertisement_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$completedAdvertisementsHash() =>
    r'3cb08953509c02e0f4739e05f866bfff54924d36';

/// Computed provider that returns advertisements filtered by completion status
///
/// Copied from [completedAdvertisements].
@ProviderFor(completedAdvertisements)
final completedAdvertisementsProvider =
    AutoDisposeProvider<List<Advertisement>>.internal(
      completedAdvertisements,
      name: r'completedAdvertisementsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$completedAdvertisementsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CompletedAdvertisementsRef =
    AutoDisposeProviderRef<List<Advertisement>>;
String _$pendingAdvertisementsHash() =>
    r'f5a0855ac10caa4e9b59a4a2c92f82f5a6352aaa';

/// Computed provider that returns advertisements that are not completed
///
/// Copied from [pendingAdvertisements].
@ProviderFor(pendingAdvertisements)
final pendingAdvertisementsProvider =
    AutoDisposeProvider<List<Advertisement>>.internal(
      pendingAdvertisements,
      name: r'pendingAdvertisementsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$pendingAdvertisementsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PendingAdvertisementsRef = AutoDisposeProviderRef<List<Advertisement>>;
String _$totalAdvertisementsValueHash() =>
    r'2aa42cd1f775b2173fc59589635e6821f249ec85';

/// Computed provider that calculates the total value of all advertisements
///
/// Copied from [totalAdvertisementsValue].
@ProviderFor(totalAdvertisementsValue)
final totalAdvertisementsValueProvider = AutoDisposeProvider<double>.internal(
  totalAdvertisementsValue,
  name: r'totalAdvertisementsValueProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$totalAdvertisementsValueHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TotalAdvertisementsValueRef = AutoDisposeProviderRef<double>;
String _$advertisementNotifierHash() =>
    r'fe5e1b359e47a6e695447317e1d97521ebd71bb8';

/// See also [AdvertisementNotifier].
@ProviderFor(AdvertisementNotifier)
final advertisementNotifierProvider =
    AutoDisposeNotifierProvider<
      AdvertisementNotifier,
      CustomAsyncValue<List<Advertisement>>
    >.internal(
      AdvertisementNotifier.new,
      name: r'advertisementNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$advertisementNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AdvertisementNotifier =
    AutoDisposeNotifier<CustomAsyncValue<List<Advertisement>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
