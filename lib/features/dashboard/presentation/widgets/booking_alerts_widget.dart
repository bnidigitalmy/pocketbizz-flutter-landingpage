import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/supabase/supabase_client.dart' show supabase;
import '../../../../core/theme/app_colors.dart';
import '../../../../data/repositories/bookings_repository_supabase.dart' show Booking;
import '../../../../data/repositories/bookings_repository_supabase_cached.dart';

/// Booking Alerts Widget for Dashboard
/// Shows bookings that need attention: overdue, upcoming, and pending
/// With real-time updates via Supabase subscriptions
class BookingAlertsWidget extends StatefulWidget {
  const BookingAlertsWidget({super.key});

  @override
  State<BookingAlertsWidget> createState() => _BookingAlertsWidgetState();
}

class _BookingAlertsWidgetState extends State<BookingAlertsWidget> {
  final _bookingsRepo = BookingsRepositorySupabaseCached();
  List<Booking> _overdueBookings = [];
  List<Booking> _upcomingBookings = [];
  List<Booking> _pendingBookings = [];
  bool _isLoading = true;

  // Real-time subscription
  StreamSubscription? _bookingsSubscription;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadBookings();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Setup real-time subscription for bookings table
  void _setupRealtimeSubscription() {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Subscribe to bookings changes for current user only
      _bookingsSubscription = supabase
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((data) {
            // Bookings updated - refresh alerts with debounce
            if (mounted) {
              _debouncedRefresh();
            }
          });

      debugPrint('✅ Booking Alerts real-time subscription setup complete');
    } catch (e) {
      debugPrint('⚠️ Error setting up booking alerts real-time subscription: $e');
    }
  }

  /// Debounced refresh to avoid excessive updates
  void _debouncedRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadBookings();
      }
    });
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final threeDaysFromNow = today.add(const Duration(days: 3));

      // Get all active bookings (pending, confirmed)
      final allBookings = await _bookingsRepo.listBookingsCached(
        limit: 200,
        onDataUpdated: (freshBookings) {
          if (mounted) {
            _processBookings(freshBookings);
          }
        },
      );
      
      final overdue = <Booking>[];
      final upcoming = <Booking>[];
      final pending = <Booking>[];

      for (final booking in allBookings) {
        // Skip completed/cancelled bookings
        if (booking.status.toLowerCase() == 'completed' ||
            booking.status.toLowerCase() == 'cancelled') {
          continue;
        }

        // Check if pending
        if (booking.status.toLowerCase() == 'pending') {
          pending.add(booking);
        }

        // Check delivery date
        try {
          final deliveryDate = DateTime.parse(booking.deliveryDate);
          final deliveryDateOnly = DateTime(
            deliveryDate.year,
            deliveryDate.month,
            deliveryDate.day,
          );

          // Overdue: delivery date is before today
          if (deliveryDateOnly.isBefore(today)) {
            overdue.add(booking);
          }
          // Upcoming: delivery date is within next 3 days (including today)
          else if (deliveryDateOnly.isBefore(threeDaysFromNow) ||
                   deliveryDateOnly.isAtSameMomentAs(today)) {
            // Only add if not already in overdue
            if (!overdue.contains(booking)) {
              upcoming.add(booking);
            }
          }
        } catch (e) {
          // Skip if date parsing fails
          debugPrint('Error parsing delivery date for booking ${booking.id}: $e');
        }
      }

      // Sort: overdue first, then by delivery date
      overdue.sort((a, b) {
        try {
          final dateA = DateTime.parse(a.deliveryDate);
          final dateB = DateTime.parse(b.deliveryDate);
          return dateA.compareTo(dateB);
        } catch (_) {
          return 0;
        }
      });

      upcoming.sort((a, b) {
        try {
          final dateA = DateTime.parse(a.deliveryDate);
          final dateB = DateTime.parse(b.deliveryDate);
          return dateA.compareTo(dateB);
        } catch (_) {
          return 0;
        }
      });

      if (mounted) {
        setState(() {
          _overdueBookings = overdue.take(5).toList();
          _upcomingBookings = upcoming.take(5).toList();
          _pendingBookings = pending.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading booking alerts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int get _totalAlerts => _overdueBookings.length + _upcomingBookings.length + _pendingBookings.length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_totalAlerts == 0) {
      return _buildCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: Colors.green[400],
              ),
              const SizedBox(height: 12),
              Text(
                'Tiada Tempahan Perlu Perhatian',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Semua tempahan terkawal',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.event_note_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alert Tempahan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Tempahan perlu perhatian',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_totalAlerts',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Overdue Bookings
          if (_overdueBookings.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.warning_amber_rounded,
              title: 'Tertunggak (${_overdueBookings.length})',
              color: Colors.red,
            ),
            ..._overdueBookings.map((b) => _buildBookingItem(b, isOverdue: true)),
          ],

          // Upcoming Bookings
          if (_upcomingBookings.isNotEmpty) ...[
            if (_overdueBookings.isNotEmpty) const Divider(height: 1),
            _buildSectionHeader(
              icon: Icons.schedule_rounded,
              title: 'Akan Datang (${_upcomingBookings.length})',
              color: Colors.orange,
            ),
            ..._upcomingBookings.map((b) => _buildBookingItem(b, isUpcoming: true)),
          ],

          // Pending Bookings
          if (_pendingBookings.isNotEmpty) ...[
            if (_overdueBookings.isNotEmpty || _upcomingBookings.isNotEmpty) const Divider(height: 1),
            _buildSectionHeader(
              icon: Icons.pending_actions_rounded,
              title: 'Menunggu Pengesahan (${_pendingBookings.length})',
              color: Colors.amber,
            ),
            ..._pendingBookings.map((b) => _buildBookingItem(b, isPending: true)),
          ],

          // View All Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed('/bookings');
                },
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Lihat Semua Tempahan'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: child,
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingItem(Booking booking, {
    bool isOverdue = false,
    bool isUpcoming = false,
    bool isPending = false,
  }) {
    String statusText = '';
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.info_outline;

    if (isOverdue) {
      statusText = 'Tertunggak';
      statusColor = Colors.red;
      statusIcon = Icons.error_outline;
    } else if (isUpcoming) {
      statusText = 'Akan Datang';
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
    } else if (isPending) {
      statusText = 'Menunggu';
      statusColor = Colors.amber;
      statusIcon = Icons.pending;
    }

    String deliveryDateText = '';
    try {
      final deliveryDate = DateTime.parse(booking.deliveryDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final deliveryDateOnly = DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day);
      final daysDiff = deliveryDateOnly.difference(today).inDays;

      if (daysDiff < 0) {
        deliveryDateText = '${daysDiff.abs()} hari lepas';
      } else if (daysDiff == 0) {
        deliveryDateText = 'Hari ini';
      } else if (daysDiff == 1) {
        deliveryDateText = 'Esok';
      } else {
        deliveryDateText = '$daysDiff hari lagi';
      }
    } catch (_) {
      deliveryDateText = booking.deliveryDate;
    }

    return InkWell(
      onTap: () {
        // Navigate to bookings page - user can find and view booking details there
        Navigator.of(context).pushNamed('/bookings').then((_) => _loadBookings());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Status Indicator
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),

            // Booking Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.bookingNumber,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(statusIcon, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '$statusText • ${booking.customerName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Delivery Date & Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    deliveryDateText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'RM ${booking.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

