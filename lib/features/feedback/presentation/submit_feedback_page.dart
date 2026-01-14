import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../../core/services/announcement_media_service.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/announcement_media.dart';
import '../../../data/models/feedback_request.dart';
import '../../../data/repositories/feedback_repository_supabase.dart';

/// Page for users to submit feedback, bug reports, feature requests, and suggestions
class SubmitFeedbackPage extends StatefulWidget {
  const SubmitFeedbackPage({super.key});

  @override
  State<SubmitFeedbackPage> createState() => _SubmitFeedbackPageState();
}

class _SubmitFeedbackPageState extends State<SubmitFeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = FeedbackRepositorySupabase();
  final _mediaService = AnnouncementMediaService();
  
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedType = 'suggestion';
  String _selectedPriority = 'normal';
  bool _isSubmitting = false;
  bool _isUploadingAttachment = false;
  final List<AnnouncementMedia> _attachments = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await _repo.createFeedback(
        type: _selectedType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _selectedPriority,
        attachments: _attachments,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terima kasih! Feedback anda telah dihantar.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghantar feedback: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hantar Feedback'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kongsi idea, laporkan masalah, atau cadangkan ciri baru untuk PocketBizz!',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Type selection
              const Text(
                'Jenis Feedback',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTypeChip('suggestion', 'Cadangan', Icons.lightbulb_outline),
                  _buildTypeChip('feature', 'Ciri Baru', Icons.add_circle_outline),
                  _buildTypeChip('bug', 'Bug Report', Icons.bug_report),
                  _buildTypeChip('other', 'Lain-lain', Icons.more_horiz),
                ],
              ),
              const SizedBox(height: 24),

              // Priority selection
              const Text(
                'Keutamaan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPriorityChip('low', 'Rendah', Colors.grey),
                  _buildPriorityChip('normal', 'Biasa', Colors.blue),
                  _buildPriorityChip('high', 'Tinggi', Colors.orange),
                  _buildPriorityChip('urgent', 'Mendesak', Colors.red),
                ],
              ),
              const SizedBox(height: 24),

              // Title field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tajuk',
                  hintText: 'Ringkaskan feedback anda',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                maxLength: 255,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Sila masukkan tajuk';
                  }
                  if (value.trim().length < 5) {
                    return 'Tajuk mesti sekurang-kurangnya 5 aksara';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Penerangan',
                  hintText: 'Terangkan dengan lebih lanjut...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
                maxLength: 2000,
                textInputAction: TextInputAction.newline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Sila masukkan penerangan';
                  }
                  if (value.trim().length < 10) {
                    return 'Penerangan mesti sekurang-kurangnya 10 aksara';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Attachments
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.attach_file, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Lampiran (Opsyenal)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Boleh attach gambar/video/fail (PDF) untuk bantu admin faham masalah.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploadingAttachment ? null : _pickAndUploadImage,
                            icon: const Icon(Icons.image, size: 18),
                            label: const Text('Gambar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploadingAttachment ? null : _pickAndUploadVideo,
                            icon: const Icon(Icons.video_library, size: 18),
                            label: const Text('Video'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploadingAttachment ? null : _pickAndUploadFile,
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text('Fail'),
                          ),
                        ),
                      ],
                    ),
                    if (_isUploadingAttachment) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(),
                    ],
                    if (_attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ..._attachments.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final a = entry.value;
                        final icon = a.isImage
                            ? Icons.image
                            : a.isVideo
                                ? Icons.video_library
                                : Icons.insert_drive_file;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
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
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                onPressed: () => setState(() => _attachments.removeAt(idx)),
                                tooltip: 'Buang',
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              ElevatedButton(
                onPressed: (_isSubmitting || _isUploadingAttachment) ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Hantar Feedback',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String value, String label, IconData icon) {
    final isSelected = _selectedType == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedType = value);
        }
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _buildPriorityChip(String value, String label, Color color) {
    final isSelected = _selectedPriority == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedPriority = value);
        }
      },
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
    );
  }

  String _folderPrefix() {
    final uid = supabase.auth.currentUser?.id ?? 'unknown';
    return 'feedback/$uid';
  }

  Future<void> _pickAndUploadImage() async {
    try {
      setState(() => _isUploadingAttachment = true);
      debugPrint('📸 Picking image...');
      final img = await _mediaService.pickImage();
      if (img == null) {
        debugPrint('⚠️ Image picker cancelled or returned null');
        return;
      }
      debugPrint('✅ Image picked: ${img.name}');
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      debugPrint('📤 Uploading image...');
      final uploaded = await _mediaService.uploadImage(
        img,
        'fb-$tempId',
        folderPrefix: _folderPrefix(),
      );
      if (!mounted) return;
      debugPrint('✅ Image uploaded successfully: ${uploaded.url}');
      setState(() => _attachments.add(uploaded));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Gambar berjaya dilampirkan'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error picking/uploading image: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      final msg = _friendlyUploadError(e, jenis: 'gambar');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAttachment = false);
    }
  }

  Future<void> _pickAndUploadVideo() async {
    try {
      setState(() => _isUploadingAttachment = true);
      debugPrint('🎥 Picking video...');
      final vid = await _mediaService.pickVideo();
      if (vid == null) {
        debugPrint('⚠️ Video picker cancelled or returned null');
        return;
      }
      debugPrint('✅ Video picked: ${vid.name}');
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      debugPrint('📤 Uploading video...');
      final uploaded = await _mediaService.uploadVideo(
        vid,
        'fb-$tempId',
        folderPrefix: _folderPrefix(),
      );
      if (!mounted) return;
      debugPrint('✅ Video uploaded successfully: ${uploaded.url}');
      setState(() => _attachments.add(uploaded));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Video berjaya dilampirkan'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error picking/uploading video: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      final msg = _friendlyUploadError(e, jenis: 'video');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAttachment = false);
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      setState(() => _isUploadingAttachment = true);
      debugPrint('📄 Picking file...');
      final result = await _mediaService.pickFile(
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'jpg', 'jpeg', 'png', 'mp4', 'mov'],
      );
      if (result == null || result.files.isEmpty) {
        debugPrint('⚠️ File picker cancelled or returned empty');
        return;
      }
      final file = result.files.single;
      debugPrint('✅ File picked: ${file.name} (${file.size} bytes)');
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      debugPrint('📤 Uploading file...');
      final uploaded = await _mediaService.uploadFile(
        file,
        'fb-$tempId',
        folderPrefix: _folderPrefix(),
      );
      if (!mounted) return;
      debugPrint('✅ File uploaded successfully: ${uploaded.url}');
      setState(() => _attachments.add(uploaded));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Fail berjaya dilampirkan'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error picking/uploading file: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      final msg = _friendlyUploadError(e, jenis: 'fail');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAttachment = false);
    }
  }

  String _friendlyUploadError(Object e, {required String jenis}) {
    final s = e.toString().toLowerCase();
    if (s.contains('blob') || s.contains('revoked')) {
      return 'Gagal upload $jenis. Sila pilih semula $jenis dan cuba lagi.';
    }
    if (s.contains('permission') || s.contains('not authorized') || s.contains('401') || s.contains('403')) {
      return 'Gagal upload $jenis. Sila log masuk semula dan cuba lagi.';
    }
    if (s.contains('network') || s.contains('socket') || s.contains('timeout')) {
      return 'Gagal upload $jenis kerana sambungan internet. Cuba lagi bila line stabil.';
    }
    return 'Gagal upload $jenis. Sila cuba lagi.';
  }
}

