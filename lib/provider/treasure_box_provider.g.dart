// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'treasure_box_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$claimableTreasureBoxCountHash() =>
    r'9ad66a32673b57be3c1c31379a01f43daa98bc1e';

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
    r'fd4d734411fcffe3378aee79bc48a7eb66a3f730';

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
    r'4f709ad35b3523f7cd70df6270b9dad7b17e379a';

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
    r'3370b5558963c21047d86b7dac923554465139e9';

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
