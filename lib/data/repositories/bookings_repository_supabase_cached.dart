import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import 'bookings_repository_supabase.dart';

/// Cached version of BookingsRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive)
/// - Background sync dengan Supabase
/// - Delta fetch untuk jimat egress
/// - Offline-first approach
/// 
/// Priority: HIGH (Used in dashboard, booking alerts)
class BookingsRepositorySupabaseCached {
  final BookingsRepositorySupabase _baseRepo = BookingsRepositorySupabase();
  
  /// List all bookings dengan persistent cache + Stale-While-Revalidate
  /// 
  /// Returns cached data immediately, syncs in background
  Future<List<Booking>> listBookingsCached({
    String? status,
    int limit = 50,
    bool forceRefresh = false,
    void Function(List<Booking>)? onDataUpdated,
  }) async {
    // Build cache key dengan filters
    final cacheKey = 'bookings_${status ?? 'all'}_$limit';
    
    // Use direct Hive caching untuk List types (more reliable)
    if (!forceRefresh) {
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final cached = box.get('data');
        if (cached != null && cached is String) {
          final jsonList = jsonDecode(cached) as List<dynamic>;
          final bookings = jsonList.map((json) {
            final jsonMap = json as Map<String, dynamic>;
            return Booking.fromJson(jsonMap);
          }).toList();
          debugPrint('✅ Cache hit: $cacheKey');
          
          // Trigger background sync
          _syncBookingsInBackground(
            status: status,
            limit: limit,
            cacheKey: cacheKey,
            onDataUpdated: onDataUpdated,
          );
          
          return bookings;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached bookings: $e');
      }
    }
    
    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh data...');
    final fresh = await _fetchBookings(
      status: status,
      limit: limit,
    );
    
    // Cache it
    try {
      if (!Hive.isBoxOpen(cacheKey)) {
        await Hive.openBox(cacheKey);
      }
      final box = Hive.box(cacheKey);
      final jsonList = fresh.map((b) => _bookingToJson(b)).toList();
      await box.put('data', jsonEncode(jsonList));
      await _updateLastSync('bookings');
    } catch (e) {
      debugPrint('⚠️ Error caching bookings: $e');
    }
    
    return fresh;
  }
  
  /// Fetch bookings from Supabase
  Future<List<Booking>> _fetchBookings({
    String? status,
    int limit = 50,
  }) async {
    // Build query dengan delta fetch support
    final lastSync = await PersistentCacheService.getLastSync('bookings');
    
    // Build base query
    dynamic query = supabase
        .from('bookings')
        .select('*, booking_items(*)');
    
    // Apply status filter if provided
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }
    
