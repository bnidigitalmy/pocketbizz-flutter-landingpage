import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/bookings_repository_supabase.dart';
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../../../core/utils/booking_pdf_generator.dart';
import 'create_booking_page_enhanced.dart';

/// Optimized Bookings Page
/// Full-featured booking management with PDF and WhatsApp sharing
class BookingsPageOptimized extends StatefulWidget {
  const BookingsPageOptimized({super.key});

  @override
  State<BookingsPageOptimized> createState() => _BookingsPageOptimizedState();
}

class _BookingsPageOptimizedState extends State<BookingsPageOptimized> {
  final _repo = BookingsRepositorySupabase();
  final _businessProfileRepo = BusinessProfileRepository();
  List<Booking> _bookings = [];
  List<Booking> _filteredBookings = [];
  bool _loading = false;
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);

    try {
      final bookings = await _repo.listBookings();
      setState(() {
        _bookings = bookings;
        _filterBookings();
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

  void _filterBookings() {
    if (_selectedStatus == 'all') {
      _filteredBookings = _bookings;
    } else {
      _filteredBookings = _bookings.where((b) => b.status == _selectedStatus).toList();
    }
  }

  int get _pendingCount => _bookings.where((b) => b.status == 'pending').length;
  int get _confirmedCount => _bookings.where((b) => b.status == 'confirmed').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tempahan & Reservasi',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Urus tempahan majlis - perkahwinan, kenduri, door gifts',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (status) {
              setState(() {
                _selectedStatus = status;
                _filterBookings();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('Semua Status')),
              const PopupMenuItem(value: 'pending', child: Text('Menunggu')),
              const PopupMenuItem(value: 'confirmed', child: Text('Disahkan')),
              const PopupMenuItem(value: 'completed', child: Text('Selesai')),
              const PopupMenuItem(value: 'cancelled', child: Text('Dibatalkan')),
            ],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_getStatusLabel(_selectedStatus)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBookings,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Stats Cards
                  _buildStatsCards(),

                  const SizedBox(height: 24),

                  // Bookings List
                  if (_filteredBookings.isEmpty)
                    _buildEmptyState()
                  else
                    ..._filteredBookings.map((booking) => _buildBookingCard(booking)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CreateBookingPageEnhanced()),
          );
          if (result == true && mounted) {
            _loadBookings();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Tempahan Baru'),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Menunggu',
            _pendingCount.toString(),
            Icons.pending_actions_rounded,
            Colors.orange,
            'Perlu disahkan',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Disahkan',
            _confirmedCount.toString(),
            Icons.check_circle_rounded,
            Colors.blue,
            'Tempahan aktif',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Jumlah',
            _bookings.length.toString(),
            Icons.event_note_rounded,
            AppColors.primary,
            'Semua tempahan',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Tiada tempahan ${_selectedStatus != 'all' ? 'dengan status "${_getStatusLabel(_selectedStatus)}"' : ''}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            booking.bookingNumber,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(booking.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatEventType(booking.eventType),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download_rounded),
                      tooltip: 'Muat Turun PDF',
                      onPressed: () => _downloadPDF(booking),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded),
                      tooltip: 'Kongsi WhatsApp',
                      onPressed: () => _shareWhatsApp(booking),
                    ),
                  ],
                ),
              ],
            ),

            const Divider(),

            // Customer Info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(Icons.person, booking.customerName),
                      const SizedBox(height: 4),
                      _buildInfoRow(Icons.phone, booking.customerPhone),
                      if (booking.customerEmail != null) ...[
                        const SizedBox(height: 4),
                        _buildInfoRow(Icons.email, booking.customerEmail!),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        Icons.calendar_today,
                        'Hantar: ${DateFormat('dd MMM yyyy', 'ms_MY').format(DateTime.parse(booking.deliveryDate))}',
                      ),
                      if (booking.deliveryTime != null) ...[
                        const SizedBox(height: 4),
                        _buildInfoRow(Icons.access_time, booking.deliveryTime!),
                      ],
                      if (booking.deliveryLocation != null) ...[
                        const SizedBox(height: 4),
                        _buildInfoRow(Icons.location_on, booking.deliveryLocation!),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (booking.items != null && booking.items!.isNotEmpty) ...[
              const Divider(),
              const Text(
                'Produk Ditempah:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...booking.items!.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.productName,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                        Chip(
                          label: Text('${item.quantity}x'),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  )),
            ],

            const Divider(),

            // Total & Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jumlah: RM${booking.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (booking.depositAmount != null)
                      Text(
                        'Deposit: RM${booking.depositAmount!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (booking.status == 'pending')
                      ElevatedButton.icon(
                        onPressed: () => _updateStatus(booking.id, 'confirmed'),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Sahkan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    if (booking.status == 'confirmed') ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _updateStatus(booking.id, 'completed'),
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text('Selesai'),
                      ),
                    ],
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _showCancelDialog(booking),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Batal'),
                    ),
                  ],
                ),
              ],
            ),

            if (booking.notes != null && booking.notes!.isNotEmpty) ...[
              const Divider(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nota:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking.notes!,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'Menunggu';
        icon = Icons.pending_actions_rounded;
        break;
      case 'confirmed':
        color = Colors.blue;
        label = 'Disahkan';
        icon = Icons.check_circle_rounded;
        break;
      case 'completed':
        color = Colors.green;
        label = 'Selesai';
        icon = Icons.done_all_rounded;
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Dibatalkan';
        icon = Icons.cancel_rounded;
        break;
      default:
        color = Colors.grey;
        label = status;
        icon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'all':
        return 'Semua Status';
      case 'pending':
        return 'Menunggu';
      case 'confirmed':
        return 'Disahkan';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  String _formatEventType(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'perkahwinan':
        return 'Perkahwinan';
      case 'kenduri':
        return 'Kenduri';
      case 'door_gifts':
        return 'Door Gifts';
      case 'birthday':
        return 'Hari Jadi';
      case 'aqiqah':
        return 'Aqiqah';
      case 'lain-lain':
        return 'Lain-lain';
      default:
        return eventType;
    }
  }

  Future<void> _downloadPDF(Booking booking) async {
    try {
      // Fetch business profile for invoice
      final businessProfile = await _businessProfileRepo.getBusinessProfile();
      
      // Generate invoice number (format: INV-YYMM-XXXX)
      final invoiceNumber = _generateInvoiceNumber(booking.createdAt);
      
      final pdfBytes = await BookingPDFGenerator.generateBookingInvoice(
        booking,
        businessProfile: businessProfile,
        invoiceNumber: invoiceNumber,
      );

      final filename = '$invoiceNumber.pdf';

      if (kIsWeb) {
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ PDF berjaya dimuat turun!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: filename,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ PDF berjaya dihasilkan!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareWhatsApp(Booking booking) async {
    try {
      final itemsTotal = booking.items?.fold<double>(
            0.0,
            (sum, item) => sum + item.subtotal,
          ) ??
          0.0;

      var message = '*TEMPAHAN INVOICE*%0A%0A';
      message += '*PocketBizz*%0A';
      message += 'No. Tempahan: ${booking.bookingNumber}%0A%0A';

      message += '*PELANGGAN*%0A';
      message += '${booking.customerName}%0A';
      message += '${booking.customerPhone}%0A%0A';

      message += '*MAJLIS*%0A';
      message += 'Jenis: ${_formatEventType(booking.eventType)}%0A';
      message += 'Tarikh Hantar: ${DateFormat('dd MMMM yyyy', 'ms_MY').format(DateTime.parse(booking.deliveryDate))}%0A%0A';

      if (booking.items != null && booking.items!.isNotEmpty) {
        message += '*PRODUK*%0A';
        for (var item in booking.items!) {
          message += '• ${item.productName} (${item.quantity}x) - RM${item.subtotal.toStringAsFixed(2)}%0A';
        }
        message += '%0A';
      }

      message += 'Subtotal: RM${itemsTotal.toStringAsFixed(2)}%0A';
      if (booking.discountAmount != null && booking.discountAmount! > 0) {
        message += 'Diskaun: -RM${booking.discountAmount!.toStringAsFixed(2)}%0A';
      }
      message += '*JUMLAH: RM${booking.totalAmount.toStringAsFixed(2)}*%0A';

      if (booking.depositAmount != null && booking.depositAmount! > 0) {
        message += 'Deposit: RM${booking.depositAmount!.toStringAsFixed(2)}%0A';
        final balance = booking.totalAmount - booking.depositAmount!;
        message += 'Baki: RM${balance.toStringAsFixed(2)}%0A';
      }

      message += '%0ATerima kasih atas tempahan anda! 🙏';

      final phone = booking.customerPhone.replaceAll(RegExp(r'[^\d]'), '');
      final waPhone = phone.startsWith('60')
          ? phone
          : '60${phone.startsWith('0') ? phone.substring(1) : phone}';
      final url = 'https://wa.me/$waPhone?text=$message';

      await launchUrl(Uri.parse(url));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ WhatsApp dibuka!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(String bookingId, String status) async {
    try {
      await _repo.updateBookingStatus(bookingId: bookingId, status: status);
      await _loadBookings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status dikemaskini kepada: ${_getStatusLabel(status)}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showCancelDialog(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batal Tempahan'),
        content: Text('Adakah anda pasti untuk batalkan tempahan ${booking.bookingNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Batal'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateStatus(booking.id, 'cancelled');
    }
  }

  /// Generate invoice number based on booking date
  /// Format: INV-YYMM-XXXX (e.g., INV-2412-0001)
  String _generateInvoiceNumber(DateTime date) {
    final yearMonth = DateFormat('yyMM').format(date);
    // Extract sequence from timestamp (last 4 digits)
    // This ensures uniqueness while maintaining date-based format
    final timestamp = date.millisecondsSinceEpoch;
    final sequence = (timestamp % 10000).toString().padLeft(4, '0');
    return 'INV-$yearMonth-$sequence';
  }
}

