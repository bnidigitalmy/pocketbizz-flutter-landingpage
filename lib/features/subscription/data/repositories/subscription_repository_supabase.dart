import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription_plan.dart';
import '../models/subscription.dart';
import '../models/plan_limits.dart' show PlanLimits, LimitInfo;
import '../models/early_adopter.dart';
import '../../../../core/supabase/supabase_client.dart';

/// Subscription Repository
/// Handles all subscription-related database operations
class SubscriptionRepositorySupabase {
  final SupabaseClient _supabase = supabase;

  /// Get all available subscription plans
  Future<List<SubscriptionPlan>> getAvailablePlans() async {
    try {
      final response = await _supabase
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .order('display_order');

      return (response as List)
          .map((json) => SubscriptionPlan.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch subscription plans: $e');
    }
  }

  /// Get user's current subscription
  Future<Subscription?> getUserSubscription() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('subscriptions')
          .select('''
            *,
            subscription_plans:plan_id (
              name,
              duration_months
            )
          ''')
          .eq('user_id', userId)
          .inFilter('status', ['trial', 'active'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final json = response as Map<String, dynamic>;
      final planData = json['subscription_plans'] as Map<String, dynamic>?;
      
      // Merge plan name into subscription data
      if (planData != null) {
        json['plan_name'] = planData['name'] as String? ?? 'PocketBizz Pro';
        json['duration_months'] = planData['duration_months'] as int? ?? 1;
      }

      return Subscription.fromJson(json);
    } catch (e) {
      throw Exception('Failed to fetch user subscription: $e');
    }
  }

  /// Get all user subscriptions (history)
  Future<List<Subscription>> getUserSubscriptionHistory() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('subscriptions')
          .select('''
            *,
            subscription_plans:plan_id (
              name,
              duration_months
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        final data = json as Map<String, dynamic>;
        final planData = data['subscription_plans'] as Map<String, dynamic>?;
        
        if (planData != null) {
          data['plan_name'] = planData['name'] as String? ?? 'PocketBizz Pro';
          data['duration_months'] = planData['duration_months'] as int? ?? 1;
        }

        return Subscription.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch subscription history: $e');
    }
  }

  /// Check if user is early adopter
  Future<bool> isEarlyAdopter() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase.rpc('is_early_adopter', params: {
        'user_uuid': userId,
      });

      return response as bool? ?? false;
    } catch (e) {
      // If function doesn't exist or error, return false
      return false;
    }
  }

  /// Get early adopter count
  Future<int> getEarlyAdopterCount() async {
    try {
      final response = await _supabase.rpc('get_early_adopter_count');
      return response as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Register user as early adopter (if under 100)
  Future<bool> registerEarlyAdopter() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final userEmail = _supabase.auth.currentUser?.email;
      
      if (userId == null || userEmail == null) return false;

      final response = await _supabase.rpc('register_early_adopter', params: {
        'user_uuid': userId,
        'user_email': userEmail,
      });

      return response as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Start free trial for user
  Future<Subscription> startTrial() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if user already has active subscription or trial
      final existing = await getUserSubscription();
      if (existing != null) {
        throw Exception('User already has an active subscription or trial');
      }

      // Get 1 month plan for trial
      final plans = await getAvailablePlans();
      final oneMonthPlan = plans.firstWhere(
        (p) => p.durationMonths == 1,
        orElse: () => plans.first,
      );

      // Check early adopter status
      final isEarlyAdopter = await this.isEarlyAdopter();
      
      // Calculate trial end date (7 days from now)
      final now = DateTime.now();
      final trialEndsAt = now.add(const Duration(days: 7));

      // Create trial subscription
      final response = await _supabase
          .from('subscriptions')
          .insert({
            'user_id': userId,
            'plan_id': oneMonthPlan.id,
            'price_per_month': isEarlyAdopter ? 29.0 : 39.0,
            'total_amount': 0.0, // Trial is free
            'discount_applied': 0.0,
            'is_early_adopter': isEarlyAdopter,
            'status': 'trial',
            'trial_started_at': now.toIso8601String(),
            'trial_ends_at': trialEndsAt.toIso8601String(),
            'expires_at': trialEndsAt.toIso8601String(),
            'auto_renew': false,
          })
          .select('''
            *,
            subscription_plans:plan_id (
              name,
              duration_months
            )
          ''')
          .single();

      final json = response as Map<String, dynamic>;
      final planData = json['subscription_plans'] as Map<String, dynamic>?;
      
      if (planData != null) {
        json['plan_name'] = planData['name'] as String? ?? 'PocketBizz Pro';
        json['duration_months'] = planData['duration_months'] as int? ?? 1;
      }

      return Subscription.fromJson(json);
    } catch (e) {
      throw Exception('Failed to start trial: $e');
    }
  }

  /// Create subscription (after payment)
  Future<Subscription> createSubscription({
    required String planId,
    required double totalAmount,
    required String paymentReference,
    String? gatewayTransactionId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get plan details
      final planResponse = await _supabase
          .from('subscription_plans')
          .select()
          .eq('id', planId)
          .single();

      final plan = SubscriptionPlan.fromJson(planResponse as Map<String, dynamic>);

      // Check early adopter status
      final isEarlyAdopter = await this.isEarlyAdopter();
      final pricePerMonth = isEarlyAdopter ? 29.0 : 39.0;
      final calculatedTotal = isEarlyAdopter 
          ? plan.getPriceForEarlyAdopter() 
          : plan.totalPrice;
      
      final discountApplied = (pricePerMonth * plan.durationMonths) - calculatedTotal;

      // Calculate expiry date
      final now = DateTime.now();
      final expiresAt = now.add(Duration(days: plan.durationMonths * 30));

      // Create subscription
      final response = await _supabase
          .from('subscriptions')
          .insert({
            'user_id': userId,
            'plan_id': planId,
            'price_per_month': pricePerMonth,
            'total_amount': calculatedTotal,
            'discount_applied': discountApplied,
            'is_early_adopter': isEarlyAdopter,
            'status': 'active',
            'started_at': now.toIso8601String(),
            'expires_at': expiresAt.toIso8601String(),
            'payment_gateway': 'bcl_my',
            'payment_reference': paymentReference,
            'payment_status': 'completed',
            'payment_completed_at': now.toIso8601String(),
            'auto_renew': false,
          })
          .select('''
            *,
            subscription_plans:plan_id (
              name,
              duration_months
            )
          ''')
          .single();

      final json = response as Map<String, dynamic>;
      final planData = json['subscription_plans'] as Map<String, dynamic>?;
      
      if (planData != null) {
        json['plan_name'] = planData['name'] as String? ?? 'PocketBizz Pro';
        json['duration_months'] = planData['duration_months'] as int? ?? 1;
      }

      // Create payment record
      await _supabase.from('subscription_payments').insert({
        'subscription_id': json['id'] as String,
        'user_id': userId,
        'amount': calculatedTotal,
        'currency': 'MYR',
        'payment_gateway': 'bcl_my',
        'payment_reference': paymentReference,
        'gateway_transaction_id': gatewayTransactionId,
        'status': 'completed',
        'paid_at': now.toIso8601String(),
      });

      return Subscription.fromJson(json);
    } catch (e) {
      throw Exception('Failed to create subscription: $e');
    }
  }

  /// Get plan limits (usage tracking)
  Future<PlanLimits> getPlanLimits() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return PlanLimits(
          products: LimitInfo(current: 0, max: 0),
          stockItems: LimitInfo(current: 0, max: 0),
          transactions: LimitInfo(current: 0, max: 0),
        );
      }

      // Get subscription to check if active
      final subscription = await getUserSubscription();
      final isActive = subscription?.isActive ?? false;

      // For now, return unlimited for active subscriptions
      // Can be customized based on plan tier later
      if (isActive) {
        return PlanLimits(
          products: LimitInfo(current: 0, max: 999999),
          stockItems: LimitInfo(current: 0, max: 999999),
          transactions: LimitInfo(current: 0, max: 999999),
        );
      }

      // For trial or expired, return limited (can customize)
      return PlanLimits(
        products: LimitInfo(current: 0, max: 50),
        stockItems: LimitInfo(current: 0, max: 100),
        transactions: LimitInfo(current: 0, max: 100),
      );
    } catch (e) {
      // Return default limits on error
      return PlanLimits(
        products: LimitInfo(current: 0, max: 0),
        stockItems: LimitInfo(current: 0, max: 0),
        transactions: LimitInfo(current: 0, max: 0),
      );
    }
  }

  /// Update subscription status (for webhook callbacks)
  Future<void> updateSubscriptionStatus({
    required String subscriptionId,
    required SubscriptionStatus status,
    String? paymentReference,
    String? gatewayTransactionId,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status.toString().split('.').last,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (paymentReference != null) {
        updateData['payment_reference'] = paymentReference;
      }

      if (status == SubscriptionStatus.active) {
        updateData['payment_status'] = 'completed';
        updateData['payment_completed_at'] = DateTime.now().toIso8601String();
      }

      await _supabase
          .from('subscriptions')
          .update(updateData)
          .eq('id', subscriptionId);

      // Update payment record if provided
      if (gatewayTransactionId != null && paymentReference != null) {
        await _supabase
            .from('subscription_payments')
            .update({
              'status': 'completed',
              'paid_at': DateTime.now().toIso8601String(),
              'gateway_transaction_id': gatewayTransactionId,
            })
            .eq('payment_reference', paymentReference);
      }
    } catch (e) {
      throw Exception('Failed to update subscription status: $e');
    }
  }
}

