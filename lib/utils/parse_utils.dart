class ParseUtils {
  static String? parseString(dynamic value) {
    return value?.toString();
  }

  static int? parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? parseDouble(dynamic value) {
    if (value is double) return value;
    return double.tryParse(value.toString());
  }

  static DateTime? parseDateTime(dynamic value, {bool? unix = false}) {
    if (value == null) return null;
    final result = DateTime.tryParse(value.toString());
    if (result != null) return result.toLocal();

    int? timestamp = value is int ? value : int.tryParse(value.toString());
    if (timestamp == null) return null;
    if (unix == true) timestamp *= 1000;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
}
