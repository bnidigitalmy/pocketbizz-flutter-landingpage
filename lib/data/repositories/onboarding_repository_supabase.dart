import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for managing onboarding progress in Supabase
class OnboardingRepositorySupabase {
  final SupabaseClient _client;

  OnboardingRepositorySupabase({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Get or create onboarding progress for current user
  Future<Map<String, dynamic>> getProgress() async {
    if (_userId == null) {
      return _defaultProgress();
    }

    try {
      // Try to get existing record
      final response = await _client
          .from('user_onboarding_progress')
          .select()
          .eq('user_id', _userId!)
          .maybeSingle();

      if (response != null) {
        return response;
      }

      // Create new record if not exists
      final newRecord = await _client
          .from('user_onboarding_progress')
          .insert({'user_id': _userId})
          .select()
          .single();

      return newRecord;
    } catch (e) {
      // If table doesn't exist or other error, return defaults
      print('OnboardingRepository.getProgress error: $e');
      return _defaultProgress();
    }
  }

  /// Update onboarding progress
  Future<void> updateProgress(Map<String, dynamic> updates) async {
    if (_userId == null) return;

    try {
      // First ensure record exists
      await getProgress();

      // Then update
      await _client
          .from('user_onboarding_progress')
          .update(updates)
          .eq('user_id', _userId!);
    } catch (e) {
      print('OnboardingRepository.updateProgress error: $e');
    }
  }

  /// Mark onboarding as seen/complete
  Future<void> markOnboardingComplete() async {
    await updateProgress({
      'has_seen_onboarding': true,
      'onboarding_completed_at': DateTime.now().toIso8601String(),
    });
  }

  /// Skip onboarding
  Future<void> skipOnboarding() async {
    await markOnboardingComplete();
  }

  /// Reset onboarding (for re-show from settings)
  Future<void> resetOnboarding() async {
    await updateProgress({
      'has_seen_onboarding': false,
      'onboarding_completed_at': null,
    });
  }

  /// Increment stock count
  Future<void> incrementStockCount() async {
    final progress = await getProgress();
    final currentCount = progress['stock_count'] ?? 0;
    await updateProgress({'stock_count': currentCount + 1});
  }

  /// Mark product created
  Future<void> markProductCreated() async {
    await updateProgress({'product_created': true});
  }

  /// Mark production recorded
  Future<void> markProductionRecorded() async {
    await updateProgress({'production_recorded': true});
  }

  /// Mark sale recorded
  Future<void> markSaleRecorded() async {
    await updateProgress({'sale_recorded': true});
  }

  /// Mark profile completed
  Future<void> markProfileCompleted() async {
    await updateProgress({'profile_completed': true});
  }

  /// Mark vendor added
  Future<void> markVendorAdded() async {
    await updateProgress({'vendor_added': true});
  }

  /// Mark delivery recorded
  Future<void> markDeliveryRecorded() async {
    await updateProgress({'delivery_recorded': true});
  }

  /// Dismiss setup widget
  Future<void> dismissSetupWidget() async {
    await updateProgress({
      'setup_dismissed': true,
      'setup_dismissed_at': DateTime.now().toIso8601String(),
    });
  }

  /// Reset setup widget
  Future<void> resetSetupWidget() async {
    await updateProgress({
      'setup_dismissed': false,
      'setup_dismissed_at': null,
    });
  }

  /// Reset all progress (for testing)
  Future<void> resetAllProgress() async {
    await updateProgress({
      'has_seen_onboarding': false,
      'onboarding_completed_at': null,
      'setup_dismissed': false,
      'setup_dismissed_at': null,
      'stock_count': 0,
      'product_created': false,
      'production_recorded': false,
      'sale_recorded': false,
      'profile_completed': false,
      'vendor_added': false,
      'delivery_recorded': false,
    });
  }

  /// Default progress when not logged in or error
  Map<String, dynamic> _defaultProgress() {
    return {
      'has_seen_onboarding': false,
      'onboarding_completed_at': null,
      'setup_dismissed': false,
      'setup_dismissed_at': null,
      'stock_count': 0,
      'product_created': false,
      'production_recorded': false,
      'sale_recorded': false,
      'profile_completed': false,
      'vendor_added': false,
      'delivery_recorded': false,
    };
  }
}
