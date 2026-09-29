import 'dart:io';

import 'package:flutter_ad_ecommerce/features/order/order_date_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Recent week ends now and spans seven days across year rollover', () {
    final now = DateTime.utc(2026, 1, 1, 13, 24, 35);
    final range = recentWeekOrderRange(now);
    expect(range.startUtc, DateTime.utc(2025, 12, 25, 13, 24, 35));
    expect(range.endExclusiveUtc, now);
  });

  test('Recent month means thirty days, including in leap years', () {
    final now = DateTime.utc(2024, 3, 15, 13, 24, 35);
    final range = recentMonthOrderRange(now);
    expect(range.startUtc, DateTime.utc(2024, 2, 14, 13, 24, 35));
    expect(range.endExclusiveUtc, now);
  });

  test(
    'Recent presets preserve exact durations across timezone transitions',
    () {
      for (final now in [
        DateTime(2026, 3, 10, 12),
        DateTime(2026, 11, 3, 12),
      ]) {
        final week = recentWeekOrderRange(now);
        final month = recentMonthOrderRange(now);
        expect(week.endExclusiveUtc, now.toUtc());
        expect(month.endExclusiveUtc, now.toUtc());
        expect(week.endExclusiveUtc!.difference(week.startUtc!).inHours, 168);
        expect(month.endExclusiveUtc!.difference(month.startUtc!).inHours, 720);
      }
    },
  );

  test('Inclusive single day becomes midnight to next midnight in UTC', () {
    final range = OrderDateRange(
      start: DateTime(2026, 12, 31),
      end: DateTime(2026, 12, 31),
    );
    expect(range.startUtc, DateTime(2026, 12, 31).toUtc());
    expect(range.endExclusiveUtc, DateTime(2027, 1, 1).toUtc());
    expect(range.startUtc!.isUtc, isTrue);
    expect(range.endExclusiveUtc!.isUtc, isTrue);
  });

  test(
    'Taipei selection matches the backend example',
    () {
      final range = OrderDateRange(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 29),
      );
      expect(range.startUtc, DateTime.utc(2026, 8, 31, 16));
      expect(range.endExclusiveUtc, DateTime.utc(2026, 9, 29, 16));
    },
    skip: Platform.environment['TZ'] != 'Asia/Taipei',
  );

  test(
    'DST days end at next local midnight after 23 or 25 hours',
    () {
      for (final example in [(3, 8, 23), (11, 1, 25)]) {
        final day = DateTime(2026, example.$1, example.$2);
        final range = OrderDateRange(start: day, end: day);
        expect(
          range.endExclusiveUtc!.difference(range.startUtc!).inHours,
          example.$3,
        );
        expect(range.endExclusiveUtc!.toLocal().hour, 0);
      }
    },
    skip: Platform.environment['TZ'] != 'America/New_York',
  );
}
