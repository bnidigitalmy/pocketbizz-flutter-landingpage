import '../supabase/rate_limited_client.dart';
import 'rate_limiter.dart';

/// Mixin to add rate limiting to repository classes
/// 
/// Usage:
/// ```dart
/// class MyRepository with RateLimitMixin {
///   Future<List<Item>> getAll() async {
///     return await executeWithRateLimit(
///       type: RateLimitType.read,
///       operation: () async {
///         return await supabase.from('items').select();
///       },
///     );
///   }
/// }
/// ```
mixin RateLimitMixin {
  /// Execute an operation with rate limiting
  /// 
  /// [type] - Type of operation (read, write, expensive, auth, upload)
  /// [operation] - The operation to execute
  /// [key] - Optional custom key for rate limiting (defaults to user-based)
  Future<T> executeWithRateLimit<T>({
    required RateLimitType type,
    required Future<T> Function() operation,
    String? key,
  }) async {
    switch (type) {
      case RateLimitType.read:
        return await rateLimitedSupabase.executeRead(
          operation: operation,
          key: key,
        );
      case RateLimitType.write:
        return await rateLimitedSupabase.executeWrite(
          operation: operation,
          key: key,
        );
      case RateLimitType.expensive:
        return await rateLimitedSupabase.executeExpensive(
          operation: operation,
          key: key,
        );
      case RateLimitType.auth:
        return await rateLimitedSupabase.executeAuth(
          operation: operation,
          key: key,
        );
      case RateLimitType.upload:
        return await rateLimitedSupabase.executeUpload(
          operation: operation,
          key: key,
        );
    }
  }
  
  /// Get remaining requests for an operation type
  int getRemainingRequests(RateLimitType type, {String? key}) {
    return rateLimitedSupabase.getRemainingRequests(type, key: key);
  }
  
  /// Get time until rate limit resets
  Duration getTimeUntilReset(RateLimitType type, {String? key}) {
    return rateLimitedSupabase.getTimeUntilReset(type, key: key);
  }
}

