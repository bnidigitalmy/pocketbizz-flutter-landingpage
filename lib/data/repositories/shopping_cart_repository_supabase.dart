import '../../core/supabase/supabase_client.dart';
import '../models/shopping_cart_item.dart';

/// Shopping Cart Repository using Supabase
class ShoppingCartRepository {
  /// Get all cart items for current user
  Future<List<ShoppingCartItem>> getAllCartItems() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('shopping_cart_items')
          .select('*, stock_items(*)')
          .eq('business_owner_id', userId)
          .eq('status', 'pending')
          .order('priority', ascending: false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ShoppingCartItem.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch cart items: $e');
    }
  }

  /// Add single item to cart
  Future<ShoppingCartItem> addToCart({
    required String stockItemId,
    required double shortageQty,
    String? notes,
    String priority = 'normal',
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Check if item already in cart
      final existing = await supabase
          .from('shopping_cart_items')
          .select()
          .eq('business_owner_id', userId)
          .eq('stock_item_id', stockItemId)
          .eq('status', 'pending')
          .maybeSingle();

      if (existing != null) {
        // Update existing
        final updated = await supabase
            .from('shopping_cart_items')
            .update({
              'shortage_qty': shortageQty,
              'notes': notes,
              'priority': priority,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id'])
            .select('*, stock_items(*)')
            .single();

        return ShoppingCartItem.fromJson(updated);
      } else {
        // Insert new
        final data = await supabase
            .from('shopping_cart_items')
            .insert({
              'business_owner_id': userId,
              'stock_item_id': stockItemId,
              'shortage_qty': shortageQty,
              'notes': notes,
              'priority': priority,
              'status': 'pending',
            })
            .select('*, stock_items(*)')
            .single();

        return ShoppingCartItem.fromJson(data);
      }
    } catch (e) {
      throw Exception('Failed to add to cart: $e');
    }
  }

  /// Bulk add items to cart
  Future<Map<String, dynamic>> bulkAddToCart(
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final result = await supabase.rpc(
        'bulk_add_to_shopping_cart',
        params: {'p_items': items},
      );

      return result as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to bulk add to cart: $e');
    }
  }

  /// Update cart item
  Future<ShoppingCartItem> updateCartItem({
    required String id,
    double? shortageQty,
    String? notes,
    String? priority,
    String? status,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (shortageQty != null) updates['shortage_qty'] = shortageQty;
      if (notes != null) updates['notes'] = notes;
      if (priority != null) updates['priority'] = priority;
      if (status != null) updates['status'] = status;

      final data = await supabase
          .from('shopping_cart_items')
          .update(updates)
          .eq('id', id)
          .select('*, stock_items(*)')
          .single();

      return ShoppingCartItem.fromJson(data);
    } catch (e) {
      throw Exception('Failed to update cart item: $e');
    }
  }

  /// Remove item from cart
  Future<void> removeFromCart(String id) async {
    try {
      await supabase
          .from('shopping_cart_items')
          .delete()
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to remove from cart: $e');
    }
  }

  /// Mark items as ordered
  Future<void> markAsOrdered(List<String> itemIds) async {
    try {
      await supabase
          .from('shopping_cart_items')
          .update({
            'status': 'ordered',
            'ordered_at': DateTime.now().toIso8601String(),
          })
          .inFilter('id', itemIds);
    } catch (e) {
      throw Exception('Failed to mark as ordered: $e');
    }
  }

  /// Mark items as received
  Future<void> markAsReceived(List<String> itemIds) async {
    try {
      await supabase
          .from('shopping_cart_items')
          .update({
            'status': 'received',
            'received_at': DateTime.now().toIso8601String(),
          })
          .inFilter('id', itemIds);
    } catch (e) {
      throw Exception('Failed to mark as received: $e');
    }
  }

  /// Get cart items count
  Future<int> getCartCount() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await supabase
          .from('shopping_cart_items')
          .select('id')
          .eq('business_owner_id', userId)
          .eq('status', 'pending')
          .count();

      return response.count;
    } catch (e) {
      return 0;
    }
  }

  /// Clear all pending cart items
  Future<void> clearCart() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase
          .from('shopping_cart_items')
          .delete()
          .eq('business_owner_id', userId)
          .eq('status', 'pending');
    } catch (e) {
      throw Exception('Failed to clear cart: $e');
    }
  }
}

