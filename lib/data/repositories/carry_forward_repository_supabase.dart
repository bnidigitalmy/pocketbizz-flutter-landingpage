import '../../core/supabase/supabase_client.dart';
import '../models/carry_forward_item.dart';

/// Repository for managing Carry Forward (C/F) items
class CarryForwardRepositorySupabase {
  /// Get all available C/F items for a vendor
  /// These are items that can be used in the next claim
  Future<List<CarryForwardItem>> getAvailableItems({
    required String vendorId,
  }) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await supabase
          .from('carry_forward_items')
          .select('*')
          .eq('business_owner_id', userId)
          .eq('vendor_id', vendorId)
          .eq('status', 'available')
          .gt('quantity_available', 0)
          .order('created_at', ascending: true);

      if (response.isEmpty) {
        return [];
      }

      return (response as List)
          .map((json) => CarryForwardItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error fetching carry forward items: $e');
    }
  }

  /// Get all available C/F items using the view (includes vendor and product info)
  Future<List<CarryForwardItem>> getAvailableItemsWithDetails({
    required String vendorId,
  }) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await supabase
          .from('carry_forward_items')
          .select('*')
          .eq('business_owner_id', userId)
          .eq('vendor_id', vendorId)
          .eq('status', 'available')
          .gt('quantity_available', 0)
          .order('created_at', ascending: true);

      if (response.isEmpty) {
        return [];
      }

      return (response as List)
          .map((json) => CarryForwardItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error fetching carry forward items: $e');
    }
  }

  /// Mark C/F items as used when they are included in a new claim
  Future<void> markAsUsed({
    required List<String> carryForwardItemIds,
    required String claimId,
  }) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    if (carryForwardItemIds.isEmpty) {
      return;
    }

    try {
      // Build filter for multiple IDs
      final filter = carryForwardItemIds.map((id) => '"$id"').join(',');

      await supabase.rpc('exec_sql', params: {
        'sql': '''
          UPDATE carry_forward_items
          SET 
            status = 'used',
            used_at = NOW(),
            used_in_claim_id = '$claimId',
            updated_at = NOW()
          WHERE 
            id IN ($filter)
            AND business_owner_id = '$userId'
            AND status = 'available'
        ''',
      });
    } catch (e) {
      // Fallback: Use direct update if RPC not available
      for (final id in carryForwardItemIds) {
        await supabase
            .from('carry_forward_items')
            .update({
              'status': 'used',
              'used_at': DateTime.now().toIso8601String(),
              'used_in_claim_id': claimId,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id)
            .eq('business_owner_id', userId)
            .eq('status', 'available');
      }
    }
  }

  /// Cancel/Delete a C/F item (user decides not to use it)
  Future<void> cancelItem(String itemId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await supabase
          .from('carry_forward_items')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', itemId)
          .eq('business_owner_id', userId);
    } catch (e) {
      throw Exception('Error cancelling carry forward item: $e');
    }
  }

  /// Get C/F items grouped by product (for easier display)
  Future<Map<String, List<CarryForwardItem>>> getAvailableItemsGroupedByProduct({
    required String vendorId,
  }) async {
    final items = await getAvailableItemsWithDetails(vendorId: vendorId);
    
    final grouped = <String, List<CarryForwardItem>>{};
    for (final item in items) {
      final key = item.productId ?? item.productName;
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(item);
    }
    
    return grouped;
  }

  /// Get total quantity available for a product (sum of all C/F items)
  Future<double> getTotalAvailableQuantity({
    required String vendorId,
    String? productId,
    String? productName,
  }) async {
    final List<CarryForwardItem> items = await getAvailableItems(vendorId: vendorId);
    
    if (productId != null) {
      final filtered = items.where((item) => item.productId == productId).toList();
      return filtered.fold<double>(0.0, (sum, item) => sum + item.quantityAvailable);
    } else if (productName != null) {
      final filtered = items.where((item) => item.productName == productName).toList();
      return filtered.fold<double>(0.0, (sum, item) => sum + item.quantityAvailable);
    }
    
    return items.fold<double>(0.0, (sum, item) => sum + item.quantityAvailable);
  }
}


