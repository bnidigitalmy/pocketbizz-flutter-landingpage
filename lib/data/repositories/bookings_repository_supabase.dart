import '../../core/supabase/supabase_client.dart';
import '../../core/utils/rate_limit_mixin.dart';
import '../../core/utils/rate_limiter.dart';

/**
 * 🔒 POCKETBIZZ CORE ENGINE (STABLE)
 * ❌ DO NOT MODIFY
 * ❌ DO NOT REFACTOR
 * ❌ DO NOT OPTIMIZE
 * This logic is production-tested.
 * New features must EXTEND, not change.
 * 
 * Balance calculation: totalAmount - depositAmount - totalPaid
 * This formula is used consistently across UI, repository, and PDF generation.
 */
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
  final double totalPaid; // Total amount paid (sum of all payments)
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
    this.totalPaid = 0.0,
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
      totalPaid: json['total_paid']?.toDouble() ?? 0.0,
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

/**
 * 🔒 POCKETBIZZ CORE ENGINE (STABLE)
 * ❌ DO NOT MODIFY
 * ❌ DO NOT REFACTOR
 * ❌ DO NOT OPTIMIZE
 * This logic is production-tested.
 * New features must EXTEND, not change.
 * 
 * recordPayment() uses: remainingBalance = totalAmount - depositAmount - totalPaid
 * This calculation must remain consistent with UI and PDF generation.
 */
/// Bookings repository using Supabase with rate limiting
class BookingsRepositorySupabase with RateLimitMixin {
  /// Get booking prefix from business_profile (optional user prefix)
  /// Returns format: "USER_PREFIX-BKG" or "BKG" if no user prefix
  Future<String> _getBookingPrefix(String userId) async {
    try {
      final profileResponse = await supabase
          .from('business_profile')
          .select('booking_prefix')
          .eq('business_owner_id', userId)
          .maybeSingle();
      
      final userPrefix = profileResponse?['booking_prefix'] as String?;
      if (userPrefix != null && userPrefix.isNotEmpty) {
        return '${userPrefix.toUpperCase()}-BKG';
      }
      return 'BKG'; // No user prefix, use original format
    } catch (e) {
      return 'BKG'; // Fallback to default
    }
  }

  /// Get next booking sequence number for current month (per owner)
  Future<int> _getNextBookingSeqForMonth({
    required String userId,
    required String prefixWithDash, // e.g. "BKG-2512-" or "ABC-BKG-2512-"
  }) async {
    final rows = await supabase
        .from('bookings')
        .select('booking_number')
        .eq('business_owner_id', userId)
        .or('booking_number.like.$prefixWithDash%,booking_number.ilike.B%')
        .order('booking_number', ascending: false)
        .limit(50);

    int maxSeq = 0;
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final bookingNumber = row['booking_number'] as String?;
      if (bookingNumber == null) continue;
      
      // Handle new format: USER_PREFIX-BKG-YYMM-XXXX
      if (bookingNumber.contains(prefixWithDash)) {
        final lastDash = bookingNumber.lastIndexOf('-');
        if (lastDash >= 0 && lastDash < bookingNumber.length - 1) {
          final suffix = bookingNumber.substring(lastDash + 1);
          final n = int.tryParse(suffix);
          if (n != null && n > maxSeq) maxSeq = n;
        }
      }
      // Handle old format: B0001, B0002, etc.
      else if (bookingNumber.startsWith('B') && bookingNumber.length > 1) {
        try {
          final numberPart = bookingNumber.substring(1).split('-')[0].split('_')[0];
          final n = int.tryParse(numberPart);
          if (n != null && n > maxSeq) maxSeq = n;
        } catch (e) {
          // Skip invalid formats
        }
      }
    }

