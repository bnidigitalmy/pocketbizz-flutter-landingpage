import 'rate_limiter.dart';

/// User-friendly error messages for rate limiting (PocketBizz style)
/// 
/// Provides friendly, non-panic messages in Bahasa Malaysia
class RateLimitMessages {
  /// Get user-friendly message for rate limit exceeded
  /// 
  /// [type] - The operation type that was rate limited
  /// [retryAfter] - Duration until rate limit resets
  /// [retryAfterSeconds] - Seconds until rate limit resets (for convenience)
  static String getMessage(
    RateLimitType type, {
    Duration? retryAfter,
    int? retryAfterSeconds,
  }) {
    final seconds = retryAfterSeconds ?? retryAfter?.inSeconds ?? 60;
    
    switch (type) {
      case RateLimitType.write:
        // For create/update/delete operations (sales, products, etc.)
        if (seconds <= 2) {
          return 'Terlalu pantas 😅\nTunggu 1–2 saat sebelum sambung jualan.';
        } else {
          return 'Terlalu pantas 😅\nTunggu ${seconds} saat sebelum cuba lagi.';
        }
        
      case RateLimitType.auth:
        // For login/signup/password reset
        if (seconds <= 60) {
          return 'Terlalu banyak cubaan login.\nSila cuba semula selepas beberapa minit.';
        } else {
          final minutes = (seconds / 60).ceil();
          return 'Terlalu banyak cubaan login.\nSila cuba semula selepas $minutes minit.';
        }
        
      case RateLimitType.expensive:
        // For reports, exports, analytics
        if (seconds <= 30) {
          return 'Laporan sedang diproses.\nSila tunggu sebentar sebelum cuba lagi.';
        } else {
          final minutes = (seconds / 60).ceil();
          return 'Laporan sedang diproses.\nSila tunggu $minutes minit sebelum cuba lagi.';
        }
        
      case RateLimitType.upload:
        // For file uploads
        if (seconds <= 5) {
          return 'Terlalu banyak muat naik.\nTunggu sekejap sebelum cuba lagi.';
        } else {
          return 'Terlalu banyak muat naik.\nTunggu ${seconds} saat sebelum cuba lagi.';
        }
        
      case RateLimitType.read:
      default:
        // For read operations (fetching data)
        if (seconds <= 5) {
          return 'Terlalu pantas 😅\nTunggu sekejap sebelum sambung.';
        } else {
          return 'Terlalu pantas 😅\nTunggu ${seconds} saat sebelum cuba lagi.';
        }
    }
  }
  
  /// Get short message (for SnackBar/Toast)
  /// 
  /// Shorter version without detailed timing
  static String getShortMessage(RateLimitType type) {
    switch (type) {
      case RateLimitType.write:
        return 'Terlalu pantas 😅 Sila tunggu sekejap.';
        
      case RateLimitType.auth:
        return 'Terlalu banyak cubaan. Sila cuba semula selepas beberapa minit.';
        
      case RateLimitType.expensive:
        return 'Laporan sedang diproses. Sila tunggu sebentar.';
        
      case RateLimitType.upload:
        return 'Terlalu banyak muat naik. Tunggu sekejap.';
        
      case RateLimitType.read:
      default:
        return 'Terlalu pantas 😅 Sila tunggu sekejap.';
    }
  }
}

