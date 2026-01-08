/// Environment Configuration
/// Loads and provides access to environment variables
/// 
/// For Flutter Web: Use --dart-define during build
/// For Flutter Mobile: Use .env file
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // Supabase Configuration
  // Priority: --dart-define > .env file > fallback (hardcoded)
  static String get supabaseUrl {
    // Try --dart-define first (best for web)
    final dartDefineUrl = const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    if (dartDefineUrl.isNotEmpty) {
      return dartDefineUrl;
    }
    
    // Try .env file (for mobile/desktop)
    if (!kIsWeb) {
      final envUrl = dotenv.env['SUPABASE_URL'];
      if (envUrl != null && envUrl.isNotEmpty) {
        return envUrl;
      }
    }
    
    // Fallback (hardcoded - for web production)
    // This is safe because anon key is public by design (OAuth standard)
    return 'https://gxllowlurizrkvpdircw.supabase.co';
  }

  static String get supabaseAnonKey {
    // Try --dart-define first (best for web)
    final dartDefineKey = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    if (dartDefineKey.isNotEmpty) {
      return dartDefineKey;
    }
    
    // Try .env file (for mobile/desktop)
    if (!kIsWeb) {
      final envKey = dotenv.env['SUPABASE_ANON_KEY'];
      if (envKey != null && envKey.isNotEmpty) {
        return envKey;
      }
    }
    
    // Fallback (hardcoded - for web production)
    // This is safe because anon key is public by design (OAuth standard)
    return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4bGxvd2x1cml6cmt2cGRpcmN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMTAyMDksImV4cCI6MjA3OTc4NjIwOX0.Avft6LyKGwmU8JH3hXmO7ukNBlgG1XngjBX-prObycs';
  }

  // Google OAuth Configuration
  static String? get googleOAuthClientId {
    // Try --dart-define first
    final dartDefine = const String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID', defaultValue: '');
    if (dartDefine.isNotEmpty) {
      return dartDefine;
    }
    
    // Try .env file (for mobile/desktop)
    if (!kIsWeb) {
      return dotenv.env['GOOGLE_OAUTH_CLIENT_ID'];
    }
    
    // Fallback
    return '214368454746-pvb44rkgman7elikd61q37673mlrdnuf.apps.googleusercontent.com';
  }

  // Initialize environment variables
  // For web: Skip .env loading (use --dart-define or fallback)
  // For mobile: Load .env file
  static Future<void> load() async {
    if (kIsWeb) {
      // On web, skip .env loading entirely
      // Use --dart-define during build or fallback values
      debugPrint('EnvConfig: Web build - using --dart-define or fallback values');
      return;
    }

    // For mobile/desktop: Load .env file
    try {
      await dotenv.load(fileName: '.env');
      debugPrint('EnvConfig: Loaded .env file successfully');
    } catch (e) {
      // If .env file doesn't exist, continue with fallback
      debugPrint('⚠️ Warning: Could not load .env file: $e');
      debugPrint('⚠️ Using fallback values. Please create .env file for production.');
    }
  }
}
