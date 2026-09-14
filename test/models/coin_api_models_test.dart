import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/models/treasure_box.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('order parses decimal discounts and coinInfo', () {
    final order = Order.fromApiResponseMap({
      'discountCoin': 52.25,
      'coinInfo': {'2026-07': 2, '2026-08': 50.25},
      'items': [],
      'deliveries': [],
    });

    expect(order.discountCoin, 52.25);
    expect(order.coinInfo, {'2026-07': 2.0, '2026-08': 50.25});
  });

  test('refund parses authoritative cash and coin fields', () {
    final refund = RefundItem.fromApiResponseMap({
      'cashRefundAmount': 95,
      'cashRemainderCoins': 2.5,
      'coins': 7.5,
      'returnableCoins': 10,
    });

    expect(refund.cashRefundAmount, 95);
    expect(refund.cashRemainderCoins, 2.5);
    expect(refund.coins, 7.5);
    expect(refund.returnableCoins, 10);
  });

  test('zero-reward treasure box remains claimable', () {
    final box = TreasureBox.fromMap({
      'accountingStatus': 'zero_reward',
      'coinsAwarded': 0,
      'claimDeadlineAt': '2026-09-13T16:00:00.000Z',
      'isActive': true,
    });

    expect(box.accountingStatus, TreasureBoxAccountingStatus.zeroReward);
    expect(box.coinsAwarded, 0);
    expect(box.claimDeadlineAt, isNotNull);
    expect(box.isActive, isTrue);
    expect(box.isClaimable, isTrue);
  });

  test('inactive zero-reward treasure box is not claimable', () {
    final box = TreasureBox.fromMap({
      'accountingStatus': 'zero_reward',
      'isOpened': false,
      'isActive': false,
    });

    expect(box.isClaimable, isFalse);
  });
}
