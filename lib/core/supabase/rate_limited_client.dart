import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/rate_limiter.dart';
import '../utils/rate_limit_messages.dart';
import 'supabase_client.dart';

/// Rate-limited wrapper for Supabase client
/// 
/// Automatically applies rate limiting to prevent API abuse and DDoS attacks.
/// Different rate limits are applied based on operation type.
class RateLimitedSupabaseClient {
  final SupabaseClient _client;
  
  RateLimitedSupabaseClient(this._client);
  
  /// Get the underlying Supabase client
  SupabaseClient get client => _client;
  
  /// Execute a read operation with rate limiting
  Future<T> executeRead<T>({
    required Future<T> Function() operation,
    String? key,
  }) async {
    final userId = _client.auth.currentUser?.id ?? 'anonymous';
    final rateLimitKey = key ?? 'read:$userId';
    final limiter = RateLimiters.read;
    
    if (!limiter.checkLimit(rateLimitKey)) {
      final retryAfter = limiter.getTimeUntilReset(rateLimitKey);
      throw RateLimitExceededException(
        message: RateLimitMessages.getShortMessage(RateLimitType.read),
        retryAfter: retryAfter,
      );
    }
    
    return await operation();
  }
  
  /// Execute a write operation with rate limiting
  Future<T> executeWrite<T>({
    required Future<T> Function() operation,
    String? key,
  }) async {
    final userId = _client.auth.currentUser?.id ?? 'anonymous';
    final rateLimitKey = key ?? 'write:$userId';
    final limiter = RateLimiters.write;
    
    if (!limiter.checkLimit(rateLimitKey)) {
      final retryAfter = limiter.getTimeUntilReset(rateLimitKey);
      throw RateLimitExceededException(
        message: RateLimitMessages.getShortMessage(RateLimitType.write),
        retryAfter: retryAfter,
      );
    }
    
    return await operation();
  }
  
  /// Execute an expensive operation with rate limiting
  Future<T> executeExpensive<T>({
    required Future<T> Function() operation,
    String? key,
  }) async {
    final userId = _client.auth.currentUser?.id ?? 'anonymous';
    final rateLimitKey = key ?? 'expensive:$userId';
    final limiter = RateLimiters.expensive;
    
    if (!limiter.checkLimit(rateLimitKey)) {
      final retryAfter = limiter.getTimeUntilReset(rateLimitKey);
      throw RateLimitExceededException(
        message: RateLimitMessages.getShortMessage(RateLimitType.expensive),
        retryAfter: retryAfter,
      );
    }
    
    return await operation();
  }
  
  /// Execute an authentication operation with rate limiting
  Future<T> executeAuth<T>({
    required Future<T> Function() operation,
    String? key,
  }) async {
    final userId = _client.auth.currentUser?.id ?? 'anonymous';
    final rateLimitKey = key ?? 'auth:$userId';
    final limiter = RateLimiters.auth;
    
    if (!limiter.checkLimit(rateLimitKey)) {
      final retryAfter = limiter.getTimeUntilReset(rateLimitKey);
      throw RateLimitExceededException(
        message: RateLimitMessages.getShortMessage(RateLimitType.auth),
        retryAfter: retryAfter,
      );
    }
    
    return await operation();
  }
  
  /// Execute a file upload operation with rate limiting
  Future<T> executeUpload<T>({
    required Future<T> Function() operation,
    String? key,
  }) async {
    final userId = _client.auth.currentUser?.id ?? 'anonymous';
    final rateLimitKey = key ?? 'upload:$userId';
    final limiter = RateLimiters.upload;
    
    if (!limiter.checkLimit(rateLimitKey)) {
      final retryAfter = limiter.getTimeUntilReset(rateLimitKey);
      throw RateLimitExceededException(
        message: RateLimitMessages.getShortMessage(RateLimitType.upload),
        retryAfter: retryAfter,
      );
    }
    
    return await operation();
  }
  
  /// Get remaining requests for a specific operation type
  int getRemainingRequests(RateLimitType type, {String? key}) {
    final userId = _client.auth.currentUser?.id ?? 'anonymous';
    final rateLimitKey = key ?? '${type.name}:$userId';
    final limiter = RateLimiters.getByType(type);
    return limiter.getRemaining(rateLimitKey);
  }
  
  /// Get time until rate limit resets
  Duration getTimeUntilReset(RateLimitType type, {String? key}) {
    final userId = _client.auth.currentUser?.id ?? 'anonymous';
    final rateLimitKey = key ?? '${type.name}:$userId';
    final limiter = RateLimiters.getByType(type);
    return limiter.getTimeUntilReset(rateLimitKey);
  }
}

/// Global rate-limited Supabase client instance
/// Use this instead of direct `supabase` calls for rate-limited operations
final rateLimitedSupabase = RateLimitedSupabaseClient(supabase);

