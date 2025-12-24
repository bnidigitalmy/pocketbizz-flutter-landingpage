import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:html' as html;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_helper.dart';
import '../../../data/repositories/bookings_repository_supabase.dart';
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../../../data/models/business_profile.dart';
import '../../../core/utils/booking_pdf_generator.dart';
import '../../drive_sync/utils/drive_sync_helper.dart';
import '../../../core/services/document_storage_service.dart';
import 'create_booking_page_enhanced.dart';
import '../../onboarding/presentation/widgets/contextual_tooltip.dart';
import '../../onboarding/data/tooltip_content.dart';
import '../../onboarding/services/tooltip_service.dart';

/// Optimized Tempahan Page
/// Full-featured tempahan management with PDF and WhatsApp sharing
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
  String _statusTab = 'all'; // all | pending | confirmed | completed
  BusinessProfile? _businessProfile;

  @override
  void initState() {
    super.initState();
    _loadBookings();
    _loadBusinessProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTooltip();
    });
  }

  Future<void> _checkAndShowTooltip() async {
    final hasData = _bookings.isNotEmpty;
    
    final shouldShow = await TooltipHelper.shouldShowTooltip(
      context,
      TooltipKeys.bookings,
      checkEmptyState: !hasData,
      emptyStateChecker: () => !hasData,
    );
    
    if (shouldShow && mounted) {
      final content = hasData ? TooltipContent.bookings : TooltipContent.bookingsEmpty;
      await TooltipHelper.showTooltip(
        context,
        content.moduleKey,
        content.title,
        content.message,
      );
    }
  }

  Future<void> _loadBusinessProfile() async {
    try {
      final profile = await _businessProfileRepo.getBusinessProfile();
      if (mounted) {
        setState(() {
          _businessProfile = profile;
        });
      }
    } catch (e) {
      // Business profile is optional, continue without it
      debugPrint('Failed to load business profile: $e');
    }
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);

    try {
      final bookings = await _repo.listBookings();
      // Sort by createdAt descending (newest first) - repository already sorts, but ensure it here too
      bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
    switch (_statusTab) {
      case 'pending':
        _filteredBookings = _bookings.where((b) => b.status == 'pending').toList();
        break;
      case 'confirmed':
        _filteredBookings = _bookings.where((b) => b.status == 'confirmed').toList();
        break;
      case 'completed':
        _filteredBookings = _bookings.where((b) => b.status == 'completed').toList();
        break;
      default:
        _filteredBookings = _bookings;
    }
  }

  int get _pendingCount => _bookings.where((b) => b.status == 'pending').length;
  int get _confirmedCount => _bookings.where((b) => b.status == 'confirmed').length;

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (canPop) {
              Navigator.of(context).pop();
            } else {
              // Navigate to dashboard if can't pop
              Navigator.of(context).pushReplacementNamed('/');
            }
          },
        ),
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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBookings,
              child: CustomScrollView(
                slivers: [
                  // Stats Cards
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _buildStatsCards(),
                    ),
                  ),

                  // Status Tabs
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: _buildStatusTabs(),
                    ),
                  ),

                  // Senarai Tempahan
                  if (_filteredBookings.isEmpty)
                    SliverFillRemaining(
                      child: _buildEmptyState(),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final booking = _filteredBookings[index];
                          return _buildBookingCard(booking);
                        },
                        childCount: _filteredBookings.length,
                      ),
                    ),
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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

  Widget _buildStatusTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatusChip('all', 'Semua', _bookings.length),
          const SizedBox(width: 8),
          _buildStatusChip('pending', 'Menunggu', _pendingCount),
          const SizedBox(width: 8),
          _buildStatusChip('confirmed', 'Disahkan', _confirmedCount),
          const SizedBox(width: 8),
          _buildStatusChip('completed', 'Selesai', _bookings.where((b) => b.status == 'completed').length),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String value, String label, int count) {
    final isSelected = _statusTab == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _statusTab = value;
            _filterBookings();
          });
        }
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Tiada tempahan ${_statusTab != 'all' ? 'dengan status "${_getStatusLabel(_statusTab)}"' : ''}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: InkWell(
        onTap: () => _showBookingDetails(booking),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: No. Tempahan & Status
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
                // More actions menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'pdf') {
                      _downloadPDF(booking);
                    } else if (value == 'whatsapp') {
                      _shareWhatsApp(booking);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'pdf',
                      child: Row(
                        children: [
                          Icon(Icons.download_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Muat Turun PDF'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'whatsapp',
                      child: Row(
                        children: [
                          Icon(Icons.share_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Kongsi WhatsApp'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Customer & Delivery Info (Simplified)
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(Icons.person, booking.customerName),
                ),
                Expanded(
                  child: _buildInfoRow(
                    Icons.calendar_today,
                    DateFormat('dd MMM yyyy', 'ms_MY').format(DateTime.parse(booking.deliveryDate)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Products Summary (if any)
            if (booking.items != null && booking.items!.isNotEmpty) ...[
              Text(
                '${booking.items!.length} produk ditempah',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Total Amount (Large & Prominent)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RM${booking.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    if (booking.depositAmount != null && booking.depositAmount! > 0)
                      Text(
                        'Deposit: RM${booking.depositAmount!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action Buttons (Clear & Simple)
            Row(
              children: [
                if (booking.status == 'pending')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(booking.id, 'confirmed'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Sahkan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (booking.status == 'confirmed') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(booking.id, 'completed'),
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('Selesai'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
                if (booking.status != 'completed' && booking.status != 'cancelled') ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _showCancelDialog(booking),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    child: const Text('Batal'),
                  ),
                ],
              ],
            ),
          ],
        ),
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

  int get _completedCount => _bookings.where((b) => b.status == 'completed').length;

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
      
      // Auto-backup to Supabase Storage (non-blocking)
      DocumentStorageService.uploadDocumentSilently(
        pdfBytes: pdfBytes,
        fileName: filename,
        documentType: 'invoice',
        relatedEntityType: 'booking',
        relatedEntityId: booking.id,
      );

      // Auto-sync to Google Drive (non-blocking, optional)
      DriveSyncHelper.syncDocumentSilently(
        pdfData: pdfBytes,
        fileName: filename,
        fileType: 'invoice',
        relatedEntityType: 'booking',
        relatedEntityId: booking.id,
      );

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
      // Ensure business profile is loaded
      if (_businessProfile == null) {
        await _loadBusinessProfile();
      }

      // Use business profile name or default to PocketBizz
      final businessName = _businessProfile?.businessName ?? 'PocketBizz';

      final itemsTotal = booking.items?.fold<double>(
            0.0,
            (sum, item) => sum + item.subtotal,
          ) ??
          0.0;

      var message = '*TEMPAHAN INVOICE*%0A%0A';
      message += '*$businessName*%0A';
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

  Future<void> _showBookingDetails(Booking booking) async {
    // Reload booking with full details including items
    try {
      final fullBooking = await _repo.getBooking(booking.id);
      
      if (!mounted) return;
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  fullBooking.bookingNumber,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _buildStatusBadge(fullBooking.status),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatEventType(fullBooking.eventType),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1),
                
                // Content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Customer Info Section
                      _buildDetailSection(
                        'Maklumat Pelanggan',
                        Icons.person,
                        [
                          _buildDetailRow('Nama', fullBooking.customerName),
                          _buildDetailRow('Telefon', fullBooking.customerPhone),
                          if (fullBooking.customerEmail != null)
                            _buildDetailRow('Email', fullBooking.customerEmail!),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Booking Date Section
                      _buildDetailSection(
                        'Maklumat Tempahan',
                        Icons.calendar_today,
                        [
                          _buildDetailRow(
                            'Tarikh Tempahan Dibuat',
                            DateTimeHelper.formatDateTime(
                              fullBooking.createdAt,
                              pattern: 'dd MMMM yyyy, hh:mm a',
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Delivery Info Section
                      _buildDetailSection(
                        'Maklumat Penghantaran',
                        Icons.local_shipping,
                        [
                          _buildDetailRow(
                            'Tarikh Hantar',
                            DateTimeHelper.formatDate(
                              DateTime.parse(fullBooking.deliveryDate),
                              pattern: 'dd MMMM yyyy',
                            ),
                          ),
                          if (fullBooking.deliveryTime != null)
                            _buildDetailRow('Masa', fullBooking.deliveryTime!),
                          if (fullBooking.deliveryLocation != null)
                            _buildDetailRow('Lokasi', fullBooking.deliveryLocation!),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Products Section
                      if (fullBooking.items != null && fullBooking.items!.isNotEmpty) ...[
                        _buildDetailSection(
                          'Produk Ditempah',
                          Icons.shopping_bag,
                          [
                            ...fullBooking.items!.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item.quantity.toStringAsFixed(0)}x × RM${item.unitPrice.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'RM${item.subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Financial Summary
                      _buildDetailSection(
                        'Ringkasan Kewangan',
                        Icons.receipt_long,
                        [
                          if (fullBooking.discountAmount != null && fullBooking.discountAmount! > 0)
                            _buildDetailRow('Diskaun', '-RM${fullBooking.discountAmount!.toStringAsFixed(2)}', isHighlight: true),
                          _buildDetailRow(
                            'Jumlah',
                            'RM${fullBooking.totalAmount.toStringAsFixed(2)}',
                            isHighlight: true,
                            isLarge: true,
                          ),
                          if (fullBooking.depositAmount != null && fullBooking.depositAmount! > 0)
                            _buildDetailRow('Deposit', 'RM${fullBooking.depositAmount!.toStringAsFixed(2)}'),
                          _buildDetailRow('Jumlah Dibayar', 'RM${fullBooking.totalPaid.toStringAsFixed(2)}'),
                          _buildDetailRow(
                            'Baki',
                            'RM${(fullBooking.totalAmount - fullBooking.totalPaid).toStringAsFixed(2)}',
                            isHighlight: true,
                          ),
                        ],
                      ),
                      
                      // Payment History Section
                      if (fullBooking.totalPaid > 0) ...[
                        const SizedBox(height: 24),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _repo.getPaymentHistory(fullBooking.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            final payments = snapshot.data ?? [];
                            
                            return _buildDetailSection(
                              'Sejarah Pembayaran',
                              Icons.payment,
                              [
                                ...payments.map((payment) {
                                  final paymentDate = payment['payment_date'] != null
                                      ? DateTimeHelper.formatDate(DateTime.parse(payment['payment_date']), pattern: 'dd MMM yyyy')
                                      : 'N/A';
                                  final paymentTime = payment['payment_time'] != null
                                      ? payment['payment_time'] as String
                                      : '';
                                  final paymentMethod = payment['payment_method'] as String? ?? 'cash';
                                  final paymentAmount = (payment['payment_amount'] as num).toDouble();
                                  final paymentNumber = payment['payment_number'] as String? ?? 'N/A';
                                  
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    paymentNumber,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '$paymentDate${paymentTime.isNotEmpty ? ', $paymentTime' : ''}',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _formatPaymentMethod(paymentMethod),
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'RM${paymentAmount.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: AppColors.success,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.receipt, size: 20),
                                                  color: AppColors.primary,
                                                  onPressed: () => _generatePaymentReceipt(fullBooking, payment),
                                                  tooltip: 'Generate Resit',
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        if (payment['notes'] != null && (payment['notes'] as String).isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Nota: ${payment['notes']}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            );
                          },
                        ),
                      ],
                      
                      if (fullBooking.notes != null && fullBooking.notes!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildDetailSection(
                          'Nota',
                          Icons.note,
                          [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                fullBooking.notes!,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Record Payment Button (if there's remaining balance)
                      if (fullBooking.totalAmount - fullBooking.totalPaid > 0) ...[
                        ElevatedButton.icon(
                          onPressed: () => _showRecordPaymentDialog(fullBooking),
                          icon: const Icon(Icons.payment, size: 20),
                          label: const Text('Rekod Pembayaran'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      // Action Buttons
                      if (fullBooking.status == 'pending')
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateStatus(fullBooking.id, 'confirmed');
                          },
                          icon: const Icon(Icons.check, size: 20),
                          label: const Text('Sahkan Tempahan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      
                      if (fullBooking.status == 'confirmed')
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateStatus(fullBooking.id, 'completed');
                          },
                          icon: const Icon(Icons.done_all, size: 20),
                          label: const Text('Tandakan Selesai'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // Secondary Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _downloadPDF(fullBooking);
                              },
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('PDF'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _shareWhatsApp(fullBooking);
                              },
                              icon: const Icon(Icons.share_rounded),
                              label: const Text('WhatsApp'),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDetailSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false, bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 16 : 14,
              color: Colors.grey[600],
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: isLarge ? 20 : 14,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                color: isHighlight ? AppColors.primary : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
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

  /// Generate invoice number based on tempahan date
  /// Format: INV-YYMM-XXXX (e.g., INV-2412-0001)
  String _generateInvoiceNumber(DateTime date) {
    final yearMonth = DateFormat('yyMM').format(date);
    // Extract sequence from timestamp (last 4 digits)
    // This ensures uniqueness while maintaining date-based format
    final timestamp = date.millisecondsSinceEpoch;
    final sequence = (timestamp % 10000).toString().padLeft(4, '0');
    return 'INV-$yearMonth-$sequence';
  }

  /// Show dialog to record payment
  Future<void> _showRecordPaymentDialog(Booking booking) async {
    final remainingBalance = booking.totalAmount - booking.totalPaid;
    
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    final notesController = TextEditingController();
    String selectedPaymentMethod = 'cash';
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rekod Pembayaran'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Baki: RM${remainingBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah Pembayaran *',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Sila masukkan jumlah';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Jumlah mesti lebih daripada 0';
                    }
                    if (amount > remainingBalance) {
                      return 'Jumlah melebihi baki';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedPaymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Kaedah Pembayaran *',
                    prefixIcon: Icon(Icons.payment),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Tunai')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cek')),
                    DropdownMenuItem(value: 'credit_card', child: Text('Kad Kredit')),
                    DropdownMenuItem(value: 'e_wallet', child: Text('E-Wallet')),
                    DropdownMenuItem(value: 'other', child: Text('Lain-lain')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedPaymentMethod = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Rujukan (Pilihan)',
                    prefixIcon: Icon(Icons.receipt),
                    border: OutlineInputBorder(),
                    hintText: 'No. cek, rujukan bank, dll',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Nota (Pilihan)',
                    prefixIcon: Icon(Icons.note),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0 || amount > remainingBalance) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sila masukkan jumlah yang sah'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'amount': amount,
                  'payment_method': selectedPaymentMethod,
                  'payment_reference': referenceController.text.isEmpty ? null : referenceController.text,
                  'notes': notesController.text.isEmpty ? null : notesController.text,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Rekod Pembayaran'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      try {
        final paymentResult = await _repo.recordPayment(
          bookingId: booking.id,
          amount: result['amount'] as double,
          paymentMethod: result['payment_method'] as String,
          paymentReference: result['payment_reference'] as String?,
          notes: result['notes'] as String?,
        );

        // Reload booking to get updated total_paid
        final updatedBooking = await _repo.getBooking(booking.id);
        
        // Close payment dialog and reload booking details
        Navigator.pop(context);
        if (mounted) {
          _showBookingDetails(updatedBooking);
        }

        // Show success message and offer to generate receipt
        if (mounted) {
          final generateReceipt = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Pembayaran Berjaya'),
              content: Text(
                'Pembayaran RM${result['amount'].toStringAsFixed(2)} telah direkod.\n\n'
                'Baki: RM${(paymentResult['remaining_balance'] as double).toStringAsFixed(2)}\n\n'
                'Adakah anda ingin generate resit pembayaran?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Tidak'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Ya, Generate Resit'),
                ),
              ],
            ),
          );

          if (generateReceipt == true && mounted) {
            final payment = paymentResult['payment'] as Map<String, dynamic>;
            // Use updatedBooking instead of booking to get correct total_paid
            await _generatePaymentReceipt(updatedBooking, payment);
          }
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
  }

  /// Generate payment receipt PDF
  Future<void> _generatePaymentReceipt(Booking booking, Map<String, dynamic> payment) async {
    try {
      final businessProfile = await _businessProfileRepo.getBusinessProfile();
      
      final pdfBytes = await BookingPDFGenerator.generatePaymentReceipt(
        booking: booking,
        payment: payment,
        businessProfile: businessProfile,
      );

      // Save and open PDF
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Resit pembayaran telah dijana'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Format payment method for display
  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Tunai';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'cheque':
        return 'Cek';
      case 'credit_card':
        return 'Kad Kredit';
      case 'e_wallet':
        return 'E-Wallet';
      case 'other':
        return 'Lain-lain';
      default:
        return method;
    }
  }
}

