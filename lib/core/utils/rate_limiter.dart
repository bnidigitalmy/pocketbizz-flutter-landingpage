import 'dart:async';

/// Rate Limiter using Token Bucket Algorithm
/// 
/// Prevents API abuse and DDoS attacks by limiting the number of requests
/// that can be made within a specified time window.
class RateLimiter {
  final int maxRequests;
  final Duration window;
  final Map<String, _RateLimitWindow> _windows = {};
  
  /// Creates a rate limiter
  /// 
  /// [maxRequests] - Maximum number of requests allowed
  /// [window] - Time window for the limit (e.g., Duration(seconds: 60) for per-minute)
  RateLimiter({
    required this.maxRequests,
    required this.window,
  });

  /// Check if a request is allowed for the given key
  /// 
  /// Returns true if request is allowed, false if rate limit exceeded
  /// 
  /// [key] - Unique identifier for the rate limit (e.g., user ID, endpoint name)
  bool checkLimit(String key) {
    final now = DateTime.now();
    final windowKey = _getWindowKey(now);
    final fullKey = '$key:$windowKey';
    
    // Get or create window for this key
    final limitWindow = _windows.putIfAbsent(
      fullKey,
      () => _RateLimitWindow(
        maxRequests: maxRequests,
        windowStart: _getWindowStart(now),
      ),
    );
    
    // Clean up old windows
    _cleanupOldWindows(now);
    
    // Check if limit exceeded
    if (limitWindow.count >= maxRequests) {
      return false;
    }
    
    // Increment count
    limitWindow.count++;
    return true;
  }
  
  /// Get remaining requests for a key
  int getRemaining(String key) {
    final now = DateTime.now();
    final windowKey = _getWindowKey(now);
    final fullKey = '$key:$windowKey';
    
    final limitWindow = _windows[fullKey];
    if (limitWindow == null) {
      return maxRequests;
    }
    
    return (maxRequests - limitWindow.count).clamp(0, maxRequests);
  }
  
  /// Get time until next window resets
  Duration getTimeUntilReset(String key) {
    final now = DateTime.now();
    final windowStart = _getWindowStart(now);
    final nextWindowStart = windowStart.add(window);
    final timeUntilReset = nextWindowStart.difference(now);
    
    return timeUntilReset.isNegative ? Duration.zero : timeUntilReset;
  }
  
  /// Reset rate limit for a key (useful for testing or manual override)
  void reset(String key) {
    final now = DateTime.now();
    final windowKey = _getWindowKey(now);
    final fullKey = '$key:$windowKey';
    _windows.remove(fullKey);
  }
  
  /// Reset all rate limits
  void resetAll() {
    _windows.clear();
  }
  
  /// Get window key based on current time
  String _getWindowKey(DateTime now) {
    final windowStart = _getWindowStart(now);
    return windowStart.millisecondsSinceEpoch.toString();
  }
  
  /// Get window start time
  DateTime _getWindowStart(DateTime now) {
    final windowMs = window.inMilliseconds;
    final nowMs = now.millisecondsSinceEpoch;
    final windowStartMs = (nowMs ~/ windowMs) * windowMs;
    return DateTime.fromMillisecondsSinceEpoch(windowStartMs);
  }
  
  /// Clean up old windows (older than 2x window duration)
  void _cleanupOldWindows(DateTime now) {
    final cutoff = now.subtract(window * 2);
    final cutoffMs = cutoff.millisecondsSinceEpoch;
    
    _windows.removeWhere((key, window) {
      return window.windowStart.millisecondsSinceEpoch < cutoffMs;
    });
  }
}

/// Internal class to track rate limit window
class _RateLimitWindow {
  final int maxRequests;
  final DateTime windowStart;
  int count = 0;
  
  _RateLimitWindow({
    required this.maxRequests,
    required this.windowStart,
  });
}

/// Rate limit exception thrown when limit is exceeded
class RateLimitExceededException implements Exception {
  final String message;
  final Duration retryAfter;
  
  RateLimitExceededException({
    required this.message,
    required this.retryAfter,
  });
  
  @override
  String toString() => message;
}

/// Pre-configured rate limiters for different operation types
class RateLimiters {
  /// Rate limiter for read operations (GET requests)
  /// 100 requests per minute
  static final read = RateLimiter(
    maxRequests: 100,
    window: Duration(seconds: 60),
  );
  
  /// Rate limiter for write operations (POST, PUT, PATCH, DELETE)
  /// 30 requests per minute
  static final write = RateLimiter(
    maxRequests: 30,
    window: Duration(seconds: 60),
  );
  
  /// Rate limiter for expensive operations (reports, exports, etc.)
  /// 10 requests per minute
  static final expensive = RateLimiter(
    maxRequests: 10,
    window: Duration(seconds: 60),
  );
  
  /// Rate limiter for authentication operations
  /// 5 requests per minute (prevent brute force)
  static final auth = RateLimiter(
    maxRequests: 5,
    window: Duration(seconds: 60),
  );
  
  /// Rate limiter for file uploads
  /// 20 requests per minute
  static final upload = RateLimiter(
    maxRequests: 20,
    window: Duration(seconds: 60),
  );
  
  /// Get rate limiter by operation type
  static RateLimiter getByType(RateLimitType type) {
    switch (type) {
      case RateLimitType.read:
        return read;
      case RateLimitType.write:
        return write;
      case RateLimitType.expensive:
        return expensive;
      case RateLimitType.auth:
        return auth;
      case RateLimitType.upload:
        return upload;
    }
  }
}

/// Types of operations for rate limiting
enum RateLimitType {
  read,
  write,
  expensive,
  auth,
  upload,
}

