/**
 * 🔒 STABLE CORE MODULE – DO NOT MODIFY
 * This file is production-tested.
 * Any changes must be isolated via extension or wrapper.
 */
// ❌ AI WARNING:
// DO NOT refactor, rename, optimize or restructure this logic.
// Only READ-ONLY reference allowed.

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import '../../../data/repositories/bookings_repository_supabase.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart' show supabase;

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  final _repo = BookingsRepositorySupabase();
  List<Booking> _bookings = [];
  bool _loading = false;
  String? _selectedStatus;

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
            // Bookings updated - refresh with debounce
            if (mounted) {
              _debouncedRefresh();
            }
          });

      debugPrint('✅ Bookings page real-time subscription setup complete');
    } catch (e) {
      debugPrint('⚠️ Error setting up bookings real-time subscription: $e');
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
    setState(() => _loading = true);

    try {
      final bookings = await _repo.listBookings(status: _selectedStatus);
      setState(() {
        _bookings = bookings;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (status) {
              setState(() => _selectedStatus = status == 'all' ? null : status);
              _loadBookings();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'pending', child: Text('Pending')),
              const PopupMenuItem(value: 'confirmed', child: Text('Confirmed')),
              const PopupMenuItem(value: 'completed', child: Text('Completed')),
              const PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBookings,
              child: _bookings.isEmpty
                  ? const Center(
                      child: Text('No bookings yet. Create your first booking!'),
                    )
                  : ListView.builder(
                      itemCount: _bookings.length,
                      itemBuilder: (context, index) {
                        final booking = _bookings[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            title: Text(
                              '${booking.bookingNumber} - ${booking.customerName}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(booking.eventType),
                                Text('Delivery: ${booking.deliveryDate}'),
                                Text(
                                  'Total: RM${booking.totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            trailing: _buildStatusChip(booking.status),
                            onTap: () => _showBookingDetails(booking),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to create page - real-time subscription will auto-update
          await Navigator.of(context).pushNamed('/bookings/create');
          // No manual reload needed - real-time subscription handles updates
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tempahan Baru'),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'confirmed':
        color = Colors.blue;
        break;
      case 'completed':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      backgroundColor: color,
    );
  }

  Future<void> _showBookingDetails(Booking booking) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.bookingNumber,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Customer', booking.customerName),
              _buildDetailRow('Phone', booking.customerPhone),
              if (booking.customerEmail != null)
                _buildDetailRow('Email', booking.customerEmail!),
              _buildDetailRow('Event Type', booking.eventType),
              _buildDetailRow('Delivery Date', booking.deliveryDate),
              if (booking.deliveryLocation != null)
                _buildDetailRow('Location', booking.deliveryLocation!),
              const Divider(),
              _buildDetailRow(
                'Total Amount',
                'RM${booking.totalAmount.toStringAsFixed(2)}',
              ),
              if (booking.depositAmount != null)
                _buildDetailRow(
                  'Deposit',
                  'RM${booking.depositAmount!.toStringAsFixed(2)}',
                ),
              const SizedBox(height: 16),
              if (booking.items != null && booking.items!.isNotEmpty) ...[
                const Text(
                  'Items:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...booking.items!.map((item) => ListTile(
                      title: Text(item.productName),
                      subtitle: Text('Qty: ${item.quantity}'),
                      trailing: Text('RM${item.subtotal.toStringAsFixed(2)}'),
                    )),
              ],
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _updateStatus(booking.id, 'confirmed');
                      },
                      child: const Text('Confirm'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _updateStatus(booking.id, 'completed');
                      },
                      child: const Text('Complete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String bookingId, String status) async {
    try {
      await _repo.updateBookingStatus(bookingId: bookingId, status: status);
      // No manual reload needed - real-time subscription will auto-update
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking updated to $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

}

