import 'package:intl/intl.dart';

class DashboardV2Format {
  static String currency(num value) {
    return NumberFormat.currency(
      locale: 'ms_MY',
      symbol: 'RM ',
      decimalDigits: 0,
    ).format(value);
  }

  static String currency2(num value) {
    return NumberFormat.currency(
      locale: 'ms_MY',
      symbol: 'RM ',
      decimalDigits: 2,
    ).format(value);
  }

  static String units(num value) {
    // SME-friendly: show whole numbers when possible.
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  /// Compact currency format for charts (e.g., RM 1.2K, RM 50K)
  static String currencyCompact(num value) {
    if (value.abs() >= 1000000) {
      return 'RM ${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value.abs() >= 1000) {
      return 'RM ${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return 'RM ${value.toInt()}';
    }
  }
}


