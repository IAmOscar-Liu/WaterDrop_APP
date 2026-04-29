import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ApiCallManager {
  // A function to check if you should make the API call.
  // 'apiKey' is a unique identifier for your API endpoint.
  static Future<bool> isOutdated(String apiKey) async {
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

    final DateTime now = DateTime.now();

    // 3. Compare the dates (ignoring the time)
    // We use the 'intl' package to format both dates to 'yyyy-MM-dd'
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final String lastCallDate = formatter.format(lastCallTime);
    final String currentDate = formatter.format(now);
    print("[$apiKey] lastCallDate: $lastCallDate, currentDate: $currentDate");

    // If the dates are different, you can make the call
    return lastCallDate != currentDate;
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
