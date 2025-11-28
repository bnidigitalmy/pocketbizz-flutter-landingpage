import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';

class BookingsService {
  final SupabaseClient _client = supabase;

  /// Create a new booking
  Future<Map<String, dynamic>> createBooking({
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    required String eventType,
    required String deliveryDate,
    String? deliveryTime,
    String? deliveryLocation,
    String? notes,
    required List<Map<String, dynamic>> items,
    String? discountType,
    double? discountValue,
    required double totalAmount,
    double? depositAmount,
  }) async {
    try {
      // 1. Generate booking number
      final bookingNumber = await _generateBookingNumber();

      // 2. Calculate totals
      final itemsTotal = items.fold<double>(
        0,
        (sum, item) => sum + (item['quantity'] * item['unit_price']),
      );

      double discountAmount = 0;
      if (discountType == 'percentage' && discountValue != null) {
        discountAmount = itemsTotal * (discountValue / 100);
      } else if (discountType == 'fixed' && discountValue != null) {
        discountAmount = discountValue;
      }

      final finalTotal = itemsTotal - discountAmount;

      // 3. Insert booking
      final booking = await _client.from('bookings').insert({
        'booking_number': bookingNumber,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_email': customerEmail,
        'event_type': eventType,
        'delivery_date': deliveryDate,
        'delivery_time': deliveryTime,
        'delivery_location': deliveryLocation,
        'notes': notes,
        'discount_type': discountType,
        'discount_value': discountValue,
        'discount_amount': discountAmount,
        'total_amount': finalTotal,
        'deposit_amount': depositAmount,
        'status': 'pending',
      }).select().single();

      // 4. Insert booking items
      final bookingItems = items.map((item) => {
        'booking_id': booking['id'],
        'product_id': item['product_id'],
        'product_name': item['product_name'],
        'quantity': item['quantity'],
        'unit_price': item['unit_price'],
        'subtotal': item['quantity'] * item['unit_price'],
      }).toList();

      await _client.from('booking_items').insert(bookingItems);

      // 5. Return booking with items
      return await getBooking(booking['id']);
    } catch (e) {
      rethrow;
    }
  }

  /// Generate booking number (B0001, B0002, etc.)
  Future<String> _generateBookingNumber() async {
    final count = await _client
        .from('bookings')
        .select('id', const FetchOptions(count: CountOption.exact));

    final nextNumber = (count.count ?? 0) + 1;
    return 'B${nextNumber.toString().padLeft(4, '0')}';
  }

  /// Get booking by ID with items
  Future<Map<String, dynamic>> getBooking(String bookingId) async {
    final booking = await _client
        .from('bookings')
        .select('*, booking_items(*)')
        .eq('id', bookingId)
        .single();

    return booking;
  }

  /// List all bookings
  Future<List<Map<String, dynamic>>> listBookings({
    String? status,
    int limit = 50,
  }) async {
    var query = _client
        .from('bookings')
        .select('*, booking_items(*)')
        .order('created_at', ascending: false)
        .limit(limit);

    if (status != null) {
      query = query.eq('status', status);
    }

    final bookings = await query;
    return List<Map<String, dynamic>>.from(bookings);
  }

  /// Update booking status
  Future<Map<String, dynamic>> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    final booking = await _client
        .from('bookings')
        .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', bookingId)
        .select()
        .single();

    return booking;
  }

  /// Delete booking
  Future<void> deleteBooking(String bookingId) async {
    await _client.from('bookings').delete().eq('id', bookingId);
  }

  /// Get booking statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final bookings = await _client.from('bookings').select('status, total_amount');

    final stats = {
      'total_bookings': bookings.length,
      'pending': 0,
      'confirmed': 0,
      'completed': 0,
      'cancelled': 0,
      'total_revenue': 0.0,
    };

    for (final booking in bookings) {
      stats[booking['status']] = (stats[booking['status']] as int) + 1;
      if (booking['status'] == 'completed') {
        stats['total_revenue'] = 
            (stats['total_revenue'] as double) + (booking['total_amount'] as num).toDouble();
      }
    }

    return stats;
  }
}

