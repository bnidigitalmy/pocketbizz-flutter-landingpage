import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/cache_service.dart';

/// Global Supabase client accessor
/// Uses lazy getter to ensure Supabase is initialized before access
SupabaseClient get supabase {
  if (!Supabase.instance.isInitialized) {
    throw StateError(
      'Supabase not initialized. Make sure Supabase.initialize() is called in main() before accessing supabase.',
    );
  }
  return Supabase.instance.client;
}

/// Supabase helper functions
class SupabaseHelper {
  /// Get current user
  static User? get currentUser => supabase.auth.currentUser;

  /// Get current user ID
  static String? get currentUserId => currentUser?.id;

  /// Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;

  /// Sign out
  /// Clears all cache to prevent data leakage between users
  static Future<void> signOut() async {
    // Clear all cache before signing out
    CacheService.clearAll();
    await supabase.auth.signOut();
  }
}

