import 'package:supabase_flutter/supabase_flutter.dart';

/// Global Supabase client accessor
final supabase = Supabase.instance.client;

/// Supabase helper functions
class SupabaseHelper {
  /// Get current user
  static User? get currentUser => supabase.auth.currentUser;

  /// Get current user ID
  static String? get currentUserId => currentUser?.id;

  /// Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;

  /// Sign out
  static Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}

