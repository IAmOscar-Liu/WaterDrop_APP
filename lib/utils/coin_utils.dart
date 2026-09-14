class CoinUtils {
  static const int unitsPerCoin = 100;
  static const int unitsPerTwd = 1000;

  const CoinUtils._();

  static int toCoinUnits(num coins) =>
      (coins.toDouble() * unitsPerCoin).round();

  static double fromCoinUnits(int units) => units / unitsPerCoin;

  static double normalize(num coins) => fromCoinUnits(toCoinUnits(coins));

  static double toTwd(num coins) => toCoinUnits(coins) / unitsPerTwd;

  static int? tryParseCoinUnits(String value) {
    final normalized = value.trim();
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(normalized)) return null;
    final coins = double.tryParse(normalized);
    return coins == null ? null : toCoinUnits(coins);
  }
}
