import 'package:shared_preferences/shared_preferences.dart';

/// Service untuk manage onboarding state dan setup progress
class OnboardingService {
  // SharedPreferences keys
  static const String _hasSeenOnboarding = 'has_seen_onboarding';
  static const String _onboardingCompletedAt = 'onboarding_completed_at';
  static const String _setupDismissed = 'setup_widget_dismissed';
  static const String _setupDismissedAt = 'setup_widget_dismissed_at';
  
  // Setup progress keys
  static const String _stockAdded = 'setup_stock_added';
  static const String _stockCount = 'setup_stock_count';
  static const String _productCreated = 'setup_product_created';
  static const String _productionRecorded = 'setup_production_recorded';
  static const String _saleRecorded = 'setup_sale_recorded';
  static const String _profileCompleted = 'setup_profile_completed';
  static const String _deliveryRecorded = 'setup_delivery_recorded';

  /// Check if should show onboarding (first time user)
  Future<bool> shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_hasSeenOnboarding) ?? false);
  }

  /// Mark onboarding as complete
  Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboarding, true);
    await prefs.setString(_onboardingCompletedAt, DateTime.now().toIso8601String());
  }

  /// Skip onboarding (user chose to explore first)
  Future<void> skipOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboarding, true);
    await prefs.setString(_onboardingCompletedAt, DateTime.now().toIso8601String());
  }

  /// Reset onboarding (for re-show from settings)
  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboarding, false);
    await prefs.remove(_onboardingCompletedAt);
  }

  // ==================== Setup Progress ====================

  /// Get setup progress as map
  Future<Map<String, dynamic>> getSetupProgress() async {
    final prefs = await SharedPreferences.getInstance();
    
    final stockCount = prefs.getInt(_stockCount) ?? 0;
    final stockAdded = stockCount >= 3; // Need minimum 3 items
    
    return {
      'stock_added': stockAdded,
      'stock_count': stockCount,
      'product_created': prefs.getBool(_productCreated) ?? false,
      'production_recorded': prefs.getBool(_productionRecorded) ?? false,
      'sale_recorded': prefs.getBool(_saleRecorded) ?? false,
      'profile_completed': prefs.getBool(_profileCompleted) ?? false,
      'delivery_recorded': prefs.getBool(_deliveryRecorded) ?? false,
    };
  }

  /// Check if all required setup tasks are complete
  Future<bool> isSetupComplete() async {
    final progress = await getSetupProgress();
    return progress['stock_added'] == true &&
           progress['product_created'] == true &&
           progress['production_recorded'] == true &&
           progress['sale_recorded'] == true;
  }

  /// Calculate setup progress percentage
  Future<int> getSetupProgressPercentage() async {
    final progress = await getSetupProgress();
    int completed = 0;
    int total = 6; // 4 required + 2 optional
    
    if (progress['stock_added'] == true) completed++;
    if (progress['product_created'] == true) completed++;
    if (progress['production_recorded'] == true) completed++;
    if (progress['sale_recorded'] == true) completed++;
    if (progress['profile_completed'] == true) completed++;
    if (progress['delivery_recorded'] == true) completed++;
    
    return ((completed / total) * 100).round();
  }

  /// Update stock progress (increment count)
  Future<void> incrementStockCount() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_stockCount) ?? 0;
    await prefs.setInt(_stockCount, currentCount + 1);
    
    // Mark as added if reached 3
    if (currentCount + 1 >= 3) {
      await prefs.setBool(_stockAdded, true);
    }
  }

  /// Mark product as created
  Future<void> markProductCreated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_productCreated, true);
  }

  /// Mark production as recorded
  Future<void> markProductionRecorded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_productionRecorded, true);
  }

  /// Mark sale as recorded
  Future<void> markSaleRecorded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_saleRecorded, true);
  }

  /// Mark profile as completed
  Future<void> markProfileCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_profileCompleted, true);
  }

  /// Mark delivery as recorded (optional - for consignment users)
  Future<void> markDeliveryRecorded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deliveryRecorded, true);
  }

  // ==================== Setup Widget ====================

  /// Check if setup widget should be shown
  Future<bool> shouldShowSetupWidget() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Don't show if dismissed
    final isDismissed = prefs.getBool(_setupDismissed) ?? false;
    if (isDismissed) {
      // Check if 14 days passed since dismiss - force hide permanently
      final dismissedAtStr = prefs.getString(_setupDismissedAt);
      if (dismissedAtStr != null) {
        final dismissedAt = DateTime.parse(dismissedAtStr);
        final daysSinceDismiss = DateTime.now().difference(dismissedAt).inDays;
        if (daysSinceDismiss >= 14) {
          return false; // Permanently hidden after 14 days
        }
      }
      return false;
    }
    
    // Don't show if setup is complete
    final isComplete = await isSetupComplete();
    if (isComplete) return false;
    
    // Check if 14 days passed since onboarding - auto hide
    final completedAtStr = prefs.getString(_onboardingCompletedAt);
    if (completedAtStr != null) {
      final completedAt = DateTime.parse(completedAtStr);
      final daysSinceOnboarding = DateTime.now().difference(completedAt).inDays;
      if (daysSinceOnboarding >= 14) {
        return false; // Auto-hide after 14 days
      }
    }
    
    return true;
  }

  /// Dismiss setup widget
  Future<void> dismissSetupWidget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupDismissed, true);
    await prefs.setString(_setupDismissedAt, DateTime.now().toIso8601String());
  }

  /// Reset setup widget (to re-show)
  Future<void> resetSetupWidget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupDismissed, false);
    await prefs.remove(_setupDismissedAt);
  }

  /// Reset all setup progress (for testing)
  Future<void> resetAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stockAdded);
    await prefs.remove(_stockCount);
    await prefs.remove(_productCreated);
    await prefs.remove(_productionRecorded);
    await prefs.remove(_saleRecorded);
    await prefs.remove(_profileCompleted);
    await prefs.remove(_deliveryRecorded);
    await prefs.remove(_setupDismissed);
    await prefs.remove(_setupDismissedAt);
  }
}
