import '../../../data/repositories/onboarding_repository_supabase.dart';

/// Service untuk manage onboarding state dan setup progress
/// Uses Supabase database for persistence across devices
class OnboardingService {
  final OnboardingRepositorySupabase _repo = OnboardingRepositorySupabase();

  // Cache progress to avoid multiple DB calls
  Map<String, dynamic>? _cachedProgress;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(seconds: 30);

  /// Get progress with caching
  Future<Map<String, dynamic>> _getProgress({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh && 
        _cachedProgress != null && 
        _cacheTime != null &&
        now.difference(_cacheTime!) < _cacheDuration) {
      return _cachedProgress!;
    }

    _cachedProgress = await _repo.getProgress();
    _cacheTime = now;
    return _cachedProgress!;
  }

  /// Invalidate cache after updates
  void _invalidateCache() {
    _cachedProgress = null;
    _cacheTime = null;
  }

  /// Check if should show onboarding (first time user)
  Future<bool> shouldShowOnboarding() async {
    final progress = await _getProgress();
    return !(progress['has_seen_onboarding'] ?? false);
  }

  /// Mark onboarding as complete
  Future<void> markOnboardingComplete() async {
    await _repo.markOnboardingComplete();
    _invalidateCache();
  }

  /// Skip onboarding (user chose to explore first)
  Future<void> skipOnboarding() async {
    await _repo.skipOnboarding();
    _invalidateCache();
  }

  /// Reset onboarding (for re-show from settings)
  Future<void> resetOnboarding() async {
    await _repo.resetOnboarding();
    _invalidateCache();
  }

  // ==================== Setup Progress ====================

  /// Get setup progress as map
  Future<Map<String, dynamic>> getSetupProgress() async {
    final progress = await _getProgress();
    
    final stockCount = progress['stock_count'] ?? 0;
    final stockAdded = stockCount >= 3; // Need minimum 3 items
    
    return {
      'stock_added': stockAdded,
      'stock_count': stockCount,
      'product_created': progress['product_created'] ?? false,
      'production_recorded': progress['production_recorded'] ?? false,
      'sale_recorded': progress['sale_recorded'] ?? false,
      'profile_completed': progress['profile_completed'] ?? false,
      'vendor_added': progress['vendor_added'] ?? false,
      'delivery_recorded': progress['delivery_recorded'] ?? false,
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

  /// Check if ALL tasks (required + optional) are complete
  Future<bool> isAllTasksComplete() async {
    final progress = await getSetupProgress();
    return progress['stock_added'] == true &&
           progress['product_created'] == true &&
           progress['production_recorded'] == true &&
           progress['sale_recorded'] == true &&
           progress['profile_completed'] == true &&
           progress['vendor_added'] == true &&
           progress['delivery_recorded'] == true;
  }

  /// Calculate setup progress percentage
  Future<int> getSetupProgressPercentage() async {
    final progress = await getSetupProgress();
    int completed = 0;
    int total = 7; // 4 required + 3 optional (profile, vendor, delivery)
    
    if (progress['stock_added'] == true) completed++;
    if (progress['product_created'] == true) completed++;
    if (progress['production_recorded'] == true) completed++;
    if (progress['sale_recorded'] == true) completed++;
    if (progress['profile_completed'] == true) completed++;
    if (progress['vendor_added'] == true) completed++;
    if (progress['delivery_recorded'] == true) completed++;
    
    return ((completed / total) * 100).round();
  }

  /// Update stock progress (increment count)
  Future<void> incrementStockCount() async {
    await _repo.incrementStockCount();
    _invalidateCache();
  }

  /// Mark product as created
  Future<void> markProductCreated() async {
    await _repo.markProductCreated();
    _invalidateCache();
  }

  /// Mark production as recorded
  Future<void> markProductionRecorded() async {
    await _repo.markProductionRecorded();
    _invalidateCache();
  }

  /// Mark sale as recorded
  Future<void> markSaleRecorded() async {
    await _repo.markSaleRecorded();
    _invalidateCache();
  }

  /// Mark profile as completed
  Future<void> markProfileCompleted() async {
    await _repo.markProfileCompleted();
    _invalidateCache();
  }

  /// Mark vendor as added (optional - for consignment users)
  Future<void> markVendorAdded() async {
    await _repo.markVendorAdded();
    _invalidateCache();
  }

  /// Mark delivery as recorded (optional - for consignment users)
  Future<void> markDeliveryRecorded() async {
    await _repo.markDeliveryRecorded();
    _invalidateCache();
  }

  // ==================== Setup Widget ====================

  /// Check if setup widget should be shown
  Future<bool> shouldShowSetupWidget() async {
    final progress = await _getProgress();
    
    // Don't show if dismissed
    final isDismissed = progress['setup_dismissed'] ?? false;
    if (isDismissed) {
      return false;
    }
    
    // Don't show if ALL tasks complete (required + optional)
    final allComplete = await isAllTasksComplete();
    if (allComplete) return false;
    
    // Check if 14 days passed since onboarding - auto hide
    final completedAtStr = progress['onboarding_completed_at'];
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
    await _repo.dismissSetupWidget();
    _invalidateCache();
  }

  /// Reset setup widget (to re-show)
  Future<void> resetSetupWidget() async {
    await _repo.resetSetupWidget();
    _invalidateCache();
  }

  /// Reset all setup progress (for testing)
  Future<void> resetAllProgress() async {
    await _repo.resetAllProgress();
    _invalidateCache();
  }
}
