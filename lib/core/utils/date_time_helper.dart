import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

/// DateTime Helper for User's Local Timezone
/// For Flutter Web: Uses browser's local time directly (DateTime.now())
/// This automatically uses the user's device/browser timezone
class DateTimeHelper {
  static bool _initialized = false;

  /// Initialize (for compatibility - doesn't need complex setup for web)
  static void initialize() {
    if (!_initialized) {
      _initialized = true;
      debugPrint('DateTimeHelper: Initialized for ${kIsWeb ? "Web" : "Mobile"}');
      debugPrint('DateTimeHelper: Current local time: ${DateTime.now()}');
      debugPrint('DateTimeHelper: Timezone offset: ${DateTime.now().timeZoneOffset}');
    }
  }
  
  /// Get timezone offset in hours (e.g., +8 for Malaysia)
  static int get timezoneOffset {
    return DateTime.now().timeZoneOffset.inHours;
  }
  
  /// Get timezone name/offset string
  static String get timezoneName {
    final offset = timezoneOffset;
    final sign = offset >= 0 ? '+' : '';
    return 'GMT$sign$offset';
  }

  /// Convert UTC DateTime to user's local timezone
  /// For web, DateTime.now() already uses local time
  static DateTime toLocalTime(DateTime dateTime) {
    // If already local (not UTC), return as is
    if (!dateTime.isUtc) {
      return dateTime;
    }
    // Convert UTC to local
    return dateTime.toLocal();
  }

  /// Format DateTime to user's local timezone with date only
  static String formatDate(DateTime dateTime, {String pattern = 'dd MMM yyyy'}) {
    final localTime = toLocalTime(dateTime);
    return DateFormat(pattern, 'ms').format(localTime);
  }

  /// Format DateTime to user's local timezone with date and time
  static String formatDateTime(DateTime dateTime, {String pattern = 'dd MMM yyyy, hh:mm a'}) {
    final localTime = toLocalTime(dateTime);
    return DateFormat(pattern, 'ms').format(localTime);
  }

  /// Format DateTime to user's local timezone with time only
  static String formatTime(DateTime dateTime, {String pattern = 'hh:mm a'}) {
    final localTime = toLocalTime(dateTime);
    return DateFormat(pattern, 'ms').format(localTime);
  }

  /// Get current time in user's local timezone
  /// DateTime.now() automatically uses browser/device local time
  static DateTime now() {
    return DateTime.now();
  }
  
  /// Get today's date at midnight in user's timezone
  static DateTime today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }
  
  /// Check if a DateTime is today in user's timezone
  static bool isToday(DateTime dateTime) {
    final todayDate = today();
    final localDate = toLocalTime(dateTime);
    return localDate.year == todayDate.year &&
           localDate.month == todayDate.month &&
           localDate.day == todayDate.day;
  }
  
  /// Get greeting based on current hour in user's timezone
  static String getGreeting() {
    final hour = now().hour;
    debugPrint('DateTimeHelper.getGreeting: Current hour = $hour');
    if (hour < 12) {
      return 'Selamat Pagi';
    } else if (hour < 18) {
      return 'Selamat Petang';
    } else {
      return 'Selamat Malam';
    }
  }
  
  /// Get current hour (for debugging)
  static int getCurrentHour() {
    return now().hour;
  }
}
