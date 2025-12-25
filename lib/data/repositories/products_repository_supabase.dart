/**
 * 🔒 POCKETBIZZ CORE ENGINE (STABLE)
 * ❌ DO NOT MODIFY
 * ❌ DO NOT REFACTOR
 * ❌ DO NOT OPTIMIZE
 * This logic is production-tested.
 * New features must EXTEND, not change.
 */

import '../../core/supabase/supabase_client.dart';
import '../../core/utils/rate_limit_mixin.dart';
import '../../core/utils/rate_limiter.dart';
import '../models/product.dart';
import '../../features/subscription/data/repositories/subscription_repository_supabase.dart';

/// Products repository using Supabase directly with rate limiting
class ProductsRepositorySupabase with RateLimitMixin {
  /// Create product with rate limiting
  Future<Product> createProduct(Product product) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        // Check subscription limits before creating product
        final subscriptionRepo = SubscriptionRepositorySupabase();
        final limits = await subscriptionRepo.getPlanLimits();
        if (limits.products.current >= limits.products.max && !limits.products.isUnlimited) {
          throw Exception(
            'Had produk telah dicapai (${limits.products.current}/${limits.products.max}). '
            'Sila naik taraf langganan anda untuk menambah lebih banyak produk.'
          );
        }

        // Build insert data, only include non-null fields
        final insertData = <String, dynamic>{
          'business_owner_id': userId,
          'name': product.name,
          'sku': product.sku,
          'sale_price': product.salePrice,
          'cost_price': product.costPrice,
          'unit': product.unit,
          'units_per_batch': product.unitsPerBatch,
          'labour_cost': product.labourCost,
          'other_costs': product.otherCosts,
          'packaging_cost': product.packagingCost,
          'is_active': true, // Default to active
        };

        // Add optional fields only if they have values
        if (product.categoryId != null && product.categoryId!.isNotEmpty) {
          insertData['category_id'] = product.categoryId;
        }
        if (product.category != null && product.category!.isNotEmpty) {
          insertData['category'] = product.category;
        }
        if (product.description != null && product.description!.isNotEmpty) {
          insertData['description'] = product.description;
        }
        if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
          insertData['image_url'] = product.imageUrl;
        }
        // Add calculated cost fields (can be null)
        if (product.materialsCost != null) {
          insertData['materials_cost'] = product.materialsCost;
        }
        if (product.totalCostPerBatch != null) {
          insertData['total_cost_per_batch'] = product.totalCostPerBatch;
        }
        if (product.costPerUnit != null) {
          insertData['cost_per_unit'] = product.costPerUnit;
        }

        final data = await supabase
            .from('products')
            .insert(insertData)
            .select()
            .single();

        return _fromSupabaseJson(data);
      },
    );
  }
  
  /// Convert Supabase JSON (snake_case) to Product model
  Product _fromSupabaseJson(Map<String, dynamic> json) {
    return Product.fromJson(json);
  }

  /// Get all products with pagination and rate limiting
  /// [limit] - Maximum number of products to fetch (default: 100)
  /// [offset] - Number of products to skip (default: 0)
  Future<List<Product>> getAll({
    int limit = 100,
    int offset = 0,
  }) async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        try {
          final response = await supabase
              .from('products')
              .select()
              .eq('business_owner_id', userId) // Filter by user's business_owner_id
              .eq('is_active', true) // Only active products for getAll
              .order('name', ascending: true)
              .range(offset, offset + limit - 1); // Add pagination

          return (response as List).map((json) => _fromSupabaseJson(json)).toList();
        } catch (e) {
          throw Exception('Failed to fetch products: $e');
        }
      },
    );
  }

  /// Get product by ID with rate limiting
  Future<Product> getProduct(String id) async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        final data = await supabase
            .from('products')
            .select()
            .eq('id', id)
            .eq('business_owner_id', userId) // Filter by user's business_owner_id
            .single();

        return _fromSupabaseJson(data);
      },
    );
  }

  /// List products with rate limiting
  /// By default, only returns active products (is_active = true)
  /// Set includeInactive = true to include disabled products
  Future<List<Product>> listProducts({
    String? category,
    String? searchQuery,
    int limit = 100,
    bool includeInactive = false, // Include disabled products
  }) async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        var query = supabase
            .from('products')
            .select()
            .eq('business_owner_id', userId); // Filter by user's business_owner_id
        
        // Filter active products unless includeInactive is true
        if (!includeInactive) {
          query = query.eq('is_active', true);
        }

        // Apply filters if provided
        if (category != null && category.isNotEmpty) {
          query = query.eq('category', category);
        }

        if (searchQuery != null && searchQuery.isNotEmpty) {
          query = query.ilike('name', '%$searchQuery%');
        }

        // Execute query with order and limit
        final data = await query.order('name').limit(limit);
        return (data as List).map((json) => _fromSupabaseJson(json)).toList();
      },
    );
  }

  /// Update product with rate limiting
  Future<Product> updateProduct(String id, Map<String, dynamic> updates) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        final data = await supabase
            .from('products')
            .update({
              ...updates,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id)
            .eq('business_owner_id', userId) // Filter by user's business_owner_id
            .select()
            .single();

        return _fromSupabaseJson(data);
      },
    );
  }

  /// Disable product (soft delete - safer option)
  /// Sets is_active = false. Product can be re-enabled later.
  /// This preserves all data and references.
  Future<void> disableProduct(String id) async {
    await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        await supabase
            .from('products')
            .update({
              'is_active': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id)
            .eq('business_owner_id', userId);
      },
    );
  }

  /// Enable product (re-activate disabled product)
  Future<void> enableProduct(String id) async {
    await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        await supabase
            .from('products')
            .update({
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id)
            .eq('business_owner_id', userId);
      },
    );
  }

  /// Delete product permanently (hard delete - use with caution)
  /// Products can be deleted even if referenced in bookings.
  /// booking_items.product_id will be set to NULL automatically (ON DELETE SET NULL),
  /// while booking_items.product_name is preserved for record-keeping.
  /// Consider using disableProduct() instead for safer operation.
  Future<void> deleteProduct(String id) async {
    await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        // Note: Product can now be deleted even if referenced in bookings
        // booking_items.product_id will be set to NULL automatically (ON DELETE SET NULL)
        // booking_items.product_name is preserved so booking records remain intact
        
        await supabase
            .from('products')
            .delete()
            .eq('id', id)
            .eq('business_owner_id', userId); // Filter by user's business_owner_id
      },
    );
  }

  /// Search products with rate limiting
  Future<List<Product>> searchProducts(String query) async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        final data = await supabase
            .from('products')
            .select()
            .eq('business_owner_id', userId) // Filter by user's business_owner_id
            .or('name.ilike.%$query%,sku.ilike.%$query%')
            .limit(20);

        return (data as List).map((json) => _fromSupabaseJson(json)).toList();
      },
    );
  }
}

