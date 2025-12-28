/**
 * 🔒 STABLE CORE MODULE – DO NOT MODIFY
 * This file is production-tested.
 * Any changes must be isolated via extension or wrapper.
 */
// ❌ AI WARNING:
// DO NOT refactor, rename, optimize or restructure this logic.
// Only READ-ONLY reference allowed.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/subscription_plan.dart';
import '../models/subscription.dart';
import '../models/subscription_payment.dart';
import '../models/plan_limits.dart' show PlanLimits, LimitInfo;
import '../models/early_adopter.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../core/utils/pdf_generator.dart';
import '../../../../core/services/document_storage_service.dart';
import '../../../../data/repositories/business_profile_repository_supabase.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        RealtimeChannel,
        PostgresChangeEvent,
        PostgresChangeFilter,
        PostgresChangeFilterType;
import 'dart:convert';

/// Subscription Repository
/// Handles all subscription-related database operations
class SubscriptionRepositorySupabase {
  final SupabaseClient _supabase = supabase;

  /// Ensure user has a trial subscription (DB-side).
  /// Returns the current active/trial/grace subscription (after ensuring), or null if not eligible.
  Future<Subscription?> ensureTrialSubscription() async {
    try {
      // Runs SECURITY DEFINER RPC in DB; creates trial if eligible.
      await _supabase.rpc('ensure_trial_subscription');
      // Fetch current subscription after ensuring.
      return await getUserSubscription();
    } catch (e) {
      // If RPC doesn't exist yet or fails, don't block; caller can fallback.
      return null;
    }
  }

  /// Helper: Add months to a date using calendar months (not fixed 30 days)
  /// Example: Jan 31 + 1 month = Feb 28/29 (not Mar 2)
  DateTime _addCalendarMonths(DateTime date, int months) {
    final newYear = date.year + (date.month + months - 1) ~/ 12;
    final newMonth = ((date.month + months - 1) % 12) + 1;
    final newDay = date.day;
    
    // Handle end-of-month edge cases (e.g., Jan 31 + 1 month = Feb 28/29)
    final daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
    final adjustedDay = newDay > daysInNewMonth ? daysInNewMonth : newDay;
    
    return DateTime(newYear, newMonth, adjustedDay, date.hour, date.minute, date.second, date.millisecond, date.microsecond);
  }

  /// Get plan by id
  Future<SubscriptionPlan> getPlanById(String planId) async {
    try {
      final response = await _supabase
          .from('subscription_plans')
          .select()
          .eq('id', planId)
          .single();

      return SubscriptionPlan.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch plan: $e');
    }
  }

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

      // Fetch recent subscriptions and pick the best "current" one.
      // We prefer an actually-active subscription (time-aware), otherwise fallback to the latest row.
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
          .order('created_at', ascending: false)
          .limit(5);

      if (response == null || (response is List && response.isEmpty)) return null;

      final rows = (response as List).cast<Map<String, dynamic>>();

      Subscription parseRow(Map<String, dynamic> row) {
        final planDataRaw = row['subscription_plans'];
        Map<String, dynamic>? planData;
        if (planDataRaw is Map<String, dynamic>) {
          planData = planDataRaw;
        } else if (planDataRaw is List && planDataRaw.isNotEmpty) {
          planData = planDataRaw.first as Map<String, dynamic>?;
        }
        if (planData != null) {
          row['plan_name'] = planData['name'] as String? ?? 'PocketBizz Pro';
          row['duration_months'] = planData['duration_months'] as int? ?? 1;
        }
        return Subscription.fromJson(row);
      }

      final subs = rows.map(parseRow).toList();

      // Prefer the first subscription that is truly active (time-aware).
      final active = subs.where((s) => s.isActive).toList();
      if (active.isNotEmpty) return active.first;

