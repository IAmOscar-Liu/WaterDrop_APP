// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'treasure_box_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$claimableTreasureBoxCountHash() =>
    r'b7adeedb4613d6c35533c2fef57ccc20587ed918';

/// Computed provider that calculates the number of claimable treasure boxes
///
/// Copied from [claimableTreasureBoxCount].
@ProviderFor(claimableTreasureBoxCount)
final claimableTreasureBoxCountProvider = AutoDisposeProvider<int>.internal(
  claimableTreasureBoxCount,
  name: r'claimableTreasureBoxCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$claimableTreasureBoxCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ClaimableTreasureBoxCountRef = AutoDisposeProviderRef<int>;
String _$totalOpenedBoxAmountHash() =>
    r'1c0581d45d261bcee01ddfcc7619f4f5cf155d48';

/// Computed provider that calculates the total amount of all opened treasure boxes
///
/// Copied from [totalOpenedBoxAmount].
@ProviderFor(totalOpenedBoxAmount)
final totalOpenedBoxAmountProvider = AutoDisposeProvider<double>.internal(
  totalOpenedBoxAmount,
  name: r'totalOpenedBoxAmountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$totalOpenedBoxAmountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TotalOpenedBoxAmountRef = AutoDisposeProviderRef<double>;
String _$emptyTreasureBoxCountHash() =>
    r'fc35790135d83531132550508dfe1fef25155882';

/// Computed provider that calculates the number of empty treasure boxes
///
/// Copied from [emptyTreasureBoxCount].
@ProviderFor(emptyTreasureBoxCount)
final emptyTreasureBoxCountProvider = AutoDisposeProvider<int>.internal(
  emptyTreasureBoxCount,
  name: r'emptyTreasureBoxCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$emptyTreasureBoxCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EmptyTreasureBoxCountRef = AutoDisposeProviderRef<int>;
String _$treasureBoxNotifierHash() =>
    r'88ef01da6994c10e41cf6e4731eaacaf2e4d15b8';

/// See also [TreasureBoxNotifier].
@ProviderFor(TreasureBoxNotifier)
final treasureBoxNotifierProvider =
    AutoDisposeNotifierProvider<
      TreasureBoxNotifier,
      CustomAsyncValue<List<TreasureBox>>
    >.internal(
      TreasureBoxNotifier.new,
      name: r'treasureBoxNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$treasureBoxNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TreasureBoxNotifier =
    AutoDisposeNotifier<CustomAsyncValue<List<TreasureBox>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
