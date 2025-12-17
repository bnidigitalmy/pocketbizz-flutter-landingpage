import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_helper.dart';
import '../../../data/models/announcement.dart';
import '../../../data/repositories/announcements_repository_supabase.dart';

/// User notification center page to view announcements
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _repo = AnnouncementsRepositorySupabase();
  bool _isLoading = true;
  List<Announcement> _announcements = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      // TODO: Get user's subscription status from subscription repository
      final announcements = await _repo.getActiveAnnouncements();
      setState(() {
        _announcements = announcements;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuatkan announcements: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsViewed(Announcement announcement) async {
    try {
      await _repo.markAsViewed(announcement.id);
      // Remove from list after viewing
      setState(() {
        _announcements.removeWhere((a) => a.id == announcement.id);
      });
    } catch (e) {
      print('Error marking as viewed: $e');
    }
  }

  Future<void> _handleAction(Announcement announcement) async {
    if (announcement.actionUrl != null) {
      try {
        final uri = Uri.parse(announcement.actionUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tidak boleh membuka pautan: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
    await _markAsViewed(announcement);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnnouncements,
            tooltip: 'Muat semula',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAnnouncements,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _announcements.length,
                    itemBuilder: (context, index) {
                      return _buildAnnouncementCard(_announcements[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Tiada notifikasi baru',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Semua notifikasi telah dibaca',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(Announcement announcement) {
    final colors = {
      'info': Colors.blue,
      'success': Colors.green,
      'warning': Colors.orange,
      'error': Colors.red,
      'feature': Colors.purple,
      'maintenance': Colors.amber,
    };

    final color = colors[announcement.type] ?? Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showAnnouncementDetail(announcement),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: color, width: 4),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_getTypeIcon(announcement.type), color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            announcement.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            announcement.typeLabel,
                            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    if (announcement.priority == 'urgent')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Mendesak',
                          style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  announcement.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                if (announcement.actionUrl != null && announcement.actionLabel != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleAction(announcement),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(announcement.actionLabel!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(
                        DateTimeHelper.toLocalTime(announcement.createdAt),
                      ),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'info':
        return Icons.info;
      case 'success':
        return Icons.check_circle;
      case 'warning':
        return Icons.warning;
      case 'error':
        return Icons.error;
      case 'feature':
        return Icons.star;
      case 'maintenance':
        return Icons.build;
      default:
        return Icons.notifications;
    }
  }

  void _showAnnouncementDetail(Announcement announcement) {
    final colors = {
      'info': Colors.blue,
      'success': Colors.green,
      'warning': Colors.orange,
      'error': Colors.red,
      'feature': Colors.purple,
      'maintenance': Colors.amber,
    };

    final color = colors[announcement.type] ?? Colors.blue;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getTypeIcon(announcement.type), color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(announcement.title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  announcement.message,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              if (announcement.actionUrl != null && announcement.actionLabel != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _handleAction(announcement);
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: Text(announcement.actionLabel!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Diterima: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTimeHelper.toLocalTime(announcement.createdAt))}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _markAsViewed(announcement);
            },
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

