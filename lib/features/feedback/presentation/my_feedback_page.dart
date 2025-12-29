import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_helper.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../data/models/feedback_request.dart';
import '../../../data/repositories/feedback_repository_supabase.dart';
import 'submit_feedback_page.dart';

/// Page for users to view their submitted feedback
class MyFeedbackPage extends StatefulWidget {
  const MyFeedbackPage({super.key});

  @override
  State<MyFeedbackPage> createState() => _MyFeedbackPageState();
}

class _MyFeedbackPageState extends State<MyFeedbackPage> {
  final _repo = FeedbackRepositorySupabase();
  bool _isLoading = true;
  List<FeedbackRequest> _feedbackList = [];

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    setState(() => _isLoading = true);
    try {
      final feedback = await _repo.getMyFeedback();
      setState(() {
        _feedbackList = feedback;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuatkan feedback: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback Saya'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFeedback,
            tooltip: 'Muat semula',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _feedbackList.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadFeedback,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _feedbackList.length,
                    itemBuilder: (context, index) {
                      return _buildFeedbackCard(_feedbackList[index]);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SubmitFeedbackPage()),
          ).then((_) => _loadFeedback());
        },
        icon: const Icon(Icons.add),
        label: const Text('Hantar Feedback'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.feedback_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Tiada feedback lagi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kongsi idea atau laporkan masalah anda',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubmitFeedbackPage()),
              ).then((_) => _loadFeedback());
            },
            icon: const Icon(Icons.add),
            label: const Text('Hantar Feedback'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(FeedbackRequest feedback) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showFeedbackDetail(feedback),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildTypeBadge(feedback.type),
                  const Spacer(),
                  _buildStatusChip(feedback.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                feedback.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                feedback.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(
                      DateTimeHelper.toLocalTime(feedback.createdAt),
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (feedback.attachments.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.attach_file, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${feedback.attachments.length} lampiran',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                  if (feedback.adminNotes != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.comment, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Ada respons',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildTypeBadge(String type) {
    final colors = {
      'bug': Colors.red,
      'feature': Colors.blue,
      'suggestion': Colors.orange,
      'other': Colors.grey,
    };
    final icons = {
      'bug': Icons.bug_report,
      'feature': Icons.add_circle,
      'suggestion': Icons.lightbulb,
      'other': Icons.more_horiz,
    };

    final feedback = FeedbackRequest(
      id: '',
      businessOwnerId: '',
      type: type,
      title: '',
      description: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors[type]?.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors[type] ?? Colors.grey),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icons[type],
            size: 14,
            color: colors[type],
          ),
          const SizedBox(width: 4),
          Text(
            feedback.typeLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors[type],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final colors = {
      'pending': Colors.grey,
      'reviewing': Colors.blue,
      'in_progress': Colors.orange,
      'completed': Colors.green,
      'rejected': Colors.red,
      'on_hold': Colors.amber,
    };

    final feedback = FeedbackRequest(
      id: '',
      businessOwnerId: '',
      type: 'other',
      title: '',
      description: '',
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors[status]?.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        feedback.statusLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors[status],
        ),
      ),
    );
  }

  void _showFeedbackDetail(FeedbackRequest feedback) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feedback.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _buildTypeBadge(feedback.type),
                  const SizedBox(width: 8),
                  _buildStatusChip(feedback.status),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Penerangan:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(feedback.description),
              if (feedback.attachments.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Lampiran:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: feedback.attachments.map((a) {
                    if (a.isImage) {
                      return InkWell(
                        onTap: () => _openUrl(a.url),
                        child: CachedImage(
                          imageUrl: a.url,
                          width: 120,
                          height: 80,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }
                    final icon = a.isVideo ? Icons.video_library : Icons.insert_drive_file;
                    return InkWell(
                      onTap: () => _openUrl(a.url),
                      child: Container(
                        width: 220,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(icon, size: 18, color: Colors.grey[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                a.filename,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (feedback.adminNotes != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Respons Admin:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(feedback.adminNotes!),
                ),
              ],
              // Implementation notes are internal/admin only - not shown to users
              const SizedBox(height: 16),
              Text(
                'Dihantar: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTimeHelper.toLocalTime(feedback.createdAt))}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

