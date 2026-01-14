import 'package:shared_preferences/shared_preferences.dart';

/// Service untuk manage user preferences (app settings)
/// Stored locally using SharedPreferences
class UserPreferencesService {
  static const String _keyClaimGracePeriodDays = 'claim_grace_period_days';

  /// Get claim grace period days (default: 7)
  Future<int> getClaimGracePeriodDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyClaimGracePeriodDays) ?? 7; // Default 7 days
  }

  /// Set claim grace period days
  Future<void> setClaimGracePeriodDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyClaimGracePeriodDays, days);
  }

  /// Reset to default (7 days)
  Future<void> resetClaimGracePeriodDays() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyClaimGracePeriodDays);
  }
}
