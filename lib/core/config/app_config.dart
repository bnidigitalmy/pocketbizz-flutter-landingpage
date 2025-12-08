/// App Configuration
/// Centralized configuration for API keys and secrets
class AppConfig {
  // Google OAuth Configuration
  // Get these from Google Cloud Console > APIs & Services > Credentials
  // For Flutter Web, only Client ID is needed (Client Secret is for server-side only)
  
  /// Google OAuth Client ID for Web Application
  /// Format: xxxxxx-xxxxx.apps.googleusercontent.com
  static const String googleOAuthClientId = '214368454746-pvb44rkgman7elikd61q37673mlrdnuf.apps.googleusercontent.com';
  
  // Note: Client Secret is NOT needed for client-side OAuth flows
  // Client Secret is only used for server-side OAuth (backend-to-backend)
}