      // Fallback: return most recent (could be pending_payment/expired/cancelled)
      return subs.first;
    } catch (e) {
      throw Exception('Failed to fetch user subscription: $e');
    }
  }

  /// Get all user subscriptions (history)
  /// Excludes current active/trial subscriptions to avoid duplication
  Future<List<Subscription>> getUserSubscriptionHistory() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Get current subscription ID to exclude it from history
      final currentSub = await getUserSubscription();
      final currentSubId = currentSub?.id;

      // Query subscriptions with plan details
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
      
      if (response == null || (response is List && response.isEmpty)) {
        return [];
      }

      final subscriptions = (response as List).map((json) {
        try {
          final data = json as Map<String, dynamic>;
          
          // Handle nested relation - subscription_plans might be Map or List
          dynamic planDataRaw = data['subscription_plans'];
          Map<String, dynamic>? planData;
          
          if (planDataRaw is Map<String, dynamic>) {
            planData = planDataRaw;
          } else if (planDataRaw is List && planDataRaw.isNotEmpty) {
            planData = planDataRaw[0] as Map<String, dynamic>?;
          }
          
          if (planData != null) {
            data['plan_name'] = planData['name'] as String? ?? 'PocketBizz Pro';
            data['duration_months'] = planData['duration_months'] as int? ?? 1;
          } else {
            // Fallback values if plan data not found
            data['plan_name'] = 'PocketBizz Pro';
            data['duration_months'] = data['duration_months'] as int? ?? 1;
          }

          return Subscription.fromJson(data);
        } catch (e) {
          print('Error parsing subscription history item: $e');
          // Return null and filter out later
          return null;
        }
      }).whereType<Subscription>().toList();

      // Filter out current subscription and active/trial subscriptions
      final filtered = subscriptions.where((sub) {
        // Exclude current subscription by ID
        if (currentSubId != null && sub.id == currentSubId) return false;
        // Exclude active, trial, and grace subscriptions (only show expired/cancelled)
        if (sub.status == SubscriptionStatus.active || sub.isOnTrial || sub.status == SubscriptionStatus.grace) return false;
        return true;
      }).toList();

      // Remove duplicates by ID (extra safety)
      final seenIds = <String>{};
      return filtered.where((sub) {
        if (seenIds.contains(sub.id)) return false;
        seenIds.add(sub.id);
        return true;
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

      // Check if user has ever had a trial (prevent reuse)
      final previousTrials = await _supabase
          .from('subscriptions')
          .select('has_ever_had_trial')
          .eq('user_id', userId)
          .eq('has_ever_had_trial', true)
          .limit(1)
          .maybeSingle();
      
      if (previousTrials != null) {
        throw Exception('Trial has already been used. Please subscribe to continue using PocketBizz.');
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
            'has_ever_had_trial': true, // Mark that user has used trial
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

      // Calculate expiry date using calendar months
      final now = DateTime.now();
      final expiresAt = _addCalendarMonths(now, plan.durationMonths);
      final graceUntil = expiresAt.add(const Duration(days: 7));

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
            'grace_until': graceUntil.toIso8601String(),
            'payment_gateway': 'bcl_my',
            'payment_reference': paymentReference,
            'payment_status': 'completed',
            'payment_completed_at': now.toIso8601String(),
            'auto_renew': true, // PHASE 8: Enable auto-renewal by default
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
      final paymentResponse = await _supabase.from('subscription_payments').insert({
        'subscription_id': json['id'] as String,
        'user_id': userId,
        'amount': calculatedTotal,
        'currency': 'MYR',
        'payment_gateway': 'bcl_my',
        'payment_reference': paymentReference,
        'gateway_transaction_id': gatewayTransactionId,
        'status': 'completed',
        'paid_at': now.toIso8601String(),
      }).select('id').single();

      final paymentId = (paymentResponse as Map<String, dynamic>)['id'] as String;

      // Generate and upload receipt (non-blocking)
      _generateAndUploadReceipt(
        subscription: Subscription.fromJson(json),
        plan: plan,
        paymentReference: paymentReference,
        gatewayTransactionId: gatewayTransactionId,
        amount: calculatedTotal,
        paidAt: now,
        paymentId: paymentId,
      ).catchError((e) {
        // Log error but don't fail subscription creation
        print('⚠️ Failed to generate receipt (non-critical): $e');
      });

      return Subscription.fromJson(json);
    } catch (e) {
      throw Exception('Failed to create subscription: $e');
    }
  }

  /// Get plan limits (usage tracking)
  /// Counts actual usage: products, stock items (ingredients), and transactions (sales)
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

      // Get subscription to check if active and determine limits
      final subscription = await getUserSubscription();
      final isActive = subscription?.isActive ?? false;
      final isTrial = subscription?.isOnTrial ?? false;

      // Count actual usage
      final usageCounts = await Future.wait([
        _countProducts(userId),
        _countStockItems(userId),
        _countTransactions(userId),
      ]);

      final productsCount = usageCounts[0] as int;
      final stockItemsCount = usageCounts[1] as int;
      final transactionsCount = usageCounts[2] as int;

      // Set limits based on subscription status
      // Trial: 10 products, 50 stock items, 100 transactions
      // Active subscriptions: 500 products, 2000 stock items, 10000 transactions
      // Expired/Grace: Same as trial limits (10/50/100)
      final maxProducts = isTrial ? 10 : (isActive ? 500 : 10);
      final maxStockItems = isTrial ? 50 : (isActive ? 2000 : 50);
      final maxTransactions = isTrial ? 100 : (isActive ? 10000 : 100);

      return PlanLimits(
        products: LimitInfo(current: productsCount, max: maxProducts),
        stockItems: LimitInfo(current: stockItemsCount, max: maxStockItems),
        transactions: LimitInfo(current: transactionsCount, max: maxTransactions),
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

  /// Count products for user
  Future<int> _countProducts(String userId) async {
    try {
      final response = await _supabase
          .from('products')
          .select('id')
          .eq('business_owner_id', userId)
          .eq('is_active', true);

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Count stock items for user
  /// Uses stock_items table (not ingredients) as that's where actual stock is managed
  Future<int> _countStockItems(String userId) async {
    try {
      final response = await _supabase
          .from('stock_items')
          .select('id')
          .eq('business_owner_id', userId)
          .eq('is_archived', false);

      return (response as List).length;
    } catch (e) {
      // If stock_items table doesn't exist yet, fallback to ingredients for backward compatibility
      try {
        final fallbackResponse = await _supabase
            .from('ingredients')
            .select('id')
            .eq('business_owner_id', userId);
        return (fallbackResponse as List).length;
      } catch (_) {
        return 0;
      }
    }
  }

  /// Count transactions (sales) for user
  Future<int> _countTransactions(String userId) async {
    try {
      final response = await _supabase
          .from('sales')
          .select('id')
          .eq('business_owner_id', userId);

      return (response as List).length;
    } catch (e) {
      return 0;
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

  /// Create pending subscription + pending payment record before redirect
  /// isExtend: if true, extends existing subscription by adding duration to expiry date
  Future<String> createPendingPaymentSession({
    required String planId,
    required String orderId,
    required double totalAmount,
    required double pricePerMonth,
    required bool isEarlyAdopter,
    String paymentGateway = 'bcl_my',
    bool isExtend = false,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final plan = await getPlanById(planId);
      final discountApplied = (pricePerMonth * plan.durationMonths) - totalAmount;
      final now = DateTime.now();
      
      // Calculate expiry date
      DateTime expiresAt;
      if (isExtend) {
        // For extend: allow ACTIVE or GRACE (renewal within grace should still extend/reactivate)
        final currentSub = await getUserSubscription();
        if (currentSub == null ||
            (currentSub.status != SubscriptionStatus.active &&
                currentSub.status != SubscriptionStatus.grace)) {
          throw Exception('No active/grace subscription to extend');
        }
        // Add new duration using calendar months.
        // If user is already past expires_at (common in grace), start from now to give full duration.
        final base = currentSub.expiresAt.isAfter(now) ? currentSub.expiresAt : now;
        expiresAt = _addCalendarMonths(base, plan.durationMonths);
      } else {
        // For new subscription: start from now using calendar months
        expiresAt = _addCalendarMonths(now, plan.durationMonths);
      }
      
      final graceUntil = expiresAt.add(const Duration(days: 7));

      // Create pending subscription
      final subResponse = await _supabase
          .from('subscriptions')
          .insert({
            'user_id': userId,
            'plan_id': planId,
            'price_per_month': pricePerMonth,
            'total_amount': totalAmount,
            'discount_applied': discountApplied,
            'is_early_adopter': isEarlyAdopter,
            'status': 'pending_payment',
            'expires_at': expiresAt.toIso8601String(),
            'grace_until': graceUntil.toIso8601String(),
            'payment_gateway': 'bcl_my',
            'payment_reference': orderId,
            'payment_status': 'pending',
            'auto_renew': true, // PHASE 8: Enable auto-renewal by default
          })
          .select('id')
          .single();

      final subscriptionId = (subResponse as Map<String, dynamic>)['id'] as String;

      // Create pending payment record
      await _supabase.from('subscription_payments').insert({
        'subscription_id': subscriptionId,
        'user_id': userId,
        'amount': totalAmount,
        'currency': 'MYR',
        'payment_gateway': paymentGateway,
        'payment_reference': orderId,
        'status': 'pending',
      });

      return subscriptionId;
    } catch (e) {
      throw Exception('Failed to create pending payment session: $e');
    }
  }

  /// Activate pending subscription when payment succeeds
  Future<Subscription> activatePendingPayment({
    required String orderId,
    String? gatewayTransactionId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // First try: Fetch pending subscription by payment_reference (our order_id)
      var pending = await _supabase
          .from('subscriptions')
          .select()
          .eq('payment_reference', orderId)
          .eq('user_id', userId)
          .eq('status', 'pending_payment')
          .maybeSingle();

      // Fallback: If not found by payment_reference, try to find latest pending payment for this user
      // This handles cases where BCL.my generates its own order number
      if (pending == null) {
        print('⚠️ Payment reference $orderId not found, trying to find latest pending payment for user');
        
        // Find latest pending subscription for this user
        final latestPending = await _supabase
            .from('subscriptions')
            .select()
            .eq('user_id', userId)
            .eq('status', 'pending_payment')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        
        if (latestPending != null) {
          pending = latestPending;
          print('✅ Found latest pending subscription: ${pending['id']}');
          
          // Update payment_reference to match BCL.my order number for future reference
          await _supabase
              .from('subscriptions')
              .update({
                'payment_reference': orderId,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', pending['id'] as String);
          
          // Also update payment record if exists
          final paymentUpdate = await _supabase
              .from('subscription_payments')
              .update({
                'payment_reference': orderId,
                'gateway_transaction_id': gatewayTransactionId,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('subscription_id', pending['id'] as String)
              .eq('status', 'pending')
              .order('created_at', ascending: false)
              .limit(1);
        }
      }

      if (pending == null) {
        throw Exception('No pending subscription found for order $orderId');
      }

      final pendingData = pending as Map<String, dynamic>;
      final planId = pendingData['plan_id'] as String;
      final plan = await getPlanById(planId);
      final pricePerMonth = (pendingData['price_per_month'] as num).toDouble();
      final totalAmount = (pendingData['total_amount'] as num).toDouble();

      final now = DateTime.now();
      final pendingExpiresAt = DateTime.parse(pendingData['expires_at'] as String);
      
      // Check if this is an extend payment by checking if user has active subscription
      // and pending expires_at is after current subscription's expires_at
      final existingActive = await _supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();
      
      DateTime expiresAt;
      DateTime graceUntil;
      bool isExtend = false;
      
      if (existingActive != null) {
        final currentExpiresAt = DateTime.parse(existingActive['expires_at'] as String);
        // If pending expires_at is after current expires_at, this is an extend
        isExtend = pendingExpiresAt.isAfter(currentExpiresAt);
        
        if (isExtend) {
          // For extend: use the calculated expiry date from pending subscription
          // This was already calculated in createPendingPaymentSession by adding to current expiry
          expiresAt = pendingExpiresAt;
          graceUntil = expiresAt.add(const Duration(days: 7));
          // Update existing subscription expiry date
          final updated = await _supabase
              .from('subscriptions')
              .update({
                'expires_at': expiresAt.toIso8601String(),
                'grace_until': graceUntil.toIso8601String(),
                'payment_status': 'completed',
                'payment_completed_at': now.toIso8601String(),
                'payment_reference': orderId,
                'updated_at': now.toIso8601String(),
              })
              .eq('id', existingActive['id'] as String)
              .select('''
                *,
                subscription_plans:plan_id (
                  name,
                  duration_months
                )
              ''')
              .single();
          
          // Delete pending subscription (we're extending existing one)
          await _supabase
              .from('subscriptions')
              .delete()
              .eq('id', pendingData['id'] as String);
          
          // Update payment record to point to existing subscription
          await _supabase
              .from('subscription_payments')
              .update({
                'subscription_id': existingActive['id'] as String,
              })
              .eq('payment_reference', orderId)
              .eq('status', 'pending');
          
          final json = updated as Map<String, dynamic>;
          final planData = json['subscription_plans'] as Map<String, dynamic>?;
          if (planData != null) {
            json['plan_name'] = planData['name'] as String? ?? 'PocketBizz Pro';
            json['duration_months'] = planData['duration_months'] as int? ?? plan.durationMonths;
          }
          
          // Update payment record to completed
          var paymentUpdate = await _supabase
              .from('subscription_payments')
              .update({
                'status': 'completed',
                'paid_at': now.toIso8601String(),
                'gateway_transaction_id': gatewayTransactionId,
                'payment_reference': orderId,
              })
              .eq('payment_reference', orderId)
              .eq('status', 'pending')
              .select('id')
              .maybeSingle();
          
          if (paymentUpdate == null) {
            throw Exception('No pending payment found to update');
          }
          
          final paymentId = (paymentUpdate as Map<String, dynamic>?)?['id'] as String?;
          if (paymentId == null) {
            throw Exception('Failed to get payment ID after update');
          }
          
          final subscription = Subscription.fromJson(json);
          
          // Generate receipt
          _generateAndUploadReceipt(
            subscription: subscription,
            plan: plan,
            paymentReference: orderId,
            gatewayTransactionId: gatewayTransactionId,
            amount: totalAmount,
            paidAt: now,
            paymentId: paymentId,
          ).catchError((e) {
            print('⚠️ Failed to generate receipt (non-critical): $e');
          });
          
          // Send email
          await _sendEmailNotification(
            subject: 'Tempoh Langganan Dipanjangkan',
            html:
                '<p>Terima kasih, tempoh langganan anda telah dipanjangkan.</p><p>Tempoh baharu: ${plan.durationMonths} bulan</p><p>Jumlah: RM ${totalAmount.toStringAsFixed(2)}</p><p>Tarikh tamat baharu: ${expiresAt.toIso8601String()}</p>',
            type: 'subscription_extended',
            meta: {
              'payment_reference': orderId,
              'subscription_id': subscription.id,
              'plan_id': planId,
              'amount': totalAmount,
              'new_expires_at': expiresAt.toIso8601String(),
            },
          );
          
          return subscription;
        }
      }
      
      // For new subscription (not extend): calculate from now using calendar months
      expiresAt = _addCalendarMonths(now, plan.durationMonths);
      graceUntil = expiresAt.add(const Duration(days: 7));

      // Expire any existing active/trial for this user (to satisfy unique index)
      await _supabase
          .from('subscriptions')
          .update({
            'status': 'expired',
            'updated_at': now.toIso8601String(),
          })
          .eq('user_id', userId)
          .inFilter('status', ['trial', 'active']);

      // Activate pending subscription
      final updated = await _supabase
          .from('subscriptions')
          .update({
            'status': 'active',
            'started_at': now.toIso8601String(),
            'expires_at': expiresAt.toIso8601String(),
            'grace_until': graceUntil.toIso8601String(),
            'payment_status': 'completed',
            'payment_completed_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', pendingData['id'] as String)
          .select('''
            *,
            subscription_plans:plan_id (
              name,
              duration_months
            )
          ''')
          .single();

      // Update payment record to completed and get payment ID
      // Try by payment_reference first, then by subscription_id if not found
      var paymentUpdate = await _supabase
          .from('subscription_payments')
          .update({
            'status': 'completed',
            'paid_at': now.toIso8601String(),
            'gateway_transaction_id': gatewayTransactionId,
            'payment_reference': orderId, // Update to BCL.my order number
          })
          .eq('payment_reference', orderId)
          .select('id')
          .maybeSingle();
      
      // Fallback: Find by subscription_id if not found by payment_reference
      if (paymentUpdate == null) {
        paymentUpdate = await _supabase
            .from('subscription_payments')
            .update({
              'status': 'completed',
              'paid_at': now.toIso8601String(),
              'gateway_transaction_id': gatewayTransactionId,
              'payment_reference': orderId, // Update to BCL.my order number
            })
            .eq('subscription_id', pendingData['id'] as String)
            .eq('status', 'pending')
            .order('created_at', ascending: false)
            .limit(1)
            .select('id')
            .maybeSingle();
      }
      
      if (paymentUpdate == null) {
        throw Exception('No pending payment found to update');
      }

      final paymentId = (paymentUpdate as Map<String, dynamic>?)?['id'] as String?;
      if (paymentId == null) {
        throw Exception('Failed to get payment ID after update');
      }

      final json = updated as Map<String, dynamic>;
      final planData = json['subscription_plans'] as Map<String, dynamic>?;
      if (planData != null) {
        json['plan_name'] = planData['name'] as String? ?? 'PocketBizz Pro';
        json['duration_months'] = planData['duration_months'] as int? ?? plan.durationMonths;
      }

      // Generate and upload receipt (non-blocking)
      final subscription = Subscription.fromJson(json);
      _generateAndUploadReceipt(
        subscription: subscription,
        plan: plan,
        paymentReference: orderId,
        gatewayTransactionId: gatewayTransactionId,
        amount: (pendingData['total_amount'] as num).toDouble(),
        paidAt: now,
        paymentId: paymentId,
      ).catchError((e) {
        // Log error but don't fail subscription activation
        print('⚠️ Failed to generate receipt (non-critical): $e');
      });

      // Send payment success email
      await _sendEmailNotification(
        subject: 'Pembayaran Berjaya',
        html:
            '<p>Terima kasih, pembayaran anda telah diterima.</p><p>Pelan: ${plan.name} (${plan.durationMonths} bulan)</p><p>Jumlah: RM ${totalAmount.toStringAsFixed(2)}</p>',
        type: 'payment_success',
        meta: {
          'payment_reference': orderId,
          'subscription_id': subscription.id,
          'plan_id': planId,
          'amount': totalAmount,
        },
      );

      return subscription;
    } catch (e) {
      throw Exception('Failed to activate pending payment: $e');
    }
  }

  /// Generate PDF receipt and upload to Supabase Storage
  /// Updates subscription_payments.receipt_url after upload
  Future<void> _generateAndUploadReceipt({
    required Subscription subscription,
    required SubscriptionPlan plan,
    required String paymentReference,
    String? gatewayTransactionId,
    required double amount,
    required DateTime paidAt,
    required String paymentId,
  }) async {
    try {
      // Get user info
      final user = _supabase.auth.currentUser;
      final userEmail = user?.email;
      final userName = user?.userMetadata?['full_name'] as String?;

      // Generate PDF receipt (uses fixed PocketBizz/BNI Digital Enterprise info in header)
      final pdfBytes = await PDFGenerator.generateSubscriptionReceipt(
        paymentReference: paymentReference,
        planName: subscription.planName,
        durationMonths: subscription.durationMonths,
        amount: amount,
        paidAt: paidAt,
        paymentGateway: subscription.paymentGateway ?? 'bcl_my',
        gatewayTransactionId: gatewayTransactionId,
        userEmail: userEmail,
        userName: userName,
        isEarlyAdopter: subscription.isEarlyAdopter,
      );

      // Upload to Supabase Storage
      final fileName = 'subscription_receipt_${paymentReference}_${DateFormat('yyyyMMdd').format(paidAt)}.pdf';
      final uploadResult = await DocumentStorageService.uploadDocument(
        pdfBytes: pdfBytes,
        fileName: fileName,
        documentType: 'subscription_receipt',
        relatedEntityType: 'subscription',
        relatedEntityId: subscription.id,
      );

      // Update payment record with receipt URL
      await _supabase
          .from('subscription_payments')
          .update({
            'receipt_url': uploadResult['url'],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', paymentId);

      print('✅ Subscription receipt generated and uploaded: ${uploadResult['url']}');
    } catch (e) {
      print('❌ Failed to generate subscription receipt: $e');
      rethrow;
    }
  }

  /// Get payment history for current user
  Future<List<SubscriptionPayment>> getPaymentHistory() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('subscription_payments')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50); // Limit to last 50 payments

      return (response as List)
          .map((json) {
            try {
              return SubscriptionPayment.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              print('Error parsing payment history item: $e');
              return null;
            }
          })
          .whereType<SubscriptionPayment>()
          .toList();
    } catch (e) {
      print('Error fetching payment history: $e');
      throw Exception('Failed to fetch payment history: $e');
    }
  }

  /// Get payment history for specific subscription
  Future<List<SubscriptionPayment>> getSubscriptionPayments(String subscriptionId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('subscription_payments')
          .select()
          .eq('subscription_id', subscriptionId)
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => SubscriptionPayment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch subscription payments: $e');
    }
  }

  /// Retry a failed/pending payment by creating a new payment reference/order
  Future<RetryPaymentResult> retryPayment({
    required SubscriptionPayment payment,
    String? paymentGateway,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Fetch subscription to get plan/duration
      final subscriptionResp = await _supabase
          .from('subscriptions')
          .select()
          .eq('id', payment.subscriptionId)
          .eq('user_id', userId)
          .maybeSingle();

      if (subscriptionResp == null) {
        throw Exception('Subscription not found for retry');
      }

      final subscriptionData = subscriptionResp as Map<String, dynamic>;
      final planId = subscriptionData['plan_id'] as String;
      final plan = await getPlanById(planId);
      final amount = (subscriptionData['total_amount'] as num).toDouble();
      final now = DateTime.now();
      final nowIso = now.toIso8601String();
      final newOrderId = 'PBZ-${const Uuid().v4()}';
      final selectedGateway = paymentGateway ?? payment.paymentGateway;

      // Check retry limit (max 5 attempts)
      if (payment.retryCount >= 5) {
        throw Exception(
          'Maximum retry attempts (5) reached. '
          'Please contact support for assistance.'
        );
      }

      // Update previous payment with retry tracking
      await _supabase.from('subscription_payments').update({
        'retry_count': payment.retryCount + 1,
        'last_retry_at': nowIso,
        'updated_at': nowIso,
      }).eq('id', payment.id);

      // Insert a new pending payment record with new reference
      await _supabase.from('subscription_payments').insert({
        'subscription_id': payment.subscriptionId,
        'user_id': userId,
        'amount': amount,
        'currency': payment.currency,
        'payment_gateway': selectedGateway,
        'payment_reference': newOrderId,
        'status': 'pending',
      });

      // Point subscription to new payment reference
      await _supabase.from('subscriptions').update({
        'payment_reference': newOrderId,
        'payment_status': 'pending',
        'status': 'pending_payment',
        'updated_at': nowIso,
      }).eq('id', payment.subscriptionId);

      return RetryPaymentResult(
        orderId: newOrderId,
        durationMonths: plan.durationMonths,
        planId: planId,
        paymentGateway: selectedGateway,
      );
    } catch (e) {
      throw Exception('Failed to retry payment: $e');
    }
  }

  /// Get proration quote for changing plan
  Future<ProrationQuote> getProrationQuote({
    required String targetPlanId,
  }) async {
    final current = await getUserSubscription();
    if (current == null) {
      throw Exception('No active subscription to change');
    }
    final plan = await getPlanById(targetPlanId);
    final isEarlyAdopterFlag = await isEarlyAdopter();
    final pricePerMonth = isEarlyAdopterFlag ? 29.0 : plan.pricePerMonth;
    final newTotal = isEarlyAdopterFlag ? plan.getPriceForEarlyAdopter() : plan.totalPrice;

    final remainingDays = _remainingPaidDays(current);
    // Calculate actual subscription duration (calendar-based, not fixed 30 days)
    final startDate = current.startedAt ?? current.createdAt;
    final totalDays = current.expiresAt.difference(startDate).inDays;
    final perDayCurrent = totalDays > 0 ? current.totalAmount / totalDays : current.totalAmount;
    final credit = (perDayCurrent * remainingDays).clamp(0, current.totalAmount);
    final amountDue = (newTotal - credit).clamp(0, double.maxFinite);

    return ProrationQuote(
      creditApplied: credit.toDouble(),
      amountDue: amountDue.toDouble(),
      newTotal: newTotal,
      durationMonths: plan.durationMonths,
      planId: targetPlanId,
      planName: plan.name,
      pricePerMonth: pricePerMonth,
      isEarlyAdopter: isEarlyAdopterFlag,
    );
  }

  /// Start plan change with proration
  /// If amountDue > 0 -> creates pending payment with new order id
  /// If amountDue == 0 -> immediately activates new subscription
  Future<ProrationResult> changePlanProrated({
    required String targetPlanId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final current = await getUserSubscription();
    if (current == null) throw Exception('No active subscription to change');

    final quote = await getProrationQuote(targetPlanId: targetPlanId);
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final newOrderId = 'PBZ-${const Uuid().v4()}';
    final isDowngradeOrSidegrade = quote.newTotal <= current.totalAmount;

    // Expire current active/trial/grace to respect unique index before new activation
    Future<void> _expireCurrent() async {
      await _supabase
          .from('subscriptions')
          .update({
            'status': 'expired',
            'updated_at': nowIso,
          })
          .eq('user_id', userId)
          .inFilter('status', ['trial', 'active', 'grace']);
    }

    if (quote.amountDue == 0) {
      // No charge. If downgrade/sidegrade, schedule at next cycle end; else activate now.
      if (isDowngradeOrSidegrade) {
        final scheduledStart = current.expiresAt;
        final expiresAt = _addCalendarMonths(scheduledStart, quote.durationMonths);
        final graceUntil = expiresAt.add(const Duration(days: 7));

        final response = await _supabase
            .from('subscriptions')
            .insert({
              'user_id': userId,
              'plan_id': quote.planId,
              'price_per_month': quote.pricePerMonth,
              'total_amount': quote.newTotal,
              'discount_applied': (quote.pricePerMonth * quote.durationMonths) - quote.newTotal,
              'is_early_adopter': quote.isEarlyAdopter,
              // using pending_payment but already paid, will auto-activate at start
              'status': 'pending_payment',
              'started_at': scheduledStart.toIso8601String(),
              'expires_at': expiresAt.toIso8601String(),
              'grace_until': graceUntil.toIso8601String(),
              'payment_gateway': 'bcl_my',
              'payment_reference': 'PRORATE-SCHEDULED-$newOrderId',
              'payment_status': 'completed',
              'payment_completed_at': nowIso,
              'auto_renew': true, // PHASE 8: Enable auto-renewal by default
            })
            .select('id')
            .single();

        final newSubscriptionId = (response as Map<String, dynamic>)['id'] as String;

        await _supabase.from('subscription_payments').insert({
          'subscription_id': newSubscriptionId,
          'user_id': userId,
          'amount': 0,
          'currency': 'MYR',
          'payment_gateway': 'bcl_my',
          'payment_reference': 'PRORATE-SCHEDULED-$newOrderId',
          'status': 'completed',
          'paid_at': nowIso,
        });

        await _sendEmailNotification(
          subject: 'Tukar Pelan Dijadualkan',
          html:
              '<p>Permintaan tukar pelan anda telah dijadualkan pada akhir kitaran semasa.</p><p>Pelan baharu: ${quote.planName} (${quote.durationMonths} bulan)</p><p>Tarikh mula: ${scheduledStart.toIso8601String()}</p>',
          type: 'plan_change_scheduled',
          meta: {
            'subscription_id': newSubscriptionId,
            'plan_id': quote.planId,
            'scheduled_start': scheduledStart.toIso8601String(),
          },
        );

        return ProrationResult(
          amountDue: 0,
          orderId: null,
          durationMonths: quote.durationMonths,
          planId: quote.planId,
          paymentGateway: 'bcl_my',
          newSubscriptionId: newSubscriptionId,
          scheduled: true,
          scheduledStart: scheduledStart,
        );
      }

      // No charge and upgrade: directly activate now
      await _expireCurrent();

      final expiresAt = _addCalendarMonths(now, quote.durationMonths);
      final graceUntil = expiresAt.add(const Duration(days: 7));

      final response = await _supabase
          .from('subscriptions')
          .insert({
            'user_id': userId,
            'plan_id': quote.planId,
            'price_per_month': quote.pricePerMonth,
            'total_amount': quote.newTotal,
            'discount_applied': (quote.pricePerMonth * quote.durationMonths) - quote.newTotal,
            'is_early_adopter': quote.isEarlyAdopter,
            'status': 'active',
            'started_at': nowIso,
            'expires_at': expiresAt.toIso8601String(),
            'grace_until': graceUntil.toIso8601String(),
            'payment_gateway': 'bcl_my',
            'payment_reference': 'PRORATE-NOCHARGE-$newOrderId',
            'payment_status': 'completed',
            'payment_completed_at': nowIso,
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
        json['plan_name'] = planData['name'] as String? ?? quote.planName;
        json['duration_months'] = planData['duration_months'] as int? ?? quote.durationMonths;
      }

      // Record zero-amount payment for audit
      await _supabase.from('subscription_payments').insert({
        'subscription_id': json['id'],
        'user_id': userId,
        'amount': 0,
        'currency': 'MYR',
        'payment_gateway': 'bcl_my',
        'payment_reference': 'PRORATE-NOCHARGE-$newOrderId',
        'status': 'completed',
        'paid_at': nowIso,
      });

      return ProrationResult(
        amountDue: 0,
        orderId: null,
        durationMonths: quote.durationMonths,
        planId: quote.planId,
        paymentGateway: 'bcl_my',
        newSubscriptionId: json['id'] as String,
      );
    }

    // amountDue > 0: create pending payment session for proration
    final plan = await getPlanById(targetPlanId);
    final discountApplied = (quote.pricePerMonth * plan.durationMonths) - quote.newTotal;
    final pendingExpiresAt = _addCalendarMonths(now, plan.durationMonths);
    final pendingGraceUntil = pendingExpiresAt.add(const Duration(days: 7));

    await _expireCurrent();

    final subResponse = await _supabase
        .from('subscriptions')
        .insert({
          'user_id': userId,
          'plan_id': targetPlanId,
          'price_per_month': quote.pricePerMonth,
          'total_amount': quote.newTotal,
          'discount_applied': discountApplied,
          'is_early_adopter': quote.isEarlyAdopter,
          'status': 'pending_payment',
          'expires_at': pendingExpiresAt.toIso8601String(),
          'grace_until': pendingGraceUntil.toIso8601String(),
          'payment_gateway': 'bcl_my',
          'payment_reference': newOrderId,
          'payment_status': 'pending',
          'auto_renew': false,
        })
        .select('id')
        .single();

    final newSubscriptionId = (subResponse as Map<String, dynamic>)['id'] as String;

    await _supabase.from('subscription_payments').insert({
        'subscription_id': newSubscriptionId,
        'user_id': userId,
        'amount': quote.amountDue,
        'currency': 'MYR',
        'payment_gateway': 'bcl_my',
        'payment_reference': newOrderId,
        'status': 'pending',
    });

    return ProrationResult(
      amountDue: quote.amountDue,
      orderId: newOrderId,
      durationMonths: quote.durationMonths,
      planId: targetPlanId,
      paymentGateway: 'bcl_my',
      newSubscriptionId: newSubscriptionId,
    );
  }

  int _remainingPaidDays(Subscription current) {
    final now = DateTime.now();
    final end = current.expiresAt;
    final diff = end.difference(now).inDays;
    return diff > 0 ? diff : 0;
  }

  Future<void> _sendEmailNotification({
    required String subject,
    required String html,
    String? to,
    String type = 'payment_success',
    Map<String, dynamic>? meta,
  }) async {
    final user = _supabase.auth.currentUser;
    final userId = user?.id;
    final targetEmail = to ?? user?.email;
    if (userId == null || targetEmail == null) return;

    String status = 'sent';
    String? error;
    try {
      await _supabase.functions.invoke(
        'resend-email',
        body: {
          'to': targetEmail,
          'subject': subject,
          'html': html,
        },
      );
    } catch (e) {
      status = 'failed';
      error = e.toString();
    } finally {
      try {
        await _supabase.from('notification_logs').insert({
          'user_id': userId,
          'channel': 'email',
          'type': type,
          'status': status,
          'subject': subject,
          'payload': meta != null ? jsonEncode(meta) : null,
          'error': error,
        });
      } catch (_) {
        // ignore logging errors
      }
    }
  }

  Future<void> _sendPaymentFailedEmail({
    required SubscriptionPayment payment,
    String? reason,
  }) async {
    // Fetch subscription + plan for context
    try {
      final subResp = await _supabase
          .from('subscriptions')
          .select('''
            *,
            subscription_plans:plan_id (name, duration_months)
          ''')
          .eq('id', payment.subscriptionId)
          .maybeSingle();

      final planName = (subResp?['subscription_plans']?['name'] as String?) ?? 'Pelan PocketBizz';
      final duration =
          (subResp?['subscription_plans']?['duration_months'] as int?) ?? 0;

      final amount = payment.amount.toStringAsFixed(2);
      final html = '''
        <p>Maaf, pembayaran anda gagal diproses.</p>
        <p>Pelan: $planName (${duration > 0 ? '$duration bulan' : ''})</p>
        <p>Jumlah: RM $amount</p>
        ${reason != null ? '<p>Sebab: $reason</p>' : ''}
        <p>Sila cuba bayar semula melalui aplikasi.</p>
      ''';

      await _sendEmailNotification(
        subject: 'Pembayaran Gagal',
        html: html,
        type: 'payment_failed',
        meta: {
          'payment_id': payment.id,
          'subscription_id': payment.subscriptionId,
          'amount': payment.amount,
          'reason': reason,
        },
      );
    } catch (e) {
      // ignore failure to fetch plan; still try to send generic email
      await _sendEmailNotification(
        subject: 'Pembayaran Gagal',
        html:
            '<p>Maaf, pembayaran anda gagal diproses.</p><p>Sila cuba bayar semula melalui aplikasi.</p>',
        type: 'payment_failed',
        meta: {
          'payment_id': payment.id,
          'subscription_id': payment.subscriptionId,
          'amount': payment.amount,
          'reason': reason,
        },
      );
    }
  }

  /// Subscribe to payment status changes for the current user
  RealtimeChannel? subscribePaymentStatus(
      void Function(SubscriptionPayment) onChange) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final channel =
        _supabase.channel('subscription_payments_status_${userId.hashCode}');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'subscription_payments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final data = payload.newRecord ?? payload.oldRecord;
            if (data is Map<String, dynamic>) {
              try {
                final payment = SubscriptionPayment.fromJson(data);
                onChange(payment);
              } catch (_) {}
            }
          },
        )
        .subscribe();

    return channel;
  }

  // Exposed for service layer
  Future<void> sendPaymentFailedEmail({
    required SubscriptionPayment payment,
    String? reason,
  }) {
    return _sendPaymentFailedEmail(payment: payment, reason: reason);
  }

  // ============================================================================
  // ADMIN METHODS
  // ============================================================================

  /// Get subscription statistics for admin dashboard
  Future<Map<String, dynamic>> getAdminSubscriptionStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startIso = startDate.toIso8601String();
      final endIso = endDate.toIso8601String();

      // Total subscriptions
      final totalResp = await _supabase
          .from('subscriptions')
          .select('id')
          .gte('created_at', startIso)
          .lte('created_at', endIso);

      // Active subscriptions
      final activeResp = await _supabase
          .from('subscriptions')
          .select('id')
          .inFilter('status', ['trial', 'active', 'grace'])
          .gte('created_at', startIso)
          .lte('created_at', endIso);

      return {
        'total': (totalResp as List).length,
        'active': (activeResp as List).length,
      };
    } catch (e) {
      throw Exception('Failed to get subscription stats: $e');
    }
  }

  /// Get revenue statistics for admin dashboard
  Future<Map<String, dynamic>> getAdminRevenueStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startIso = startDate.toIso8601String();
      final endIso = endDate.toIso8601String();

      // Total revenue (completed payments)
      final totalResp = await _supabase
          .from('subscription_payments')
          .select('amount')
          .eq('status', 'completed')
          .gte('paid_at', startIso)
          .lte('paid_at', endIso);

      double total = 0.0;
      if (totalResp is List) {
        for (final payment in totalResp) {
          total += ((payment as Map<String, dynamic>)['amount'] as num).toDouble();
        }
      }

      // Monthly revenue (current month)
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);

      final monthlyResp = await _supabase
          .from('subscription_payments')
          .select('amount')
          .eq('status', 'completed')
          .gte('paid_at', monthStart.toIso8601String())
          .lte('paid_at', monthEnd.toIso8601String());

      double monthly = 0.0;
      if (monthlyResp is List) {
        for (final payment in monthlyResp) {
          monthly += ((payment as Map<String, dynamic>)['amount'] as num).toDouble();
        }
      }

      return {
        'total': total,
        'monthly': monthly,
      };
    } catch (e) {
      throw Exception('Failed to get revenue stats: $e');
    }
  }

  /// Get payment statistics for admin dashboard
  Future<Map<String, dynamic>> getAdminPaymentStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startIso = startDate.toIso8601String();
      final endIso = endDate.toIso8601String();

      // Total payments
      final totalResp = await _supabase
          .from('subscription_payments')
          .select('id, status')
          .gte('created_at', startIso)
          .lte('created_at', endIso);

      final total = (totalResp as List).length;

      // Successful payments
      final successResp = await _supabase
          .from('subscription_payments')
          .select('id')
          .eq('status', 'completed')
          .gte('created_at', startIso)
          .lte('created_at', endIso);

      final success = (successResp as List).length;
      final successRate = total > 0 ? (success / total * 100) : 0.0;

      return {
        'total': total,
        'success': success,
        'failed': total - success,
        'success_rate': successRate,
      };
    } catch (e) {
      throw Exception('Failed to get payment stats: $e');
    }
  }

  /// Get all subscriptions for admin (with filters)
  Future<List<Subscription>> getAdminSubscriptions({
    String? status,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      var query = _supabase
          .from('subscriptions')
          .select('''
            *,
            subscription_plans:plan_id (
              name,
              duration_months
            )
          ''');

      if (status != null) {
        query = query.eq('status', status);
      }
      if (userId != null) {
        query = query.eq('user_id', userId);
      }
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) {
            final data = json as Map<String, dynamic>;
            final planData = data['subscription_plans'] as Map<String, dynamic>?;
            if (planData != null) {
              data['plan_name'] = planData['name'] as String? ?? 'PocketBizz Pro';
              data['duration_months'] = planData['duration_months'] as int? ?? 1;
            }
            return Subscription.fromJson(data);
          })
          .toList();
    } catch (e) {
      throw Exception('Failed to get admin subscriptions: $e');
    }
  }

  // ============================================================================
  // PAUSE/RESUME METHODS
  // ============================================================================

  /// Pause a subscription (extends expiry date by pause duration)
  Future<Subscription> pauseSubscription({
    required String subscriptionId,
    required int daysToPause,
    String? reason,
    DateTime? pausedUntil,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Fetch subscription
      final subResp = await _supabase
          .from('subscriptions')
          .select()
          .eq('id', subscriptionId)
          .maybeSingle();

      if (subResp == null) {
        throw Exception('Subscription not found');
      }

      final subData = subResp as Map<String, dynamic>;
      final currentExpiresAt = DateTime.parse(subData['expires_at'] as String);
      final now = DateTime.now();
      final nowIso = now.toIso8601String();

      // Calculate new expiry date (extend by pause duration)
      final newExpiresAt = currentExpiresAt.add(Duration(days: daysToPause));
      final pauseUntil = pausedUntil ?? now.add(Duration(days: daysToPause));

      // Update subscription
      final updated = await _supabase
          .from('subscriptions')
          .update({
            'is_paused': true,
            'paused_at': nowIso,
            'paused_until': pauseUntil.toIso8601String(),
            'pause_reason': reason,
            'paused_days': daysToPause,
            'expires_at': newExpiresAt.toIso8601String(),
            'status': 'paused',
            'updated_at': nowIso,
          })
          .eq('id', subscriptionId)
          .select('''
            *,
            subscription_plans:plan_id (
              name,
              duration_months
            )
          ''')
          .single();

      final json = updated as Map<String, dynamic>;
      final planData = json['subscription_plans'] as Map<String, dynamic>?;
      if (planData != null) {
        json['plan_name'] = planData['name'] as String? ?? 'PocketBizz Pro';
        json['duration_months'] = planData['duration_months'] as int? ?? 1;
      }

      return Subscription.fromJson(json);
    } catch (e) {
      throw Exception('Failed to pause subscription: $e');
    }
  }

  /// Resume a paused subscription
  Future<Subscription> resumeSubscription(String subscriptionId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Fetch subscription
      final subResp = await _supabase
          .from('subscriptions')
          .select()
          .eq('id', subscriptionId)
          .maybeSingle();

      if (subResp == null) {
        throw Exception('Subscription not found');
      }

      final subData = subResp as Map<String, dynamic>;
      final now = DateTime.now();
      final nowIso = now.toIso8601String();
      final pausedDays = subData['paused_days'] as int? ?? 0;
      final originalExpiresAt = DateTime.parse(subData['expires_at'] as String);

      // Calculate remaining days (subtract paused days from expiry)
      // Since we already extended expiry when pausing, we just need to reactivate
      final status = originalExpiresAt.isAfter(now) ? 'active' : 'expired';

      // Update subscription
      final updated = await _supabase
          .from('subscriptions')
          .update({
            'is_paused': false,
            'paused_at': null,
            'paused_until': null,
            'pause_reason': null,
            'status': status,
            'updated_at': nowIso,
          })
          .eq('id', subscriptionId)
          .select('''
            *,
            subscription_plans:plan_id (
              name,
              duration_months
            )
          ''')
          .single();

      final json = updated as Map<String, dynamic>;
      final planData = json['subscription_plans'] as Map<String, dynamic>?;
      if (planData != null) {
        json['plan_name'] = planData['name'] as String? ?? 'PocketBizz Pro';
        json['duration_months'] = planData['duration_months'] as int? ?? 1;
      }

      return Subscription.fromJson(json);
    } catch (e) {
      throw Exception('Failed to resume subscription: $e');
    }
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
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Fetch payment
      final paymentResp = await _supabase
          .from('subscription_payments')
          .select('''
            *,
            subscriptions:subscription_id (
              id,
              user_id,
              payment_gateway
            )
          ''')
          .eq('id', paymentId)
          .maybeSingle();

      if (paymentResp == null) {
        throw Exception('Payment not found');
      }

      final paymentData = paymentResp as Map<String, dynamic>;
      final subscriptionData = paymentData['subscriptions'] as Map<String, dynamic>?;
      final subscriptionId = subscriptionData?['id'] as String?;
      final gateway = paymentData['payment_gateway'] as String? ?? 'bcl_my';
      final amount = (paymentData['amount'] as num).toDouble();
      final finalRefundAmount = fullRefund ? amount : refundAmount;

      if (finalRefundAmount > amount) {
        throw Exception('Refund amount cannot exceed payment amount');
      }

      final now = DateTime.now();
      final nowIso = now.toIso8601String();
      final refundRef = 'REF-${DateTime.now().millisecondsSinceEpoch}';

      // TODO: Call BCL.my refund API or gateway refund endpoint
      // For now, we'll just update the database
      // In production, you need to integrate with BCL.my refund API

      // Update payment record
      await _supabase
          .from('subscription_payments')
          .update({
            'status': fullRefund ? 'refunded' : 'refunding',
            'refunded_amount': finalRefundAmount,
            'refunded_at': nowIso,
            'refund_reason': reason,
            'refund_reference': refundRef,
            'updated_at': nowIso,
          })
          .eq('id', paymentId);

      // Create refund record
      final refundResp = await _supabase
          .from('subscription_refunds')
          .insert({
            'payment_id': paymentId,
            'subscription_id': subscriptionId,
            'user_id': subscriptionData?['user_id'] as String?,
            'refund_amount': finalRefundAmount,
            'currency': 'MYR',
            'refund_reason': reason,
            'payment_gateway': gateway,
            'refund_reference': refundRef,
            'status': 'completed', // TODO: Set to 'processing' if async
            'processed_by': userId,
          })
          .select()
          .single();

      // If full refund, update subscription status
      if (fullRefund && subscriptionId != null) {
        await _supabase
            .from('subscriptions')
            .update({
              'status': 'cancelled',
              'payment_status': 'refunded',
              'updated_at': nowIso,
            })
            .eq('id', subscriptionId);
      }

      return {
        'success': true,
        'refund_id': (refundResp as Map<String, dynamic>)['id'] as String,
        'refund_reference': refundRef,
        'refund_amount': finalRefundAmount,
      };
    } catch (e) {
      throw Exception('Failed to process refund: $e');
    }
  }

  // ============================================================================
  // ADMIN MANUAL OPERATIONS
  // ============================================================================

  /// Manually activate subscription for a user (admin only)
  /// Used as backup when payment gateway fails
  Future<Subscription> manualActivateSubscription({
    required String userId,
    required String planId,
    required int durationMonths,
    String? notes,
  }) async {
    try {
      // Get plan details
      final planResponse = await _supabase
          .from('subscription_plans')
          .select()
          .eq('id', planId)
          .single();

      final plan = SubscriptionPlan.fromJson(planResponse as Map<String, dynamic>);

      // Check early adopter status for the user
      final earlyAdopterResp = await _supabase
          .from('early_adopters')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      final isEarlyAdopter = earlyAdopterResp != null;
      final pricePerMonth = isEarlyAdopter ? 29.0 : 39.0;
      
      // Calculate total based on duration
      final calculatedTotal = isEarlyAdopter
          ? plan.getPriceForEarlyAdopter() * (durationMonths / plan.durationMonths)
          : plan.totalPrice * (durationMonths / plan.durationMonths);
      
      final discountApplied = (pricePerMonth * durationMonths) - calculatedTotal;

      // Calculate expiry date using calendar months
      final now = DateTime.now();
      final expiresAt = _addCalendarMonths(now, durationMonths);
      final graceUntil = expiresAt.add(const Duration(days: 7));
      final nowIso = now.toIso8601String();

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
            'started_at': nowIso,
            'expires_at': expiresAt.toIso8601String(),
            'grace_until': graceUntil.toIso8601String(),
            'payment_gateway': 'manual',
            'payment_reference': 'MANUAL-${DateTime.now().millisecondsSinceEpoch}',
            'payment_status': 'completed',
            'payment_completed_at': nowIso,
            'auto_renew': true, // PHASE 8: Enable auto-renewal by default (can be disabled by user)
            'notes': notes,
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
        json['duration_months'] = durationMonths;
      }

      // Create payment record
      await _supabase.from('subscription_payments').insert({
        'subscription_id': json['id'] as String,
        'user_id': userId,
        'amount': calculatedTotal,
        'currency': 'MYR',
        'payment_gateway': 'manual',
        'payment_reference': json['payment_reference'] as String,
        'status': 'completed',
        'paid_at': nowIso,
        'notes': notes,
      });

      return Subscription.fromJson(json);
    } catch (e) {
      throw Exception('Failed to manually activate subscription: $e');
    }
  }

  /// Extend subscription expiry date (admin only)
  Future<Subscription> extendSubscription({
    required String subscriptionId,
    required int extensionMonths,
    String? notes,
  }) async {
    try {
      // Fetch subscription
      final subResp = await _supabase
          .from('subscriptions')
          .select('''
            *,
            subscription_plans:plan_id (
              name,
              duration_months
            )
          ''')
          .eq('id', subscriptionId)
          .maybeSingle();

      if (subResp == null) {
        throw Exception('Subscription not found');
      }

      final subData = subResp as Map<String, dynamic>;
      final currentExpiresAt = DateTime.parse(subData['expires_at'] as String);
      final now = DateTime.now();
      final nowIso = now.toIso8601String();

      // Calculate new expiry date using calendar months
      final newExpiresAt = _addCalendarMonths(currentExpiresAt, extensionMonths);
      final newGraceUntil = newExpiresAt.add(const Duration(days: 7));

      // Calculate extension price
      final planData = subData['subscription_plans'] as Map<String, dynamic>?;
      final pricePerMonth = (subData['price_per_month'] as num).toDouble();
      final extensionAmount = pricePerMonth * extensionMonths;

      // Update subscription
      final updated = await _supabase
          .from('subscriptions')
          .update({
            'expires_at': newExpiresAt.toIso8601String(),
            'grace_until': newGraceUntil.toIso8601String(),
            'updated_at': nowIso,
          })
          .eq('id', subscriptionId)
          .select('''
            *,
            subscription_plans:plan_id (
              name,
              duration_months
            )
          ''')
          .single();

      final json = updated as Map<String, dynamic>;
      final updatedPlanData = json['subscription_plans'] as Map<String, dynamic>?;
      if (updatedPlanData != null) {
        json['plan_name'] = updatedPlanData['name'] as String? ?? 'PocketBizz Pro';
      }

      // Create payment record for extension
      await _supabase.from('subscription_payments').insert({
        'subscription_id': subscriptionId,
        'user_id': subData['user_id'] as String,
        'amount': extensionAmount,
        'currency': 'MYR',
        'payment_gateway': 'manual',
        'payment_reference': 'EXTEND-${DateTime.now().millisecondsSinceEpoch}',
        'status': 'completed',
        'paid_at': nowIso,
        'notes': notes ?? 'Subscription extended by $extensionMonths months',
      });

      return Subscription.fromJson(json);
    } catch (e) {
      throw Exception('Failed to extend subscription: $e');
    }
  }

  /// Add manual payment record (admin only)
  Future<Map<String, dynamic>> addManualPayment({
    required String userId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    try {
      final now = DateTime.now();
      final nowIso = now.toIso8601String();

      // Get user's current subscription
      final subResp = await _supabase
          .from('subscriptions')
          .select('id')
          .eq('user_id', userId)
          .inFilter('status', ['trial', 'active', 'grace'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final subscriptionId = subResp != null ? (subResp as Map<String, dynamic>)['id'] as String : null;

      // Create payment record
      final paymentResp = await _supabase
          .from('subscription_payments')
          .insert({
            'subscription_id': subscriptionId,
            'user_id': userId,
            'amount': amount,
            'currency': 'MYR',
            'payment_gateway': paymentMethod,
            'payment_reference': 'MANUAL-PAY-${DateTime.now().millisecondsSinceEpoch}',
            'status': 'completed',
            'paid_at': nowIso,
            'notes': notes,
          })
          .select()
          .single();

      return {
        'success': true,
        'payment_id': (paymentResp as Map<String, dynamic>)['id'] as String,
        'message': 'Manual payment recorded successfully',
      };
    } catch (e) {
      throw Exception('Failed to add manual payment: $e');
    }
  }
}

class ProrationQuote {
  final double creditApplied;
  final double amountDue;
  final double newTotal;
  final int durationMonths;
  final String planId;
  final String planName;
  final double pricePerMonth;
  final bool isEarlyAdopter;

  ProrationQuote({
    required this.creditApplied,
    required this.amountDue,
    required this.newTotal,
    required this.durationMonths,
    required this.planId,
    required this.planName,
    required this.pricePerMonth,
    required this.isEarlyAdopter,
  });
}

class ProrationResult {
  final double amountDue;
  final String? orderId;
  final int durationMonths;
  final String planId;
  final String paymentGateway;
  final String newSubscriptionId;
  final bool scheduled;
  final DateTime? scheduledStart;

  ProrationResult({
    required this.amountDue,
    required this.orderId,
    required this.durationMonths,
    required this.planId,
    required this.paymentGateway,
    required this.newSubscriptionId,
    this.scheduled = false,
    this.scheduledStart,
  });
}

class RetryPaymentResult {
  final String orderId;
  final int durationMonths;
  final String planId;
  final String paymentGateway;

  RetryPaymentResult({
    required this.orderId,
    required this.durationMonths,
    required this.planId,
    required this.paymentGateway,
  });
}

