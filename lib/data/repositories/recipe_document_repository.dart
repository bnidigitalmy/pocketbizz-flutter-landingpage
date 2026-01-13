import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../../core/config/env_config.dart';
import '../../core/supabase/supabase_client.dart';
import '../../core/utils/rate_limit_mixin.dart';
import '../../core/utils/rate_limiter.dart';
import '../models/recipe_document.dart';

/// Repository for recipe documents using Supabase
class RecipeDocumentRepository with RateLimitMixin {
  /// Get all recipe documents with optional filters
  Future<List<RecipeDocument>> getAll({
    String? categoryId,
    bool? isFavourite,
    String? contentType,
    String? searchQuery,
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

        // Build base query
        dynamic queryBuilder = supabase
            .from('recipe_documents')
            .select()
            .eq('business_owner_id', userId);

        // Apply filters - chain them directly
        if (categoryId != null && categoryId.isNotEmpty) {
          queryBuilder = queryBuilder.eq('category_id', categoryId);
        }
        if (isFavourite != null) {
          queryBuilder = queryBuilder.eq('is_favourite', isFavourite);
        }
        if (contentType != null && contentType.isNotEmpty) {
          queryBuilder = queryBuilder.eq('content_type', contentType);
        }
        if (searchQuery != null && searchQuery.isNotEmpty) {
          // Search in title (simpler approach)
          queryBuilder = queryBuilder.ilike('title', '%$searchQuery%');
        }

        // Apply ordering and pagination
        queryBuilder = queryBuilder.order('uploaded_at', ascending: false);
        queryBuilder = queryBuilder.range(offset, offset + limit - 1);

        final data = await queryBuilder;
        return (data as List)
            .map((json) => RecipeDocument.fromJson(json as Map<String, dynamic>))
            .toList();
      },
    );
  }

  /// Get recipe document by ID
  Future<RecipeDocument?> getById(String id) async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        final data = await supabase
            .from('recipe_documents')
            .select()
            .eq('id', id)
            .eq('business_owner_id', userId)
            .maybeSingle();

        if (data == null) return null;
        return RecipeDocument.fromJson(data as Map<String, dynamic>);
      },
    );
  }

  /// Create recipe document (file or text)
  Future<RecipeDocument> create(RecipeDocument document) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        final insertData = <String, dynamic>{
          'business_owner_id': userId,
          'title': document.title,
          'content_type': document.contentType,
        };

        // Add optional fields
        if (document.description != null && document.description!.isNotEmpty) {
          insertData['description'] = document.description;
        }
        if (document.categoryId != null && document.categoryId!.isNotEmpty) {
          insertData['category_id'] = document.categoryId;
        }
        if (document.source != null && document.source!.isNotEmpty) {
          insertData['source'] = document.source;
        }
        if (document.tags.isNotEmpty) {
          insertData['tags'] = document.tags;
        }
        if (document.isFavourite) {
          insertData['is_favourite'] = true;
        }
        if (document.linkedRecipeId != null && document.linkedRecipeId!.isNotEmpty) {
          insertData['linked_recipe_id'] = document.linkedRecipeId;
        }

        // Add file fields if content type is file
        if (document.contentType == 'file') {
          if (document.fileName != null) insertData['file_name'] = document.fileName;
          if (document.filePath != null) insertData['file_path'] = document.filePath;
          if (document.fileType != null) insertData['file_type'] = document.fileType;
          if (document.fileSize != null) insertData['file_size'] = document.fileSize;
        }

        // Add text content if content type is text
        if (document.contentType == 'text') {
          if (document.textContent != null) {
            insertData['text_content'] = document.textContent;
          }
        }

        final data = await supabase
            .from('recipe_documents')
            .insert(insertData)
            .select()
            .single();

        return RecipeDocument.fromJson(data as Map<String, dynamic>);
      },
    );
  }

  /// Update recipe document
  Future<RecipeDocument> update(RecipeDocument document) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        final updateData = <String, dynamic>{
          'title': document.title,
        };

        // Add optional fields
        if (document.description != null) {
          updateData['description'] = document.description;
        }
        if (document.categoryId != null) {
          updateData['category_id'] = document.categoryId;
        } else {
          updateData['category_id'] = null;
        }
        if (document.source != null) {
          updateData['source'] = document.source;
        }
        if (document.tags.isNotEmpty) {
          updateData['tags'] = document.tags;
        }
        updateData['is_favourite'] = document.isFavourite;
        if (document.linkedRecipeId != null && document.linkedRecipeId!.isNotEmpty) {
          updateData['linked_recipe_id'] = document.linkedRecipeId;
        } else {
          updateData['linked_recipe_id'] = null;
        }

        // Update text content if content type is text
        if (document.contentType == 'text' && document.textContent != null) {
          updateData['text_content'] = document.textContent;
        }

        final data = await supabase
            .from('recipe_documents')
            .update(updateData)
            .eq('id', document.id)
            .eq('business_owner_id', userId)
            .select()
            .single();

        return RecipeDocument.fromJson(data as Map<String, dynamic>);
      },
    );
  }

  /// Delete recipe document
  Future<void> delete(String id) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        // Get document to check if it has a file
        final document = await getById(id);
        if (document == null) {
          throw Exception('Document not found');
        }

        // Delete file from storage if it exists
        if (document.isFile && document.filePath != null && document.filePath!.isNotEmpty) {
          try {
            // For web, we might need to use HTTP DELETE
            if (kIsWeb) {
              final accessToken = supabase.auth.currentSession?.accessToken;
              if (accessToken != null) {
                final supabaseUrl = EnvConfig.supabaseUrl;
                final supabaseAnonKey = EnvConfig.supabaseAnonKey;
                
                // Encode path properly for URL
                final pathSegments = document.filePath!.split('/');
                final encodedSegments = pathSegments.map((s) => Uri.encodeComponent(s)).join('/');
                final storageUrl = '$supabaseUrl/storage/v1/object/recipe-documents/$encodedSegments';
                
                final response = await http.delete(
                  Uri.parse(storageUrl),
                  headers: {
                    'Authorization': 'Bearer $accessToken',
                    'apikey': supabaseAnonKey,
                  },
                );
                
                // 200, 204, or 404 (already deleted) are acceptable
                if (response.statusCode != 200 && 
                    response.statusCode != 204 && 
                    response.statusCode != 404) {
                  print('Warning: Failed to delete file from storage: ${response.statusCode} - ${response.body}');
                }
              }
            } else {
              // For mobile: use Supabase client
              await supabase.storage
                  .from('recipe-documents')
                  .remove([document.filePath!]);
            }
          } catch (e) {
            // Log error but continue with database deletion
            // File might already be deleted or not exist
            print('Warning: Error deleting file from storage: $e');
          }
        }

        // Delete from database
        // Use select() to get deleted rows for verification
        final deleteResult = await supabase
            .from('recipe_documents')
            .delete()
            .eq('id', id)
            .eq('business_owner_id', userId)
            .select();
        
        // Verify deletion was successful
        // Supabase returns empty list if no rows were deleted
        if (deleteResult == null || (deleteResult is List && deleteResult.isEmpty)) {
          throw Exception('Gagal memadam dokumen. Dokumen mungkin tidak wujud atau anda tidak mempunyai kebenaran.');
        }
      },
    );
  }

  /// Toggle favourite status
  Future<RecipeDocument> toggleFavourite(String id) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        // Get current document
        final current = await getById(id);
        if (current == null) {
          throw Exception('Document not found');
        }

        // Toggle favourite
        final data = await supabase
            .from('recipe_documents')
            .update({'is_favourite': !current.isFavourite})
            .eq('id', id)
            .eq('business_owner_id', userId)
            .select()
            .single();

        return RecipeDocument.fromJson(data as Map<String, dynamic>);
      },
    );
  }

  /// Update view stats (last_viewed_at and view_count)
  Future<void> updateViewStats(String id) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        // Get current view count
        final current = await getById(id);
        if (current == null) return;

        await supabase
            .from('recipe_documents')
            .update({
              'last_viewed_at': DateTime.now().toIso8601String(),
              'view_count': current.viewCount + 1,
            })
            .eq('id', id)
            .eq('business_owner_id', userId);
      },
    );
  }

  /// Link document to recipe
  Future<RecipeDocument> linkToRecipe(String documentId, String recipeId) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        final data = await supabase
            .from('recipe_documents')
            .update({'linked_recipe_id': recipeId})
            .eq('id', documentId)
            .eq('business_owner_id', userId)
            .select()
            .single();

        return RecipeDocument.fromJson(data as Map<String, dynamic>);
      },
    );
  }

  /// Unlink document from recipe
  Future<RecipeDocument> unlinkFromRecipe(String documentId) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        final data = await supabase
            .from('recipe_documents')
            .update({'linked_recipe_id': null})
            .eq('id', documentId)
            .eq('business_owner_id', userId)
            .select()
            .single();

        return RecipeDocument.fromJson(data as Map<String, dynamic>);
      },
    );
  }

  /// Upload file to Supabase Storage
  /// Returns the file path
  Future<String> uploadFile({
    required String fileName,
    required Uint8List fileBytes,
    String? contentType,
  }) async {
    return await executeWithRateLimit(
      type: RateLimitType.upload,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        // Generate unique file path: {user_id}/{timestamp}_{filename}
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final sanitizedFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final filePath = '$userId/$timestamp$sanitizedFileName';

        // Handle web platform differently
        if (kIsWeb) {
          // For web: use HTTP PUT with proper headers
          final accessToken = supabase.auth.currentSession?.accessToken;
          if (accessToken == null || accessToken.isEmpty) {
            throw Exception('User not authenticated. Please login first.');
          }

          // Use EnvConfig which handles --dart-define, .env, and fallback automatically
          final supabaseUrl = EnvConfig.supabaseUrl;
          final supabaseAnonKey = EnvConfig.supabaseAnonKey;

          // Encode path properly for URL
          final pathSegments = filePath.split('/');
          final encodedSegments = pathSegments.map((s) => Uri.encodeComponent(s)).join('/');
          final storageUrl = '$supabaseUrl/storage/v1/object/recipe-documents/$encodedSegments';

          // Determine content type
          final finalContentType = contentType ?? 'application/octet-stream';

          // Upload using HTTP PUT
          final response = await http.put(
            Uri.parse(storageUrl),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': finalContentType,
              'apikey': supabaseAnonKey,
              'x-upsert': 'false',
            },
            body: fileBytes,
          );

          if (response.statusCode != 200 && response.statusCode != 201) {
            throw Exception('Failed to upload file: ${response.statusCode} - ${response.body}');
          }

          return filePath;
        } else {
          // For mobile: use Supabase client upload
          // Import FileOptions from supabase_flutter if needed
          await supabase.storage
              .from('recipe-documents')
              .upload(
                filePath,
                fileBytes,
              );

          return filePath;
        }
      },
    );
  }

  /// Get file download URL
  Future<String> getFileUrl(String filePath) async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        final response = await supabase.storage
            .from('recipe-documents')
            .createSignedUrl(filePath, 3600); // 1 hour expiry

        return response;
      },
    );
  }
}
