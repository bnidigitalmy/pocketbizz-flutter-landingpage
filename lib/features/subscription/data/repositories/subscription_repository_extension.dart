/// Subscription Repository Extension
/// Extends the stable subscription repository with pricing tier functionality
/// This file is safe to modify - it's an extension, not the core module

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pricing_tier.dart';
import '../../../../core/supabase/supabase_client.dart';

/// Extension methods for subscription pricing tiers
class SubscriptionPricingRepository {
  final SupabaseClient _supabase = supabase;

  /// Get full pricing information including current tier and all tiers
  /// Calls the get_subscription_pricing_info() RPC function
  Future<PricingInfo?> getPricingInfo() async {
    try {
      final response = await _supabase.rpc('get_subscription_pricing_info');
      
      if (response == null) return null;
      
      return PricingInfo.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('Error fetching pricing info: $e');
      // Return default pricing info as fallback
      return _getDefaultPricingInfo();
    }
  }

  /// Get current pricing tier for new subscribers
  /// Returns the tier that new subscribers should be assigned to
  Future<PricingTier?> getCurrentPricingTier() async {
    try {
      final response = await _supabase.rpc('get_current_pricing_tier');
      
      if (response == null || (response is List && response.isEmpty)) {
        return null;
      }

      // RPC returns a single row as list
      if (response is List && response.isNotEmpty) {
        return PricingTier.fromJson(response.first as Map<String, dynamic>);
      }
      
      return PricingTier.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('Error fetching current pricing tier: $e');
      return _getDefaultCurrentTier();
    }
  }

  /// Get all pricing tiers with status
  /// Returns all tiers sorted by tier order
  Future<List<PricingTier>> getAllPricingTiers() async {
    try {
      final response = await _supabase.rpc('get_all_pricing_tiers');
      
      if (response == null) return [];
      
      final tiers = (response as List)
          .map((e) => PricingTier.fromJson(e as Map<String, dynamic>))
          .toList();
      
      return tiers;
    } catch (e) {
      print('Error fetching all pricing tiers: $e');
      return _getDefaultTiers();
    }
  }

  /// Check if early adopter slots are still available
  Future<bool> hasEarlyAdopterSlots() async {
    try {
      final response = await _supabase
          .from('pricing_tiers')
          .select('current_subscribers, max_subscribers')
          .eq('tier_name', 'early_adopter')
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return false;

      final current = response['current_subscribers'] as int? ?? 0;
      final max = response['max_subscribers'] as int?;
      
      if (max == null) return true; // Unlimited
      return current < max;
    } catch (e) {
      print('Error checking early adopter slots: $e');
      return false;
    }
  }

  /// Get early adopter slots remaining
  Future<int> getEarlyAdopterSlotsRemaining() async {
    try {
      final response = await _supabase
          .from('pricing_tiers')
          .select('current_subscribers, max_subscribers')
          .eq('tier_name', 'early_adopter')
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return 0;

      final current = response['current_subscribers'] as int? ?? 0;
      final max = response['max_subscribers'] as int? ?? 100;
      
      return (max - current).clamp(0, max);
    } catch (e) {
      print('Error getting early adopter slots remaining: $e');
      return 0;
    }
  }

  /// Get growth tier slots remaining
  Future<int> getGrowthSlotsRemaining() async {
    try {
      final response = await _supabase
          .from('pricing_tiers')
          .select('current_subscribers, max_subscribers')
          .eq('tier_name', 'growth')
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return 0;

      final current = response['current_subscribers'] as int? ?? 0;
      final max = response['max_subscribers'] as int?;
      
      if (max == null) return 999999; // Unlimited
      return (max - current).clamp(0, max);
    } catch (e) {
      print('Error getting growth slots remaining: $e');
      return 0;
    }
  }

  /// Get price per month for current tier
  /// This replaces the hardcoded RM29/RM39 logic with dynamic pricing
  Future<double> getCurrentPricePerMonth() async {
    final tier = await getCurrentPricingTier();
    return tier?.priceMonthly ?? 49.0; // Default to standard if not found
  }

  /// Check if user qualifies for early adopter pricing
  /// User qualifies if:
  /// 1. Early adopter slots are still available AND
  /// 2. User doesn't already have a paid subscription with locked price
  Future<bool> qualifiesForEarlyAdopter(String userId) async {
    try {
      // Check if early adopter slots available
      final hasSlots = await hasEarlyAdopterSlots();
      if (!hasSlots) return false;

      // Check if user already has subscription with locked price
      final existingSub = await _supabase
          .from('subscriptions')
          .select('pricing_tier_name, locked_price_monthly')
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      // If user has active subscription with locked price, they keep their tier
      if (existingSub != null && existingSub['pricing_tier_name'] != null) {
        return existingSub['pricing_tier_name'] == 'early_adopter';
      }

      // New user qualifies for early adopter
      return true;
    } catch (e) {
      print('Error checking early adopter qualification: $e');
      return false;
    }
  }

  /// Get user's locked pricing tier (grandfather clause)
  /// Returns the tier name if user has locked pricing, null otherwise
  Future<String?> getUserLockedTier(String userId) async {
    try {
      final response = await _supabase
          .from('subscriptions')
          .select('pricing_tier_name, locked_price_monthly')
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      if (response == null) return null;
      return response['pricing_tier_name'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Default pricing info as fallback
  PricingInfo _getDefaultPricingInfo() {
    return PricingInfo(
      currentTier: _getDefaultCurrentTier()!,
      allTiers: _getDefaultTiers(),
      hasEarlyAdopterSlots: true,
    );
  }

  /// Default current tier (standard) as fallback
  PricingTier? _getDefaultCurrentTier() {
    return PricingTier(
      id: 'default',
      tierOrder: 3,
      tierName: 'standard',
      tierNameDisplay: 'Standard',
      priceMonthly: 49.0,
      priceYearly: 490.0,
      maxSubscribers: null,
      currentSubscribers: 0,
      slotsRemaining: null,
      isCurrentTier: true,
      isSoldOut: false,
      description: 'Harga standard selepas kuota awal habis.',
    );
  }

  /// Default tiers list as fallback
  List<PricingTier> _getDefaultTiers() {
    return [
      PricingTier(
        id: 'ea',
        tierOrder: 1,
        tierName: 'early_adopter',
        tierNameDisplay: 'Early Adopter',
        priceMonthly: 29.0,
        priceYearly: 290.0,
        maxSubscribers: 100,
        currentSubscribers: 100, // Assume sold out for safety
        slotsRemaining: 0,
        isCurrentTier: false,
        isSoldOut: true,
        description: 'Harga istimewa untuk 100 subscriber pertama.',
      ),
      PricingTier(
        id: 'growth',
        tierOrder: 2,
        tierName: 'growth',
        tierNameDisplay: 'Growth',
        priceMonthly: 39.0,
        priceYearly: 390.0,
        maxSubscribers: 2000,
        currentSubscribers: 0,
        slotsRemaining: 2000,
        isCurrentTier: false,
        isSoldOut: false,
        description: 'Harga khas untuk 2,000 subscriber seterusnya.',
      ),
      PricingTier(
        id: 'standard',
        tierOrder: 3,
        tierName: 'standard',
        tierNameDisplay: 'Standard',
        priceMonthly: 49.0,
        priceYearly: 490.0,
        maxSubscribers: null,
        currentSubscribers: 0,
        slotsRemaining: null,
        isCurrentTier: true,
        isSoldOut: false,
        description: 'Harga standard selepas kuota awal habis.',
      ),
    ];
  }
}
