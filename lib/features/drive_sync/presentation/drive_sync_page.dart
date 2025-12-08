import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../data/models/drive_sync_log.dart';
import '../data/repositories/drive_sync_repository_supabase.dart';
import '../utils/drive_sync_helper.dart';

class DriveSyncPage extends StatefulWidget {
  const DriveSyncPage({super.key});

  @override
  State<DriveSyncPage> createState() => _DriveSyncPageState();
}

class _DriveSyncPageState extends State<DriveSyncPage> {
  final _repo = DriveSyncRepositorySupabase();
  List<DriveSyncLog> _syncLogs = [];
  bool _loading = true;
  String? _error;
  bool _isSignedIn = false;
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    _checkSignInStatus();
    _loadSyncLogs();
  }

  Future<void> _checkSignInStatus() async {
    final isSignedIn = DriveSyncHelper.isSignedIn;
    if (mounted) {
      setState(() {
        _isSignedIn = isSignedIn;
      });
    }
  }

  Future<void> _signInToGoogleDrive() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      final success = await DriveSyncHelper.signIn();
      if (mounted) {
        setState(() {
          _isSignedIn = success;
          _isSigningIn = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Berjaya sign in ke Google Drive!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sign in dibatalkan'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat sign in: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOutFromGoogleDrive() async {
    try {
      await DriveSyncHelper.signOut();
      if (mounted) {
        setState(() {
          _isSignedIn = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Berjaya sign out dari Google Drive'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat sign out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadSyncLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final logs = await _repo.getSyncLogs();
      if (mounted) {
        setState(() {
          _syncLogs = logs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _openInDrive(String webViewLink) async {
    final uri = Uri.parse(webViewLink);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka link')),
        );
      }
    }
  }

  String _getFileTypeLabel(String type) {
    return DriveSyncLog(
      id: '',
      businessOwnerId: '',
      fileName: '',
      fileType: type,
      driveFileId: '',
      driveWebViewLink: '',
      syncedAt: DateTime.now(),
      syncStatus: 'success',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).getFileTypeLabel();
  }

  Color _getFileTypeBadgeColor(String type) {
    if (type.contains('thermal')) return Colors.blue;
    if (type.contains('claim')) return Colors.green;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dokumen Google Drive'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSyncLogs,
            tooltip: 'Refresh',
          ),
          if (_isSignedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOutFromGoogleDrive,
              tooltip: 'Sign out dari Google Drive',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _buildContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ralat memuatkan sync logs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Sila refresh halaman atau cuba lagi kemudian',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadSyncLogs,
              icon: const Icon(Icons.refresh),
              label: const Text('Cuba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_syncLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isSignedIn ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
                size: 64,
                color: _isSignedIn ? Colors.green : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _isSignedIn 
                    ? 'Tiada dokumen di-sync lagi'
                    : 'Belum sign in ke Google Drive',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignedIn
                    ? 'Dokumen akan auto-sync ke Google Drive selepas dijana'
                    : 'Sign in untuk mula sync dokumen ke Google Drive anda',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              if (!_isSignedIn)
                ElevatedButton.icon(
                  onPressed: _isSigningIn ? null : _signInToGoogleDrive,
                  icon: _isSigningIn
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.cloud),
                  label: Text(_isSigningIn ? 'Signing in...' : 'Sign In ke Google Drive'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSyncLogs,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
            _buildSummaryCard(),
            const SizedBox(height: 16),

            // Sync Logs List
            const Text(
              'Senarai Dokumen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._syncLogs.map((log) => _buildSyncLogCard(log)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalDocs = _syncLogs.length;
    final invoices = _syncLogs.where((l) => l.fileType.contains('invoice')).length;
    final claims = _syncLogs.where((l) => l.fileType.contains('claim')).length;
    final thermal = _syncLogs.where((l) => l.fileType.contains('thermal')).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.description, size: 20),
                SizedBox(width: 8),
                Text(
                  'Ringkasan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    totalDocs.toString(),
                    'Total Dokumen',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    invoices.toString(),
                    'Invois',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    claims.toString(),
                    'Penyata',
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    thermal.toString(),
                    'Thermal',
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSyncLogCard(DriveSyncLog log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    log.fileName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getFileTypeBadgeColor(log.fileType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getFileTypeLabel(log.fileType),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getFileTypeBadgeColor(log.fileType),
                    ),
                  ),
                ),
              ],
            ),
            if (log.vendorName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Vendor: ${log.vendorName}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  DateFormat('d MMMM yyyy, h:mm a', 'ms_MY').format(log.syncedAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _openInDrive(log.driveWebViewLink),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Buka di Drive'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

