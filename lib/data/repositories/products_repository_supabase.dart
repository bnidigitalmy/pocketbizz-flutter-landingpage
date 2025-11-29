import '../../core/supabase/supabase_client.dart';
import '../api/models/product_models.dart';

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
          'category': product.category,
          'sale_price': product.salePrice,
          'cost_price': product.costPrice ?? 0,
          'description': product.description,
          'unit': product.unit ?? 'pcs',
          'image_url': product.imageUrl,
        })
        .select()
        .single();

    return _fromSupabaseJson(data);
  }
  
  /// Convert Supabase JSON (snake_case) to Product model (camelCase)
  Product _fromSupabaseJson(Map<String, dynamic> json) {
    return Product.fromJson({
      'id': json['id'],
      'ownerId': json['business_owner_id'],
      'sku': json['sku'],
      'name': json['name'],
      'unit': json['unit'],
      'costPrice': json['cost_price'],
      'salePrice': json['sale_price'],
      'isActive': json['is_active'] ?? true,
      'createdAt': json['created_at'],
      'updatedAt': json['updated_at'],
      'description': json['description'],
      'category': json['category'],
      'imageUrl': json['image_url'],
      // New costing fields
      'unitsPerBatch': json['units_per_batch'],
      'labourCost': json['labour_cost'],
      'otherCosts': json['other_costs'],
      'packagingCost': json['packaging_cost'],
      'materialsCost': json['materials_cost'],
      'totalCostPerBatch': json['total_cost_per_batch'],
      'costPerUnit': json['cost_per_unit'],
    });
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

