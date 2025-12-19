import '../../core/supabase/supabase_client.dart';

/// Ownership Validator
/// 
/// App-level validation for business_owner_id (Defense in Depth)
/// Even though RLS protects at database level, this provides:
/// - Better UX with clear error messages
/// - Additional safety layer
/// - Code-level validation
class OwnershipValidator {
  /// Validate that the business_owner_id matches current user
  /// 
  /// Throws exception if validation fails
  /// 
  /// [businessOwnerId] - The business_owner_id to validate
  /// [entityType] - Type of entity (for error message)
  static void validateOwnership(String? businessOwnerId, String entityType) {
    final currentUserId = supabase.auth.currentUser?.id;
    
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }
    
    if (businessOwnerId == null) {
      throw Exception('$entityType does not have a business owner (data integrity error)');
    }
    
    if (businessOwnerId != currentUserId) {
      throw Exception(
        'Anda tidak mempunyai akses kepada $entityType ini. '
        'Data ini adalah milik pengguna lain.'
      );
    }
  }

  /// Validate ownership without throwing (returns bool)
  /// 
  /// Useful for conditional checks
  static bool isOwner(String? businessOwnerId) {
    final currentUserId = supabase.auth.currentUser?.id;
    
    if (currentUserId == null || businessOwnerId == null) {
      return false;
    }
    
    return businessOwnerId == currentUserId;
  }

  /// Validate ownership for a map/JSON object
  /// 
  /// Checks 'business_owner_id' field in the map
  static void validateFromMap(Map<String, dynamic> data, String entityType) {
    final businessOwnerId = data['business_owner_id'] as String?;
    validateOwnership(businessOwnerId, entityType);
  }

  /// Get current user's business owner ID
  /// 
  /// Throws if user is not authenticated
  static String getCurrentBusinessOwnerId() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    return userId;
  }

  /// Assert that user is authenticated
  /// 
  /// Throws if user is not authenticated
  static void assertAuthenticated() {
    if (supabase.auth.currentUser?.id == null) {
      throw Exception('User not authenticated');
    }
  }
}

