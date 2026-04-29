// number_formatter_extension.dart
import 'package:intl/intl.dart';

extension NumberFormatterExtension on num {
  /// Formats a number with a thousands separator (comma).
  String formatWithCommas({int? decimals = 0}) {
    String pattern = '#,##0';
    if (decimals != null && decimals > 0) {
      pattern += '.${'0' * decimals}';
    }
    final formatter = NumberFormat(pattern);
    return formatter.format(this);
  }

  String toDollarsString({String? prefix}) {
    // Default to 0 decimals for dollar strings unless specified otherwise.
    return "${prefix ?? ""}\$ ${formatWithCommas(decimals: 0)}";
  }
}
