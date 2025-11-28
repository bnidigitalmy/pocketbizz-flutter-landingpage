import '../../core/supabase/supabase_client.dart';
import '../api/models/product_models.dart';

/// Products repository using Supabase directly
class ProductsRepositorySupabase {
  /// Create product
  Future<Product> createProduct(Product product) async {
    final data = await supabase
        .from('products')
        .insert({
          'name': product.name,
          'sku': product.sku,
          'category': product.category,
          'price': product.price,
          'description': product.description,
          'unit': product.unit ?? 'pcs',
          'cost_price': product.costPrice,
        })
        .select()
        .single();

    return Product.fromJson(data);
  }

  /// Get product by ID
  Future<Product> getProduct(String id) async {
    final data = await supabase
        .from('products')
        .select()
        .eq('id', id)
        .single();

    return Product.fromJson(data);
  }

  /// List products
  Future<List<Product>> listProducts({
    String? category,
    String? searchQuery,
    int limit = 100,
  }) async {
    var query = supabase.from('products').select().limit(limit);

    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('name', '%$searchQuery%');
    }

    final data = await query.order('name');
    return (data as List).map((json) => Product.fromJson(json)).toList();
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

    return Product.fromJson(data);
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

    return (data as List).map((json) => Product.fromJson(json)).toList();
  }
}

