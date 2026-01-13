import '../../core/supabase/supabase_client.dart';
import '../../core/utils/rate_limit_mixin.dart';
import '../../core/utils/rate_limiter.dart';
import '../models/recipe_document_category.dart';

/// Repository for recipe document categories using Supabase
class RecipeDocumentCategoryRepository with RateLimitMixin {
  /// Get all categories
  Future<List<RecipeDocumentCategory>> getAll() async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        final data = await supabase
            .from('recipe_document_categories')
            .select()
            .eq('business_owner_id', userId)
            .order('sort_order')
            .order('name');

        return (data as List)
            .map((json) => RecipeDocumentCategory.fromJson(json as Map<String, dynamic>))
            .toList();
      },
    );
  }

  /// Get category by ID
  Future<RecipeDocumentCategory?> getById(String id) async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        final data = await supabase
            .from('recipe_document_categories')
            .select()
            .eq('id', id)
            .eq('business_owner_id', userId)
            .maybeSingle();

        if (data == null) return null;
        return RecipeDocumentCategory.fromJson(data as Map<String, dynamic>);
      },
    );
  }

  /// Create category
  Future<RecipeDocumentCategory> create(RecipeDocumentCategory category) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        final insertData = <String, dynamic>{
          'business_owner_id': userId,
          'name': category.name,
          'sort_order': category.sortOrder,
        };

        if (category.icon != null && category.icon!.isNotEmpty) {
          insertData['icon'] = category.icon;
        }
        if (category.color != null && category.color!.isNotEmpty) {
          insertData['color'] = category.color;
        }

        final data = await supabase
            .from('recipe_document_categories')
            .insert(insertData)
            .select()
            .single();

        return RecipeDocumentCategory.fromJson(data as Map<String, dynamic>);
      },
    );
  }

  /// Update category
  Future<RecipeDocumentCategory> update(RecipeDocumentCategory category) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        final updateData = <String, dynamic>{
          'name': category.name,
          'sort_order': category.sortOrder,
        };

        if (category.icon != null) {
          updateData['icon'] = category.icon;
        }
        if (category.color != null) {
          updateData['color'] = category.color;
        }

        final data = await supabase
            .from('recipe_document_categories')
            .update(updateData)
            .eq('id', category.id)
            .eq('business_owner_id', userId)
            .select()
            .single();

        return RecipeDocumentCategory.fromJson(data as Map<String, dynamic>);
      },
    );
  }

  /// Delete category
  Future<void> delete(String id) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        // Check if category is used by any documents
        final documents = await supabase
            .from('recipe_documents')
            .select('id')
            .eq('business_owner_id', userId)
            .eq('category_id', id)
            .limit(1);

        if ((documents as List).isNotEmpty) {
          throw Exception(
            'Kategori ini sedang digunakan. Sila alihkan dokumen ke kategori lain terlebih dahulu.',
          );
        }

        await supabase
            .from('recipe_document_categories')
            .delete()
            .eq('id', id)
            .eq('business_owner_id', userId);
      },
    );
  }

  /// Check if category name exists
  Future<bool> nameExists(String name) async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        final data = await supabase
            .from('recipe_document_categories')
            .select('id')
            .eq('business_owner_id', userId)
            .eq('name', name)
            .maybeSingle();

        return data != null;
      },
    );
  }
}
