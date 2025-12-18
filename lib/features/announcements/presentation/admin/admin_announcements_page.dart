import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/admin_helper.dart';
import '../../../../core/utils/date_time_helper.dart';
import '../../../../core/services/announcement_media_service.dart';
import '../../../../data/models/announcement.dart';
import '../../../../data/models/announcement_media.dart';
import '../../../../data/repositories/announcements_repository_supabase.dart';

/// Admin page to manage announcements
class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});

  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
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
      final announcements = await _repo.getAllAnnouncements();
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

  void _showAddDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final mediaService = AnnouncementMediaService();
    String selectedType = 'info';
    String selectedPriority = 'normal';
    String selectedTarget = 'all';
    bool isActive = true;
    DateTime? showUntil;
    List<AnnouncementMedia> mediaList = [];
    bool isUploadingMedia = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Announcement'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tajuk',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Sila masukkan tajuk' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      labelText: 'Mesej',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Sila masukkan mesej' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Jenis',
                      border: OutlineInputBorder(),
                    ),
                    items: ['info', 'success', 'warning', 'error', 'feature', 'maintenance']
                        .map((type) {
                      final ann = Announcement(
                        id: '',
                        title: '',
                        message: '',
                        type: type,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      return DropdownMenuItem(
                        value: type,
                        child: Text(ann.typeLabel),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => selectedType = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedPriority,
                    decoration: const InputDecoration(
                      labelText: 'Keutamaan',
                      border: OutlineInputBorder(),
                    ),
                    items: ['low', 'normal', 'high', 'urgent'].map((priority) {
                      final ann = Announcement(
                        id: '',
                        title: '',
                        message: '',
                        priority: priority,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      return DropdownMenuItem(
                        value: priority,
                        child: Text(ann.priorityLabel),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => selectedPriority = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedTarget,
                    decoration: const InputDecoration(
                      labelText: 'Sasaran',
                      border: OutlineInputBorder(),
                    ),
                    items: ['all', 'trial', 'active', 'expired', 'grace'].map((target) {
                      final ann = Announcement(
                        id: '',
                        title: '',
                        message: '',
                        targetAudience: target,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      return DropdownMenuItem(
                        value: target,
                        child: Text(ann.targetAudienceLabel),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => selectedTarget = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Aktif'),
                    value: isActive,
                    onChanged: (value) {
                      setDialogState(() => isActive = value ?? true);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Media upload section
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Lampiran Media',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isUploadingMedia
                              ? null
                              : () async {
                                  try {
                                    setDialogState(() => isUploadingMedia = true);
                                    final image = await mediaService.pickImage();
                                    if (image != null) {
                                      // Generate temporary ID for upload
                                      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
                                      final uploadedMedia = await mediaService.uploadImage(image, tempId);
                                      setDialogState(() {
                                        mediaList.add(uploadedMedia);
                                        isUploadingMedia = false;
                                      });
                                    } else {
                                      setDialogState(() => isUploadingMedia = false);
                                    }
                                  } catch (e) {
                                    setDialogState(() => isUploadingMedia = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Gagal upload gambar: $e'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.image, size: 18),
                          label: const Text('Gambar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isUploadingMedia
                              ? null
                              : () async {
                                  try {
                                    setDialogState(() => isUploadingMedia = true);
                                    final video = await mediaService.pickVideo();
                                    if (video != null) {
                                      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
                                      final uploadedMedia = await mediaService.uploadVideo(video, tempId);
                                      setDialogState(() {
                                        mediaList.add(uploadedMedia);
                                        isUploadingMedia = false;
                                      });
                                    } else {
                                      setDialogState(() => isUploadingMedia = false);
                                    }
                                  } catch (e) {
                                    setDialogState(() => isUploadingMedia = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Gagal upload video: $e'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.video_library, size: 18),
                          label: const Text('Video'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isUploadingMedia
                              ? null
                              : () async {
                                  try {
                                    setDialogState(() => isUploadingMedia = true);
                                    final result = await mediaService.pickFile(
                                      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
                                    );
                                    if (result != null && result.files.isNotEmpty) {
                                      final platformFile = result.files.single;
                                      // For web, bytes is available; for mobile, path is available
                                      final isValidFile = platformFile.bytes != null || platformFile.path != null;
                                      if (isValidFile) {
                                        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
                                        final uploadedMedia = await mediaService.uploadFile(platformFile, tempId);
                                        setDialogState(() {
                                          mediaList.add(uploadedMedia);
                                          isUploadingMedia = false;
                                        });
                                      } else {
                                        setDialogState(() => isUploadingMedia = false);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('Fail tidak valid atau tidak boleh diakses'),
                                              backgroundColor: AppColors.error,
                                            ),
                                          );
                                        }
                                      }
                                    } else {
                                      setDialogState(() => isUploadingMedia = false);
                                    }
                                  } catch (e) {
                                    setDialogState(() => isUploadingMedia = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Gagal upload fail: $e'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.attach_file, size: 18),
                          label: const Text('Fail'),
                        ),
                      ),
                    ],
                  ),
                  if (isUploadingMedia) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  if (mediaList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...mediaList.asMap().entries.map((entry) {
                      final index = entry.key;
                      final media = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              media.isImage
                                  ? Icons.image
                                  : media.isVideo
                                      ? Icons.video_library
                                      : Icons.attach_file,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                media.filename,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                              onPressed: () {
                                setDialogState(() {
                                  mediaList.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isUploadingMedia
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        try {
                          // Re-upload media with actual announcement ID after creation
                          final announcement = await _repo.createAnnouncement(
                            title: titleController.text.trim(),
                            message: messageController.text.trim(),
                            type: selectedType,
                            priority: selectedPriority,
                            targetAudience: selectedTarget,
                            isActive: isActive,
                            showUntil: showUntil,
                            media: mediaList,
                          );
                          if (mounted) {
                            Navigator.of(context).pop();
                            _loadAnnouncements();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Announcement telah ditambah dan dihebahkan'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal menambah announcement: ${e.toString()}'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AdminHelper.isAdmin()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Akses Ditolak')),
        body: const Center(child: Text('Hanya admin boleh akses halaman ini.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengurusan Announcements'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Announcement'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Tiada announcements',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambah announcement untuk hebahan kepada users',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(Announcement announcement) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildTypeBadge(announcement.type),
                const Spacer(),
                if (!announcement.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Tidak Aktif', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                const SizedBox(width: 8),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Padam', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      // TODO: Implement edit
                    } else if (value == 'delete') {
                      _deleteAnnouncement(announcement);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              announcement.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(announcement.message),
            if (announcement.media.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: announcement.media.map((media) {
                  return Chip(
                    avatar: Icon(
                      media.isImage
                          ? Icons.image
                          : media.isVideo
                              ? Icons.video_library
                              : Icons.attach_file,
                      size: 16,
                    ),
                    label: Text(media.filename, style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.blue[50],
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.people, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  announcement.targetAudienceLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd MMM yyyy').format(DateTimeHelper.toLocalTime(announcement.createdAt)),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    final colors = {
      'info': Colors.blue,
      'success': Colors.green,
      'warning': Colors.orange,
      'error': Colors.red,
      'feature': Colors.purple,
      'maintenance': Colors.amber,
    };

    final announcement = Announcement(
      id: '',
      title: '',
      message: '',
      type: type,
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
      child: Text(
        announcement.typeLabel,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors[type]),
      ),
    );
  }

  Future<void> _deleteAnnouncement(Announcement announcement) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam Announcement'),
        content: Text('Adakah anda pasti mahu memadam "${announcement.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Padam'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repo.deleteAnnouncement(announcement.id);
        if (mounted) {
          _loadAnnouncements();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Announcement telah dipadam'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memadam announcement: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

