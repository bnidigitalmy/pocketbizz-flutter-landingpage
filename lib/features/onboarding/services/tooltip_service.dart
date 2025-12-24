import 'package:shared_preferences/shared_preferences.dart';

/// Service untuk manage contextual tooltip status
class TooltipService {
  static const String _prefix = 'tooltip_seen_';

  /// Check kalau tooltip dah ditunjukkan untuk module tertentu
  Future<bool> hasSeenTooltip(String moduleKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$moduleKey') ?? false;
  }

  /// Mark tooltip sebagai seen untuk module tertentu
  Future<void> markTooltipSeen(String moduleKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$moduleKey', true);
  }

  /// Reset semua tooltips (untuk testing)
  Future<void> resetAllTooltips() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Reset specific tooltip (untuk testing)
  Future<void> resetTooltip(String moduleKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$moduleKey');
  }
}

/// Module keys untuk tooltip tracking
class TooltipKeys {
  static const String dashboard = 'dashboard';
  static const String sales = 'sales';
  static const String expenses = 'expenses';
  static const String inventory = 'inventory';
  static const String reports = 'reports';
  static const String products = 'products';
  static const String bookings = 'bookings';
  static const String vendors = 'vendors';
  static const String claims = 'claims';
  static const String suppliers = 'suppliers';
  static const String purchaseOrders = 'purchase_orders';
  static const String shoppingList = 'shopping_list';
  static const String production = 'production';
  static const String recipes = 'recipes';
  static const String planner = 'planner';
  static const String deliveries = 'deliveries';
}
