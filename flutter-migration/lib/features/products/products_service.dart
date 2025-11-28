import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';

class ProductsService {
  final SupabaseClient _client = supabase;

  /// Create a new product
  Future<Map<String, dynamic>> createProduct({
    required String name,
    required String sku,
    required String category,
    required double price,
    String? description,
    String? unit,
    double? costPrice,
  }) async {
    final product = await _client.from('products').insert({
      'name': name,
      'sku': sku,
      'category': category,
      'price': price,
      'description': description,
      'unit': unit ?? 'pcs',
      'cost_price': costPrice,
    }).select().single();

    return product;
  }

  /// Get product by ID
  Future<Map<String, dynamic>> getProduct(String productId) async {
    final product = await _client
        .from('products')
        .select()
        .eq('id', productId)
        .single();

    return product;
  }

  /// List all products
  Future<List<Map<String, dynamic>>> listProducts({
    String? category,
    String? searchQuery,
    int limit = 100,
  }) async {
    var query = _client.from('products').select().limit(limit);

    if (category != null) {
      query = query.eq('category', category);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('name', '%$searchQuery%');
    }

    final products = await query.order('name');
    return List<Map<String, dynamic>>.from(products);
  }

  /// Update product
  Future<Map<String, dynamic>> updateProduct({
    required String productId,
    String? name,
    String? category,
    double? price,
    String? description,
    double? costPrice,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (name != null) updates['name'] = name;
    if (category != null) updates['category'] = category;
    if (price != null) updates['price'] = price;
    if (description != null) updates['description'] = description;
    if (costPrice != null) updates['cost_price'] = costPrice;

    final product = await _client
        .from('products')
        .update(updates)
        .eq('id', productId)
        .select()
        .single();

    return product;
  }

  /// Delete product
  Future<void> deleteProduct(String productId) async {
    await _client.from('products').delete().eq('id', productId);
  }

  /// Get product categories
  Future<List<String>> getCategories() async {
    final result = await _client
        .from('products')
        .select('category')
        .order('category');

    final categories = <String>{};
    for (final row in result) {
      if (row['category'] != null) {
        categories.add(row['category'] as String);
      }
    }

    return categories.toList();
  }

  /// Search products
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final products = await _client
        .from('products')
        .select()
        .or('name.ilike.%$query%,sku.ilike.%$query%,description.ilike.%$query%')
        .limit(20);

    return List<Map<String, dynamic>>.from(products);
  }
}

