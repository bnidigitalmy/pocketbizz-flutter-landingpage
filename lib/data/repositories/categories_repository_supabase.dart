import '../../core/supabase/supabase_client.dart';
import '../../core/utils/rate_limit_mixin.dart';
import '../../core/utils/rate_limiter.dart';
import '../models/category.dart';

class CategoriesRepositorySupabase with RateLimitMixin {
  /// Get all categories for current user with rate limiting
  Future<List<Category>> getAll({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      return await executeWithRateLimit(
        type: RateLimitType.read,
        operation: () async {
          final response = await supabase
              .from('categories')
              .select()
              .eq('is_active', true)
              .order('name', ascending: true)
              .range(offset, offset + limit - 1); // Add pagination

          return (response as List)
              .map((json) => Category.fromJson(json))
              .toList();
        },
      );
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  /// Create category with rate limiting
  Future<Category> create(String name, {String? description, String? icon, String? color}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final data = await supabase
            .from('categories')
            .insert({
              'business_owner_id': userId,
              'name': name,
              'description': description,
              'icon': icon,
              'color': color,
            })
            .select()
            .single();

        return Category.fromJson(data);
      },
    );
  }

  /// Update category with rate limiting
  Future<Category> update(String id, Map<String, dynamic> updates) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final data = await supabase
            .from('categories')
            .update({
              ...updates,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id)
            .select()
            .single();

        return Category.fromJson(data);
      },
    );
  }

  /// Delete category with rate limiting
  Future<void> delete(String id) async {
    await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        await supabase.from('categories').delete().eq('id', id);
      },
    );
  }

  /// Get category by ID with rate limiting
  Future<Category> getById(String id) async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        final data = await supabase
            .from('categories')
            .select()
            .eq('id', id)
            .single();

        return Category.fromJson(data);
      },
    );
  }
}

