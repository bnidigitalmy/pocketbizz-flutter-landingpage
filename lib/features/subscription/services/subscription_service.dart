import '../data/repositories/subscription_repository_supabase.dart';
import '../data/models/subscription.dart';
import '../data/models/subscription_plan.dart';
import '../data/models/subscription_payment.dart';
import '../data/models/plan_limits.dart';
import '../data/repositories/subscription_repository_supabase.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../../../core/supabase/supabase_client.dart';

/// Subscription Service
/// Business logic for subscription management
class SubscriptionService {
  final SubscriptionRepositorySupabase _repo = SubscriptionRepositorySupabase();
  static const Duration _defaultTimeout = Duration(seconds: 12);
  // BCL.my payment forms (must match the exact charged totals)
  // Normal price (RM39/bulan): np-*
  static const _bclFormUrlsNormal = {
    1: 'https://bnidigital.bcl.my/form/np-1-bulan',
    3: 'https://bnidigital.bcl.my/form/np-3-bulan',
    6: 'https://bnidigital.bcl.my/form/np-6-bulan',
    12: 'https://bnidigital.bcl.my/form/np-12-bulan',
  };

  // Early adopter (RM29/bulan): ea-*
  static const _bclFormUrlsEarlyAdopter = {
    1: 'https://bnidigital.bcl.my/form/ea-1-bulan',
    3: 'https://bnidigital.bcl.my/form/ea-3-bulan',
    6: 'https://bnidigital.bcl.my/form/ea-6-bulan',
    12: 'https://bnidigital.bcl.my/form/ea-12-bulan',
  };

  static String? _bclUrlForDuration(int durationMonths, {required bool isEarlyAdopter}) {
    return (isEarlyAdopter ? _bclFormUrlsEarlyAdopter : _bclFormUrlsNormal)[durationMonths];
  }

