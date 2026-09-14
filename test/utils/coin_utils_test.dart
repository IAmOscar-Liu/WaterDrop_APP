import 'package:flutter_ad_ecommerce/utils/coin_utils.dart';
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoinUtils', () {
    test('stores coin values as exact hundredths', () {
      expect(CoinUtils.toCoinUnits(7.5), 750);
      expect(CoinUtils.toCoinUnits(52.25), 5225);
      expect(CoinUtils.fromCoinUnits(5225), 52.25);
    });

    test('converts coins to TWD without whole-coin rounding', () {
      expect(CoinUtils.toTwd(4.25), closeTo(0.425, 0.000001));
    });

    test('accepts no more than two decimal places', () {
      expect(CoinUtils.tryParseCoinUnits('52.25'), 5225);
      expect(CoinUtils.tryParseCoinUnits('7.5'), 750);
      expect(CoinUtils.tryParseCoinUnits('1.234'), isNull);
    });

    test('hides unnecessary trailing zeroes', () {
      expect(15.formatCoinValue(), '15');
      expect(7.5.formatCoinValue(), '7.5');
      expect(52.25.formatCoinValue(), '52.25');
    });
  });
}