    return maxSeq + 1;
  }

  /// Generate booking number with prefix support
  /// Format: USER_PREFIX-BKG-YYMM-0001 or BKG-YYMM-0001
  /// Falls back to old format (B0001) for compatibility
  Future<String> _generateBookingNumber({int retryAttempt = 0}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final prefix = await _getBookingPrefix(userId);
      final now = DateTime.now();
      final yy = (now.year % 100).toString().padLeft(2, '0');
      final mm = now.month.toString().padLeft(2, '0');
      final prefixWithDash = '$prefix-$yy$mm-';
      
      final seqNum = await _getNextBookingSeqForMonth(
        userId: userId,
        prefixWithDash: prefixWithDash,
      );

      final baseNumber = '$prefixWithDash${seqNum.toString().padLeft(4, '0')}';
      
      // Add timestamp suffix for retry attempts to ensure uniqueness
      if (retryAttempt > 0) {
        final timestamp = DateTime.now().millisecondsSinceEpoch % 10000;
        return '${baseNumber}_$timestamp';
      }
      
      return baseNumber;
    } catch (e) {
      // Fallback to old format if prefix generation fails
      final result = await supabase
          .from('bookings')
          .select('booking_number')
          .order('booking_number', ascending: false)
          .limit(1)
          .maybeSingle();

      int nextNumber = 1;
      if (result != null && result['booking_number'] != null) {
        final lastNumber = result['booking_number'] as String;
        if (lastNumber.startsWith('B')) {
          try {
            final numberPart = lastNumber.substring(1).split('-')[0].split('_')[0];
            final lastNum = int.parse(numberPart);
            nextNumber = lastNum + 1;
          } catch (e) {
            final count = await supabase.from('bookings').count();
            nextNumber = count + 1;
          }
        }
      }

      final baseNumber = 'B${nextNumber.toString().padLeft(4, '0')}';
      if (retryAttempt > 0) {
        final timestamp = DateTime.now().millisecondsSinceEpoch % 10000;
        return '${baseNumber}_$timestamp';
      }
      return baseNumber;
    }
  }

  /// Create a new booking with rate limiting
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
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
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
    int maxRetries = 10; // Increased retries
    int retryCount = 0;
    
    while (booking == null && retryCount < maxRetries) {
      try {
        // Generate booking number with retry attempt for uniqueness
        final bookingNumber = await _generateBookingNumber(retryAttempt: retryCount);

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
          // Wait with exponential backoff + random jitter to avoid immediate collision
          final baseDelay = 200 * (1 << retryCount); // Exponential: 200ms, 400ms, 800ms, etc.
          final jitter = (baseDelay * 0.2 * (retryCount % 3)); // Random jitter
          await Future.delayed(Duration(milliseconds: (baseDelay + jitter).round()));
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
    final finalBooking = booking;

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
      },
    );
  }

  /// Get booking by ID with items and rate limiting
  Future<Booking> getBooking(String bookingId) async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        final data = await supabase
            .from('bookings')
            .select('*, booking_items(*)')
            .eq('id', bookingId)
            .single();

        return Booking.fromJson(data);
      },
    );
  }

  /// List all bookings with rate limiting
  Future<List<Booking>> listBookings({
    String? status,
    int limit = 50,
  }) async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
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
      },
    );
  }

  /// Update booking status with rate limiting
  Future<Booking> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
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
      },
    );
  }

  /// Delete booking with rate limiting
  Future<void> deleteBooking(String bookingId) async {
    await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        await supabase.from('bookings').delete().eq('id', bookingId);
      },
    );
  }

  /// Get booking statistics with rate limiting
  Future<Map<String, dynamic>> getStatistics() async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
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
      },
    );
  }

  /// Record a payment for a booking with rate limiting
  Future<Map<String, dynamic>> recordPayment({
    required String bookingId,
    required double amount,
    required String paymentMethod,
    String? paymentReference,
    String? notes,
  }) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Validate amount
    if (amount <= 0) {
      throw Exception('Payment amount must be greater than 0');
    }

    // Get booking to check total
    final booking = await getBooking(bookingId);
    final remainingBalance = booking.totalAmount - (booking.depositAmount ?? 0.0) - booking.totalPaid;
    
    if (amount > remainingBalance) {
      throw Exception('Payment amount (RM${amount.toStringAsFixed(2)}) exceeds remaining balance (RM${remainingBalance.toStringAsFixed(2)})');
    }

    // Insert payment
    final paymentData = await supabase
        .from('booking_payments')
        .insert({
          'business_owner_id': userId,
          'booking_id': bookingId,
          'payment_date': DateTime.now().toIso8601String().split('T')[0],
          'payment_time': DateTime.now().toIso8601String().split('T')[1].split('.')[0],
          'payment_amount': amount,
          'payment_method': paymentMethod,
          'payment_reference': paymentReference,
          'notes': notes,
        })
        .select()
        .single();

        // Get updated booking with new total_paid
        final updatedBooking = await getBooking(bookingId);

        return {
          'payment': paymentData,
          'booking': updatedBooking,
          'remaining_balance': updatedBooking.totalAmount - (updatedBooking.depositAmount ?? 0.0) - updatedBooking.totalPaid,
        };
      },
    );
  }

  /// Get payment history for a booking with rate limiting
  Future<List<Map<String, dynamic>>> getPaymentHistory(String bookingId) async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        final payments = await supabase
            .from('booking_payments')
            .select('*')
            .eq('booking_id', bookingId)
            .order('payment_date', ascending: false)
            .order('payment_time', ascending: false);

        return (payments as List).map((p) => p as Map<String, dynamic>).toList();
      },
    );
  }
}

