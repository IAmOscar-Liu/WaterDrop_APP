import 'package:shared_preferences/shared_preferences.dart';

class ApiCallManager {
  static const int dailyRefreshHour = 0;
  static const int dailyRefreshMinute = 2;

  // A function to check if you should make the API call.
  // 'apiKey' is a unique identifier for your API endpoint.
  static Future<bool> isOutdated(String apiKey, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Get the last saved timestamp string
    final String? lastCallString = prefs.getString(apiKey);

    // If no record exists, you can make the call
    if (lastCallString == null) {
      return true;
    }

    // 2. Parse the stored string into a DateTime object
    final DateTime? lastCallTime = DateTime.tryParse(lastCallString);

    if (lastCallTime == null) {
      return true;
    }

    final currentTime = (now ?? DateTime.now()).toLocal();
    final latestRefresh = latestDailyRefreshAt(currentTime);
    final outdated = lastCallTime.toLocal().isBefore(latestRefresh);
    print(
      '[$apiKey] lastCallTime: $lastCallTime, '
      'latestRefresh: $latestRefresh',
    );

    return outdated;
  }

  /// Returns the most recent local daily refresh boundary (00:02).
  static DateTime latestDailyRefreshAt(DateTime now) {
    final localNow = now.toLocal();
    final todayRefresh = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
      dailyRefreshHour,
      dailyRefreshMinute,
    );
    if (!localNow.isBefore(todayRefresh)) return todayRefresh;

    return DateTime(
      localNow.year,
      localNow.month,
      localNow.day - 1,
      dailyRefreshHour,
      dailyRefreshMinute,
    );
  }

  /// Returns the next local 00:02 boundary for scheduling an in-app refresh.
  static DateTime nextDailyRefreshAt(DateTime now) {
    final localNow = now.toLocal();
    final todayRefresh = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
      dailyRefreshHour,
      dailyRefreshMinute,
    );
    if (localNow.isBefore(todayRefresh)) return todayRefresh;

    return DateTime(
      localNow.year,
      localNow.month,
      localNow.day + 1,
      dailyRefreshHour,
      dailyRefreshMinute,
    );
  }

  static Future<bool> isOlderThan(String apiKey, Duration maxAge) async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastCallString = prefs.getString(apiKey);

    if (lastCallString == null) {
      return true;
    }

    final DateTime? lastCallTime = DateTime.tryParse(lastCallString);
    if (lastCallTime == null) {
      return true;
    }

    return DateTime.now().difference(lastCallTime) > maxAge;
  }

  // A function to update the timestamp after a successful call.
  static Future<void> updateApiCallTimestamp(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();

    // Store the current time as an ISO 8601 string.
    final value = DateTime.now().toIso8601String();
    await prefs.setString(apiKey, value);
    print('Updated [$apiKey] -> $value');
  }
}
