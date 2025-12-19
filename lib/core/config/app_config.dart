/// App Configuration
/// Centralized configuration for API keys and secrets
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Google OAuth Configuration
  // Get these from Google Cloud Console > APIs & Services > Credentials
  // For Flutter Web, only Client ID is needed (Client Secret is for server-side only)
  
  /// Google OAuth Client ID for Web Application
  /// Format: xxxxxx-xxxxx.apps.googleusercontent.com
  /// Environment variable is REQUIRED for production
  /// Note: Client IDs are public by design (OAuth standard), but using env vars is best practice
  static String get googleOAuthClientId {
    final clientId = dotenv.env['GOOGLE_OAUTH_CLIENT_ID'];
    if (clientId == null) {
      throw Exception(
        '❌ CRITICAL: Missing GOOGLE_OAUTH_CLIENT_ID environment variable!\n'
        'Please create a .env file with:\n'
        '  GOOGLE_OAUTH_CLIENT_ID=your_google_oauth_client_id\n'
        '\n'
        'For production, this must be set via environment variables.'
      );
    }
    return clientId;
  }
  
  // Note: Client Secret is NOT needed for client-side OAuth flows
  // Client Secret is only used for server-side OAuth (backend-to-backend)
}



