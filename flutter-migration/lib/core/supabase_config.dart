import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration and initialization
class SupabaseConfig {
  /// Initialize Supabase
  /// Call this in main() before runApp()
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  /// Get Supabase client instance
  static SupabaseClient get client => Supabase.instance.client;

  /// Get current user
  static User? get currentUser => client.auth.currentUser;

  /// Get current user ID
  static String? get currentUserId => currentUser?.id;

  /// Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;
}

/// Global accessor for Supabase client
final supabase = SupabaseConfig.client;

