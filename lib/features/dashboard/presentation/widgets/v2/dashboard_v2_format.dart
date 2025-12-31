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
}