  Future<void> _launchExternal(Uri uri) async {
    // PWA/Web: externalApplication can fail in standalone mode.
    // Use platformDefault and navigate in the same window for reliability.
    if (kIsWeb) {
      try {
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_self',
        );
        return;
      } catch (_) {
        // Fallback: try new tab
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_blank',
        );
        return;
      }
    }

    // Mobile/desktop
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Open BCL.my payment form with an existing order id (no DB writes).
  /// Used for pending_payment flows ("Teruskan Pembayaran") so users don't create multiple pending sessions.
  Future<void> openBclPaymentForm({
    required int durationMonths,
    required String orderId,
    bool? isEarlyAdopter,
  }) async {
    final early = isEarlyAdopter ?? await _repo.isEarlyAdopter();
    final url = _bclUrlForDuration(durationMonths, isEarlyAdopter: early);
    if (url == null) {
      throw Exception('Invalid duration: $durationMonths');
    }
    final uri = Uri.parse(url).replace(queryParameters: {
      ...Uri.parse(url).queryParameters,
      'order_id': orderId,
    });
    if (await canLaunchUrl(uri)) {
      await _launchExternal(uri);
    } else {
      throw Exception('Could not launch payment URL');
    }
  }

  /// Initialize trial for new user
  /// Called automatically on user registration
  Future<Subscription> initializeTrial() async {
    try {
      // Prefer DB-side ensure to avoid client/RLS quirks.
      // This will create a 7-day trial if eligible, or return existing active/trial/grace.
      final ensured = await _repo.ensureTrialSubscription();
      if (ensured != null) return ensured;

      // Fallback (older DBs): client-side flow.
      final earlyAdopterCount = await _repo.getEarlyAdopterCount();
      if (earlyAdopterCount < 100) {
        await _repo.registerEarlyAdopter();
      }
      return await _repo.startTrial();
    } catch (e) {
      throw Exception('Failed to initialize trial: $e');
    }
  }

  /// Get current subscription status
  Future<Subscription?> getCurrentSubscription() async {
    return _repo.getUserSubscription().timeout(_defaultTimeout);
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
    return _repo.isEarlyAdopter().timeout(_defaultTimeout);
  }

  /// Get available subscription plans
  Future<List<SubscriptionPlan>> getAvailablePlans() async {
    return _repo.getAvailablePlans().timeout(_defaultTimeout);
  }

  /// Get plan limits (usage tracking)
  Future<PlanLimits> getPlanLimits() async {
    try {
      // Fast path: COUNT queries (avoid downloading all rows)
      return await _getPlanLimitsFast().timeout(_defaultTimeout);
    } catch (_) {
      // Fallback (older DBs/edge cases)
      return _repo.getPlanLimits().timeout(_defaultTimeout);
    }
  }

  Future<PlanLimits> _getPlanLimitsFast() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return PlanLimits(
        products: LimitInfo(current: 0, max: 0),
        stockItems: LimitInfo(current: 0, max: 0),
        transactions: LimitInfo(current: 0, max: 0),
      );
    }

    final subscription = await getCurrentSubscription();
    final isActive = subscription?.isActive ?? false;
    final isTrial = subscription?.isOnTrial ?? false;

    Future<int> countProducts() async {
      final resp = await supabase
          .from('products')
          .select('id')
          .eq('business_owner_id', userId)
          .eq('is_active', true)
          .count();
      return resp.count;
    }

    Future<int> countStockItems() async {
      try {
        final resp = await supabase
            .from('stock_items')
            .select('id')
            .eq('business_owner_id', userId)
            .eq('is_archived', false)
            .count();
        return resp.count;
      } catch (_) {
        // Backward compatibility
        final resp = await supabase
            .from('ingredients')
            .select('id')
            .eq('business_owner_id', userId)
            .count();
        return resp.count;
      }
    }

    Future<int> countTransactions() async {
      final resp = await supabase
          .from('sales')
          .select('id')
          .eq('business_owner_id', userId)
          .count();
      return resp.count;
    }

    final counts = await Future.wait([
      countProducts(),
      countStockItems(),
      countTransactions(),
    ]);

    final productsCount = counts[0];
    final stockItemsCount = counts[1];
    final transactionsCount = counts[2];

    final maxProducts = isTrial ? 10 : (isActive ? 500 : 10);
    final maxStockItems = isTrial ? 50 : (isActive ? 2000 : 50);
    final maxTransactions = isTrial ? 100 : (isActive ? 10000 : 100);

    return PlanLimits(
      products: LimitInfo(current: productsCount, max: maxProducts),
      stockItems: LimitInfo(current: stockItemsCount, max: maxStockItems),
      transactions: LimitInfo(current: transactionsCount, max: maxTransactions),
    );
  }

  /// Redirect to payment form with order_id and pending session
  /// paymentGateway: 'bcl_my' | 'paypal'
  /// isExtend: if true, extends existing subscription by adding duration to expiry date
  Future<void> redirectToPayment({
    required int durationMonths,
    required String planId,
    String paymentGateway = 'bcl_my',
    bool isExtend = false,
  }) async {
    // Fetch plan & pricing
    final plan = await _repo.getPlanById(planId);
    final isEarlyAdopter = await _repo.isEarlyAdopter();
    final pricePerMonth = isEarlyAdopter ? 29.0 : plan.pricePerMonth;
    final totalAmount = isEarlyAdopter ? plan.getPriceForEarlyAdopter() : plan.totalPrice;

    // Generate order id
    final orderId = 'PBZ-${const Uuid().v4()}';

    // Create pending subscription & payment
    await _repo.createPendingPaymentSession(
      planId: planId,
      orderId: orderId,
      totalAmount: totalAmount,
      pricePerMonth: pricePerMonth,
      isEarlyAdopter: isEarlyAdopter,
      paymentGateway: paymentGateway,
      isExtend: isExtend,
    );

    if (paymentGateway == 'paypal') {
      // TODO: hook to PayPal Edge Function when ready
      throw Exception('PayPal integration pending Edge Function implementation');
    }

    // Default: BCL.my
    final url = _bclUrlForDuration(durationMonths, isEarlyAdopter: isEarlyAdopter);
    if (url == null) {
      throw Exception('Invalid duration: $durationMonths');
    }
    final uri = Uri.parse(url).replace(queryParameters: {
      ...Uri.parse(url).queryParameters,
      'order_id': orderId,
    });
    if (await canLaunchUrl(uri)) {
      await _launchExternal(uri);
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

  /// Confirm pending payment (order_id) and activate subscription
  Future<Subscription> confirmPendingPayment({
    required String orderId,
    String? gatewayTransactionId,
  }) async {
    return _repo.activatePendingPayment(
      orderId: orderId,
      gatewayTransactionId: gatewayTransactionId,
    );
  }

  /// Get proration quote for changing plan
  Future<ProrationQuote> getProrationQuote(String targetPlanId) {
    return _repo.getProrationQuote(targetPlanId: targetPlanId);
  }

  /// Change plan with proration. If amountDue > 0, opens payment URL.
  Future<void> changePlanProrated(String targetPlanId) async {
    final result = await _repo.changePlanProrated(targetPlanId: targetPlanId);
    if (result.amountDue <= 0 || result.orderId == null) {
      // No payment needed; either instant switch or scheduled downgrade
      return;
    }
    // For proration, we need to pass dynamic amount
    final url = await _paymentUrlForProration(
      durationMonths: result.durationMonths,
      orderId: result.orderId!,
      amount: result.amountDue,
    );
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await _launchExternal(uri);
    } else {
      throw Exception('Could not launch payment URL');
    }
  }

  /// Retry a failed/pending payment and redirect to payment page with new order id
  Future<void> retryPayment({
    required SubscriptionPayment payment,
    String? paymentGateway,
  }) async {
    final result = await _repo.retryPayment(
      payment: payment,
      paymentGateway: paymentGateway,
    );
    final early = await _repo.isEarlyAdopter();
    final baseUrl = _bclUrlForDuration(result.durationMonths, isEarlyAdopter: early);
    if (baseUrl == null) throw Exception('Invalid duration: ${result.durationMonths}');
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      ...Uri.parse(baseUrl).queryParameters,
      'order_id': result.orderId,
    });
    if (await canLaunchUrl(uri)) {
      await _launchExternal(uri);
    } else {
      throw Exception('Could not launch payment URL');
    }
  }

  // _paymentUrlForDuration removed; all BCL URLs must use correct (np vs ea) base form.

  /// Generate payment URL for proration with dynamic amount
  /// Since BCL.my forms don't accept amount parameter, we need to:
  /// 1. Use a generic payment form (if available)
  /// 2. Or call Edge Function to create custom payment link
  /// 3. Or handle amount mismatch in webhook
  Future<String> _paymentUrlForProration({
    required int durationMonths,
    required String orderId,
    required double amount,
  }) async {
    try {
      // Option 1: Try to call Edge Function to create custom payment link
      // This requires BCL.my API integration
      final response = await supabase.functions.invoke(
        'bcl-create-payment-link',
        body: {
          'orderId': orderId,
          'amount': amount,
          'durationMonths': durationMonths,
          'description': 'Tukar Pelan (Prorata)',
          'redirectUrl': 'https://app.pocketbizz.my/#/payment-success',
        },
      );
      
      if (response.data != null && response.data['paymentUrl'] != null) {
        return response.data['paymentUrl'] as String;
      }
    } catch (e) {
      print('⚠️ Edge Function not available, using fallback: $e');
    }
    
    // Option 2: Fallback - Use generic payment form or closest form
    // IMPORTANT: BCL.my form will show fixed amount, but webhook will verify
    // actual prorated amount from database
    
    // Check if we have a generic payment form URL
    // If not, use closest duration form
    final early = await _repo.isEarlyAdopter();
    final baseUrl = _bclUrlForDuration(durationMonths, isEarlyAdopter: early) ??
        _bclUrlForDuration(12, isEarlyAdopter: early)!;
    
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      ...Uri.parse(baseUrl).queryParameters,
      'order_id': orderId,
      'prorated': 'true', // Flag for webhook to verify amount
    });
    
    // Note: BCL.my form will show fixed amount (e.g., RM 295.80 for 12 bulan)
    // But webhook will verify actual prorated amount (RM 267.97) from database
    // and activate subscription correctly
    
    return uri.toString();
  }

  /// Subscribe to payment status changes for current user
  RealtimeChannel? subscribePaymentNotifications(void Function(SubscriptionPayment) onChange) {
    return _repo.subscribePaymentStatus(onChange);
  }

  Future<void> sendPaymentFailedEmail(SubscriptionPayment payment, {String? reason}) {
    return _repo.sendPaymentFailedEmail(payment: payment, reason: reason);
  }

  /// Get subscription history
  Future<List<Subscription>> getSubscriptionHistory() async {
    return _repo.getUserSubscriptionHistory().timeout(_defaultTimeout);
  }

  /// Get payment history
  Future<List<SubscriptionPayment>> getPaymentHistory() async {
    return _repo.getPaymentHistory().timeout(_defaultTimeout);
  }

  /// Get payments for specific subscription
  Future<List<SubscriptionPayment>> getSubscriptionPayments(String subscriptionId) async {
    return await _repo.getSubscriptionPayments(subscriptionId);
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

  // ============================================================================
  // ADMIN METHODS
  // ============================================================================

  /// Get admin subscription statistics
  Future<Map<String, dynamic>> getAdminSubscriptionStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return _repo.getAdminSubscriptionStats(
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Get admin revenue statistics
  Future<Map<String, dynamic>> getAdminRevenueStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return _repo.getAdminRevenueStats(
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Get admin payment statistics
  Future<Map<String, dynamic>> getAdminPaymentStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return _repo.getAdminPaymentStats(
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Get all subscriptions for admin
  Future<List<Subscription>> getAdminSubscriptions({
    String? status,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    int offset = 0,
  }) async {
    return _repo.getAdminSubscriptions(
      status: status,
      userId: userId,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      offset: offset,
    );
  }

  // ============================================================================
  // PAUSE/RESUME METHODS
  // ============================================================================

  /// Pause a subscription
  Future<Subscription> pauseSubscription({
    required String subscriptionId,
    required int daysToPause,
    String? reason,
    DateTime? pausedUntil,
  }) async {
    return _repo.pauseSubscription(
      subscriptionId: subscriptionId,
      daysToPause: daysToPause,
      reason: reason,
      pausedUntil: pausedUntil,
    );
  }

  /// Resume a paused subscription
  Future<Subscription> resumeSubscription(String subscriptionId) async {
    return _repo.resumeSubscription(subscriptionId);
  }

  // ============================================================================
  // REFUND METHODS
  // ============================================================================

  /// Process refund for a payment
  Future<Map<String, dynamic>> processRefund({
    required String paymentId,
    required double refundAmount,
    required String reason,
    bool fullRefund = false,
  }) async {
    return _repo.processRefund(
      paymentId: paymentId,
      refundAmount: refundAmount,
      reason: reason,
      fullRefund: fullRefund,
    );
  }

  // ============================================================================
  // ADMIN MANUAL OPERATIONS
  // ============================================================================

  /// Manually activate subscription for a user (admin only)
  Future<Subscription> manualActivateSubscription({
    required String userId,
    required String planId,
    required int durationMonths,
    String? notes,
  }) async {
    return _repo.manualActivateSubscription(
      userId: userId,
      planId: planId,
      durationMonths: durationMonths,
      notes: notes,
    );
  }

  /// Extend subscription expiry date (admin only)
  Future<Subscription> extendSubscription({
    required String subscriptionId,
    required int extensionMonths,
    String? notes,
  }) async {
    return _repo.extendSubscription(
      subscriptionId: subscriptionId,
      extensionMonths: extensionMonths,
      notes: notes,
    );
  }

  /// Add manual payment record (admin only)
  Future<Map<String, dynamic>> addManualPayment({
    required String userId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    return _repo.addManualPayment(
      userId: userId,
      amount: amount,
      paymentMethod: paymentMethod,
      notes: notes,
    );
  }
}

