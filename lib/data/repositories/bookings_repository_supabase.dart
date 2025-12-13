import '../../core/supabase/supabase_client.dart';

/// Booking model
class Booking {
  final String id;
  final String bookingNumber;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String eventType;
  final String? eventDate;
  final String deliveryDate;
  final String? deliveryTime;
  final String? deliveryLocation;
  final String? notes;
  final String? discountType;
  final double? discountValue;
  final double? discountAmount;
  final double totalAmount;
  final double? depositAmount;
  final String status;
  final DateTime createdAt;
  final List<BookingItem>? items;

  Booking({
    required this.id,
    required this.bookingNumber,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.eventType,
    this.eventDate,
    required this.deliveryDate,
    this.deliveryTime,
    this.deliveryLocation,
    this.notes,
    this.discountType,
    this.discountValue,
    this.discountAmount,
    required this.totalAmount,
    this.depositAmount,
    required this.status,
    required this.createdAt,
    this.items,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'],
      bookingNumber: json['booking_number'],
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      customerEmail: json['customer_email'],
      eventType: json['event_type'],
      eventDate: json['event_date'],
      deliveryDate: json['delivery_date'],
      deliveryTime: json['delivery_time'],
      deliveryLocation: json['delivery_location'],
      notes: json['notes'],
      discountType: json['discount_type'],
      discountValue: json['discount_value']?.toDouble(),
      discountAmount: json['discount_amount']?.toDouble(),
      totalAmount: json['total_amount']?.toDouble() ?? 0.0,
      depositAmount: json['deposit_amount']?.toDouble(),
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at']),
      items: json['booking_items'] != null
          ? (json['booking_items'] as List)
              .map((item) => BookingItem.fromJson(item))
              .toList()
          : null,
    );
  }
}

/// Booking item model
class BookingItem {
  final String id;
  final String bookingId;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  BookingItem({
    required this.id,
    required this.bookingId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    return BookingItem(
      id: json['id'],
      bookingId: json['booking_id'],
      productId: json['product_id'],
      productName: json['product_name'],
      quantity: json['quantity']?.toDouble() ?? 0.0,
      unitPrice: json['unit_price']?.toDouble() ?? 0.0,
      subtotal: json['subtotal']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
    };
  }
}

/// Bookings repository using Supabase
class BookingsRepositorySupabase {
  /// Generate booking number (B0001, B0002, etc.)
  /// Uses max booking number to avoid race conditions
  Future<String> _generateBookingNumber() async {
    // Get the max booking number to avoid race conditions
    final result = await supabase
        .from('bookings')
        .select('booking_number')
        .order('booking_number', ascending: false)
        .limit(1)
        .maybeSingle();

    int nextNumber = 1;
    
    if (result != null && result['booking_number'] != null) {
      final lastNumber = result['booking_number'] as String;
      // Extract number from format like "B0001"
      if (lastNumber.startsWith('B')) {
        try {
          final numberStr = lastNumber.substring(1);
          final lastNum = int.parse(numberStr);
          nextNumber = lastNum + 1;
        } catch (e) {
          // If parsing fails, fall back to count
          final count = await supabase.from('bookings').count();
          nextNumber = count + 1;
        }
      }
    }

    return 'B${nextNumber.toString().padLeft(4, '0')}';
  }

  /// Create a new booking
  Future<Booking> createBooking({
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    required String eventType,
    String? eventDate,
    required String deliveryDate,
    String? deliveryTime,
    String? deliveryLocation,
    String? notes,
    required List<Map<String, dynamic>> items,
    String? discountType,
    double? discountValue,
    double? depositAmount,
  }) async {
    // Calculate totals
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

    // Get current user ID
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Insert booking with retry logic for duplicate booking_number
    Booking? booking;
    int maxRetries = 5;
    int retryCount = 0;
    
    while (booking == null && retryCount < maxRetries) {
      try {
        // Generate booking number
        final bookingNumber = await _generateBookingNumber();

        // Insert booking
        final bookingData = await supabase.from('bookings').insert({
          'business_owner_id': userId,
          'booking_number': bookingNumber,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'customer_email': customerEmail,
          'event_type': eventType,
          'event_date': eventDate,
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
        
        booking = Booking.fromJson(bookingData);
      } catch (e) {
        final errorString = e.toString().toLowerCase();
        
        // If duplicate booking_number error, retry with new number
        if (errorString.contains('duplicate') || 
            errorString.contains('unique constraint') ||
            errorString.contains('bookings_booking_number_key') ||
            errorString.contains('409')) {
          retryCount++;
          if (retryCount >= maxRetries) {
            throw Exception('Failed to create booking: Unable to generate unique booking number after $maxRetries attempts. Please try again.');
          }
          // Wait a bit before retry to avoid immediate collision
          await Future.delayed(Duration(milliseconds: 100 * retryCount));
        } else {
          // Other errors, throw immediately
          throw Exception('Failed to create booking: $e');
        }
      }
    }
    
    if (booking == null) {
      throw Exception('Failed to create booking: Unable to generate unique booking number.');
    }

    // At this point, booking is guaranteed to be non-null
    final finalBooking = booking!;

    // Insert booking items
    final bookingItems = items.map((item) => {
      'business_owner_id': userId, // Required for RLS policy
      'booking_id': finalBooking.id,
      'product_id': item['product_id'],
      'product_name': item['product_name'],
      'quantity': item['quantity'],
      'unit_price': item['unit_price'],
      'subtotal': item['quantity'] * item['unit_price'],
    }).toList();

    await supabase.from('booking_items').insert(bookingItems);

    // Return booking with items
    return getBooking(finalBooking.id);
  }

  /// Get booking by ID with items
  Future<Booking> getBooking(String bookingId) async {
    final data = await supabase
        .from('bookings')
        .select('*, booking_items(*)')
        .eq('id', bookingId)
        .single();

    return Booking.fromJson(data);
  }

  /// List all bookings
  Future<List<Booking>> listBookings({
    String? status,
    int limit = 50,
  }) async {
    var query = supabase
        .from('bookings')
        .select('*, booking_items(*)');

    // Apply status filter if provided
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    // Execute query with order and limit
    final data = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List).map((json) => Booking.fromJson(json)).toList();
  }

  /// Update booking status
  Future<Booking> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    final data = await supabase
        .from('bookings')
        .update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', bookingId)
        .select('*, booking_items(*)')
        .single();

    return Booking.fromJson(data);
  }

  /// Delete booking
  Future<void> deleteBooking(String bookingId) async {
    await supabase.from('bookings').delete().eq('id', bookingId);
  }

  /// Get booking statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final bookings = await supabase
        .from('bookings')
        .select('status, total_amount');

    final stats = {
      'total_bookings': bookings.length,
      'pending': 0,
      'confirmed': 0,
      'completed': 0,
      'cancelled': 0,
      'total_revenue': 0.0,
    };

    for (final booking in bookings) {
      final status = booking['status'] as String;
      stats[status] = (stats[status] as int) + 1;
      
      if (status == 'completed') {
        stats['total_revenue'] = 
            (stats['total_revenue'] as double) + 
            (booking['total_amount'] as num).toDouble();
      }
    }

    return stats;
  }
}

