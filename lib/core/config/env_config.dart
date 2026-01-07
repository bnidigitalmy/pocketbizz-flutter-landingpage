/// Environment Configuration
/// Loads and provides access to environment variables
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // Supabase Configuration
  static String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception(
        'SUPABASE_URL not found in environment variables. '
        'Please create a .env file with SUPABASE_URL=your-url'
      );
    }
    return url;
  }

  static String get supabaseAnonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY not found in environment variables. '
        'Please create a .env file with SUPABASE_ANON_KEY=your-key'
      );
    }
    return key;
  }

  // Google OAuth Configuration
  static String? get googleOAuthClientId {
    return dotenv.env['GOOGLE_OAUTH_CLIENT_ID'];
  }

  // Initialize environment variables
  static Future<void> load() async {
    if (kIsWeb) {
      // On web, try to load bundled asset at assets/.env (must be listed in pubspec)
      try {
        await dotenv.load(fileName: 'assets/.env');
        debugPrint('EnvConfig: Loaded assets/.env for web');
        return;
      } catch (e) {
        debugPrint('⚠️ Warning: Could not load assets/.env on web: $e');
        debugPrint('⚠️ Using fallback values. Please ensure assets/.env is bundled.');
        return;
      }
    }

    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      // If .env file doesn't exist, try to continue with fallback
      // This allows the app to work in development with hardcoded values
      // but should be fixed for production
      print('⚠️ Warning: Could not load .env file: $e');
      print('⚠️ Using fallback values. Please create .env file for production.');
    }
  }
}
