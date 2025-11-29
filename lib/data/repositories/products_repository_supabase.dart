import '../../core/supabase/supabase_client.dart';
import '../models/product.dart';

/// Products repository using Supabase directly
class ProductsRepositorySupabase {
  /// Create product
  Future<Product> createProduct(Product product) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final data = await supabase
        .from('products')
        .insert({
          'business_owner_id': userId,
          'name': product.name,
          'sku': product.sku,
          'category_id': product.categoryId,
          'category': product.category,
          'sale_price': product.salePrice,
          'cost_price': product.costPrice,
          'description': product.description,
          'unit': product.unit,
          'image_url': product.imageUrl,
          'units_per_batch': product.unitsPerBatch,
          'labour_cost': product.labourCost,
          'other_costs': product.otherCosts,
          'packaging_cost': product.packagingCost,
        })
        .select()
        .single();

    return _fromSupabaseJson(data);
  }
  
  /// Convert Supabase JSON (snake_case) to Product model
  Product _fromSupabaseJson(Map<String, dynamic> json) {
    return Product.fromJson(json);
  }

  /// Get all products
  Future<List<Product>> getAll() async {
    try {
      final response = await supabase
          .from('products')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);

      return (response as List).map((json) => _fromSupabaseJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }

  /// Get product by ID
  Future<Product> getProduct(String id) async {
    final data = await supabase
        .from('products')
        .select()
        .eq('id', id)
        .single();

    return _fromSupabaseJson(data);
  }

  /// List products
  Future<List<Product>> listProducts({
    String? category,
    String? searchQuery,
    int limit = 100,
  }) async {
    var query = supabase.from('products').select();

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
  }

  /// Update product
  Future<Product> updateProduct(String id, Map<String, dynamic> updates) async {
    final data = await supabase
        .from('products')
        .update({
          ...updates,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();

    return _fromSupabaseJson(data);
  }

  /// Delete product
  Future<void> deleteProduct(String id) async {
    await supabase.from('products').delete().eq('id', id);
  }

  /// Search products
  Future<List<Product>> searchProducts(String query) async {
    final data = await supabase
        .from('products')
        .select()
        .or('name.ilike.%$query%,sku.ilike.%$query%')
        .limit(20);

    return (data as List).map((json) => _fromSupabaseJson(json)).toList();
  }
}