    // Delta fetch: hanya ambil updated records
    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
      debugPrint('🔄 Delta fetch: bookings updated after ${lastSync.toIso8601String()}');
    }
    
    // Order
    query = query.order('created_at', ascending: false);
    
    // If delta fetch, don't limit (get all updates)
    if (lastSync == null) {
      query = query.limit(limit);
    }
    
    // Execute query
    final queryResult = await query;
    final deltaData = List<Map<String, dynamic>>.from(queryResult);
    
    // If delta fetch returns empty, do full fetch
    if (deltaData.isEmpty && lastSync != null) {
      debugPrint('🔄 Delta empty, fetching full bookings list');
      // Full fetch
      dynamic fullQuery = supabase
          .from('bookings')
          .select('*, booking_items(*)');
      
      if (status != null && status.isNotEmpty) {
        fullQuery = fullQuery.eq('status', status);
      }
      
      final fullResult = await fullQuery
          .order('created_at', ascending: false)
          .limit(limit);
      
      return (fullResult as List).map((json) => Booking.fromJson(json)).toList();
    }
    
    return deltaData.map((json) => Booking.fromJson(json)).toList();
  }
  
  /// Convert Booking to JSON for caching
  Map<String, dynamic> _bookingToJson(Booking booking) {
    return {
      'id': booking.id,
      'booking_number': booking.bookingNumber,
      'customer_name': booking.customerName,
      'customer_phone': booking.customerPhone,
      'customer_email': booking.customerEmail,
      'event_type': booking.eventType,
      'event_date': booking.eventDate,
      'delivery_date': booking.deliveryDate,
      'delivery_time': booking.deliveryTime,
      'delivery_location': booking.deliveryLocation,
      'notes': booking.notes,
      'discount_type': booking.discountType,
      'discount_value': booking.discountValue,
      'discount_amount': booking.discountAmount,
      'total_amount': booking.totalAmount,
      'deposit_amount': booking.depositAmount,
      'total_paid': booking.totalPaid,
      'status': booking.status,
      'created_at': booking.createdAt.toIso8601String(),
      'booking_items': booking.items?.map((item) => item.toJson()).toList(),
    };
  }
  
  /// Background sync for bookings
  Future<void> _syncBookingsInBackground({
    String? status,
    int limit = 50,
    required String cacheKey,
    void Function(List<Booking>)? onDataUpdated,
  }) async {
    try {
      final fresh = await _fetchBookings(
        status: status,
        limit: limit,
      );
      
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final jsonList = fresh.map((b) => _bookingToJson(b)).toList();
        await box.put('data', jsonEncode(jsonList));
        await _updateLastSync('bookings');
      } catch (e) {
        debugPrint('⚠️ Error updating bookings cache: $e');
      }
      
      if (onDataUpdated != null) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: $cacheKey');
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
  }
  
  /// Update last sync timestamp
  Future<void> _updateLastSync(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_$key', DateTime.now().toIso8601String());
  }
  
  /// Get booking by ID dengan cache
  Future<Booking> getBookingCached(String bookingId) async {
    // For single booking, use base repo
    return await _baseRepo.getBooking(bookingId);
  }
  
  // Delegate methods untuk write operations (no cache needed)
  
  /// Get booking by ID (delegate to base repo - no cache for single item)
  Future<Booking> getBooking(String bookingId) async {
    return await _baseRepo.getBooking(bookingId);
  }
  
  /// Update booking status (write operation - no cache)
  Future<Booking> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    final updated = await _baseRepo.updateBookingStatus(
      bookingId: bookingId,
      status: status,
    );
    // Invalidate cache after update
    await invalidateCache();
    return updated;
  }
  
  /// Record payment (write operation - no cache)
  Future<Map<String, dynamic>> recordPayment({
    required String bookingId,
    required double amount,
    required String paymentMethod,
    String? paymentReference,
    String? notes,
  }) async {
    final result = await _baseRepo.recordPayment(
      bookingId: bookingId,
      amount: amount,
      paymentMethod: paymentMethod,
      paymentReference: paymentReference,
      notes: notes,
    );
    // Invalidate cache after payment
    await invalidateCache();
    return result;
  }
  
  /// Get payment history (real-time data - no cache)
  Future<List<Map<String, dynamic>>> getPaymentHistory(String bookingId) async {
    return await _baseRepo.getPaymentHistory(bookingId);
  }
  
  /// Get booking statistics (real-time aggregation - no cache)
  Future<Map<String, dynamic>> getStatistics() async {
    return await _baseRepo.getStatistics();
  }
  
  /// Force refresh semua bookings dari Supabase
  Future<List<Booking>> refreshAll({
    String? status,
    int limit = 50,
  }) async {
    return await listBookingsCached(
      status: status,
      limit: limit,
      forceRefresh: true,
    );
  }
  
  /// Sync bookings in background (non-blocking)
  Future<void> syncInBackground({
    String? status,
    int limit = 50,
    void Function(List<Booking>)? onDataUpdated,
  }) async {
    try {
      await listBookingsCached(
        status: status,
        limit: limit,
        forceRefresh: false,
        onDataUpdated: onDataUpdated,
      );
      debugPrint('✅ Background sync completed: bookings');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }
  
  /// Invalidate bookings cache
  Future<void> invalidateCache() async {
    await PersistentCacheService.invalidate('bookings');
  }
  
  /// Expose base repository for widgets that need full BookingsRepositorySupabase interface
  BookingsRepositorySupabase get baseRepository => _baseRepo;
}

