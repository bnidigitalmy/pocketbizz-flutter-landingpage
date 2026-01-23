import 'package:flutter/foundation.dart';
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
    
    return await PersistentCacheService.getOrSync<List<Booking>>(
      key: cacheKey,
      fetcher: () async {
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
        if (!forceRefresh && lastSync != null) {
          query = query.gt('updated_at', lastSync.toIso8601String());
          debugPrint('🔄 Delta fetch: bookings updated after ${lastSync.toIso8601String()}');
        }
        
        // Order
        query = query.order('created_at', ascending: false);
        
        // If delta fetch, don't limit (get all updates)
        if (forceRefresh || lastSync == null) {
          query = query.limit(limit);
        }
        
        // Execute query
        final queryResult = await query;
        final deltaData = List<Map<String, dynamic>>.from(queryResult);
        
        // If delta fetch returns empty, do full fetch
        if (deltaData.isEmpty && lastSync != null && !forceRefresh) {
          debugPrint('🔄 Delta empty, fetching full bookings list');
          // Full fetch
          dynamic fullQuery = supabase
              .from('bookings')
              .select('*, booking_items(*)');
          
          if (status != null && status.isNotEmpty) {
            fullQuery = fullQuery.eq('status', status);
          }
          
          fullQuery = fullQuery.order('created_at', ascending: false).limit(limit);
          
          final fullResult = await fullQuery;
          return List<Map<String, dynamic>>.from(fullResult);
        }
        
        return deltaData;
      },
      fromJson: (json) => Booking.fromJson(json),
      toJson: (booking) => {
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
      },
      onDataUpdated: onDataUpdated != null 
          ? (data) => onDataUpdated(data)
          : null,
      forceRefresh: forceRefresh,
    );
  }
  
  /// Get booking by ID dengan cache
  Future<Booking> getBookingCached(String bookingId) async {
    // For single booking, use base repo
    return await _baseRepo.getBooking(bookingId);
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
}

