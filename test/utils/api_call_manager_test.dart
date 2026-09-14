import 'package:flutter_ad_ecommerce/utils/api_call_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiCallManager daily refresh boundary', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('does not expire the previous-day list before 00:02', () async {
      SharedPreferences.setMockInitialValues({
        'advertisements': DateTime(2026, 9, 11, 23, 55).toIso8601String(),
      });

      expect(
        await ApiCallManager.isOutdated(
          'advertisements',
          now: DateTime(2026, 9, 12, 0, 1),
        ),
        isFalse,
      );
    });

    test('expires the previous-day list at 00:02', () async {
      SharedPreferences.setMockInitialValues({
        'advertisements': DateTime(2026, 9, 11, 23, 55).toIso8601String(),
      });

      expect(
        await ApiCallManager.isOutdated(
          'advertisements',
          now: DateTime(2026, 9, 12, 0, 2),
        ),
        isTrue,
      );
    });

    test('uses the next 00:02 boundary for scheduling', () {
      expect(
        ApiCallManager.nextDailyRefreshAt(DateTime(2026, 9, 11, 23, 55)),
        DateTime(2026, 9, 12, 0, 2),
      );
      expect(
        ApiCallManager.nextDailyRefreshAt(DateTime(2026, 9, 12, 0, 2)),
        DateTime(2026, 9, 13, 0, 2),
      );
    });
  });
}
