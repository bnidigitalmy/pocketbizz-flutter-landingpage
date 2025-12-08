import '../data/repositories/subscription_repository_supabase.dart';
import '../data/models/subscription.dart';
import '../data/models/subscription_plan.dart';
import '../data/models/plan_limits.dart';
import 'package:url_launcher/url_launcher.dart';

/// Subscription Service
/// Business logic for subscription management
class SubscriptionService {
  final SubscriptionRepositorySupabase _repo = SubscriptionRepositorySupabase();

  /// Initialize trial for new user
  /// Called automatically on user registration
  Future<Subscription> initializeTrial() async {
    try {
      // Check if user is early adopter (first 100 users)
      final earlyAdopterCount = await _repo.getEarlyAdopterCount();
      if (earlyAdopterCount < 100) {
        await _repo.registerEarlyAdopter();
      }

      // Start trial
      return await _repo.startTrial();
    } catch (e) {
      throw Exception('Failed to initialize trial: $e');
    }
  }

  /// Get current subscription status
  Future<Subscription?> getCurrentSubscription() async {
    return await _repo.getUserSubscription();
  }

  /// Check if user has active subscription (trial or paid)
  Future<bool> hasActiveSubscription() async {
    final subscription = await getCurrentSubscription();
    return subscription?.isActive ?? false;
  }

  /// Check if user is on trial
  Future<bool> isOnTrial() async {
    final subscription = await getCurrentSubscription();
    return subscription?.isOnTrial ?? false;
  }

  /// Check if user is early adopter
  Future<bool> isEarlyAdopter() async {
    return await _repo.isEarlyAdopter();
  }

  /// Get available subscription plans
  Future<List<SubscriptionPlan>> getAvailablePlans() async {
    return await _repo.getAvailablePlans();
  }

  /// Get plan limits (usage tracking)
  Future<PlanLimits> getPlanLimits() async {
    return await _repo.getPlanLimits();
  }

  /// Redirect to bcl.my payment form
  /// Based on the React code provided
  Future<void> redirectToPayment({
    required int durationMonths,
    required String planId,
  }) async {
    // BCL.my form URLs (from provided React code)
    const bclFormUrls = {
      1: 'https://bnidigital.bcl.my/form/1-bulan',
      3: 'https://bnidigital.bcl.my/form/3-bulan',
      6: 'https://bnidigital.bcl.my/form/6-bulan',
      12: 'https://bnidigital.bcl.my/form/12-bulan',
    };

    final url = bclFormUrls[durationMonths];
    if (url == null) {
      throw Exception('Invalid duration: $durationMonths');
    }

    // Open URL in browser
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch payment URL');
    }
  }

  /// Handle payment callback (after user returns from bcl.my)
  /// This should be called when user returns to app after payment
  Future<Subscription?> handlePaymentCallback({
    required String paymentReference,
    String? gatewayTransactionId,
    required String planId,
  }) async {
    try {
      // Get plan to calculate amount
      final plans = await getAvailablePlans();
      final plan = plans.firstWhere((p) => p.id == planId);

      // Check early adopter status
      final isEarlyAdopter = await this.isEarlyAdopter();
      final totalAmount = isEarlyAdopter 
          ? plan.getPriceForEarlyAdopter() 
          : plan.totalPrice;

      // Create subscription
      return await _repo.createSubscription(
        planId: planId,
        totalAmount: totalAmount,
        paymentReference: paymentReference,
        gatewayTransactionId: gatewayTransactionId,
      );
    } catch (e) {
      throw Exception('Failed to process payment callback: $e');
    }
  }

  /// Get subscription history
  Future<List<Subscription>> getSubscriptionHistory() async {
    return await _repo.getUserSubscriptionHistory();
  }

  /// Cancel subscription (set auto_renew to false)
  Future<void> cancelSubscription(String subscriptionId) async {
    // Note: This doesn't immediately cancel, just stops auto-renewal
    // User still has access until expiry
    await _repo.updateSubscriptionStatus(
      subscriptionId: subscriptionId,
      status: SubscriptionStatus.active, // Keep active, just stop renewal
    );
  }
}

