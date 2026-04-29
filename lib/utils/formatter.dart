import 'package:intl/intl.dart';

class Formatter {
  static String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = secs.toString().padLeft(2, '0');

    if (hours > 0) {
      final hoursStr = hours.toString().padLeft(2, '0');
      return '$hoursStr:$minutesStr:$secondsStr';
    } else {
      return '$minutesStr:$secondsStr';
    }
  }

  static String formatDateTime(DateTime value) {
    DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm');
    String formattedDate = formatter.format(value);
    return formattedDate;
  }

  static String formatDateOnly(DateTime value) {
    DateFormat formatter = DateFormat('yyyy-MM-dd');
    String formattedDate = formatter.format(value);
    return formattedDate;
  }
}
