import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/admin_helper.dart';
import '../../../../data/models/community_link.dart';
import '../../../../data/repositories/community_links_repository_supabase.dart';

/// Admin page to manage community links
class AdminCommunityLinksPage extends StatefulWidget {
  const AdminCommunityLinksPage({super.key});

  @override
  State<AdminCommunityLinksPage> createState() => _AdminCommunityLinksPageState();
}

class _AdminCommunityLinksPageState extends State<AdminCommunityLinksPage> {
  final _repo = CommunityLinksRepositorySupabase();
  bool _isLoading = true;
  List<CommunityLink> _links = [];

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    setState(() => _isLoading = true);
    try {
      final links = await _repo.getAllLinks();
      setState(() {
        _links = links;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuatkan pautan: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddLinkDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedPlatform = 'facebook';
    int displayOrder = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Pautan Komuniti'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedPlatform,
                    decoration: const InputDecoration(
                      labelText: 'Platform',
                      border: OutlineInputBorder(),
                    ),
                    items: ['facebook', 'telegram', 'whatsapp', 'discord', 'other']
                        .map((platform) {
                      final link = CommunityLink(
                        id: '',
                        businessOwnerId: '',
                        platform: platform,
                        name: '',
                        url: '',
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      return DropdownMenuItem(
                        value: platform,
                        child: Text(link.platformLabel),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedPlatform = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama',
                      hintText: 'Contoh: PocketBizz Official Group',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Sila masukkan nama';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Sila masukkan URL';
                      }
                      final uri = Uri.tryParse(value);
                      if (uri == null || !uri.hasAbsolutePath) {
                        return 'URL tidak sah';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Penerangan (pilihan)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: '0',
                    decoration: const InputDecoration(
                      labelText: 'Susunan Paparan',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      displayOrder = int.tryParse(value) ?? 0;
                    },
                  ),
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
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await _repo.createLink(
                      platform: selectedPlatform,
                      name: nameController.text.trim(),
                      url: urlController.text.trim(),
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      displayOrder: displayOrder,
                    );
                    if (mounted) {
                      Navigator.of(context).pop();
                      _loadLinks();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pautan telah ditambah'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Gagal menambah pautan: ${e.toString()}'),
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

  void _showEditLinkDialog(CommunityLink link) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: link.name);
    final urlController = TextEditingController(text: link.url);
    final descriptionController = TextEditingController(text: link.description ?? '');
    String selectedPlatform = link.platform;
    int displayOrder = link.displayOrder;
    bool isActive = link.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Pautan Komuniti'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedPlatform,
                    decoration: const InputDecoration(
                      labelText: 'Platform',
                      border: OutlineInputBorder(),
                    ),
                    items: ['facebook', 'telegram', 'whatsapp', 'discord', 'other']
                        .map((platform) {
                      final link = CommunityLink(
                        id: '',
                        businessOwnerId: '',
                        platform: platform,
                        name: '',
                        url: '',
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      return DropdownMenuItem(
                        value: platform,
                        child: Text(link.platformLabel),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedPlatform = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Sila masukkan nama';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Sila masukkan URL';
                      }
                      final uri = Uri.tryParse(value);
                      if (uri == null || !uri.hasAbsolutePath) {
                        return 'URL tidak sah';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Penerangan (pilihan)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: displayOrder.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Susunan Paparan',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      displayOrder = int.tryParse(value) ?? 0;
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
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await _repo.updateLink(
                      id: link.id,
                      platform: selectedPlatform,
                      name: nameController.text.trim(),
                      url: urlController.text.trim(),
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      displayOrder: displayOrder,
                      isActive: isActive,
                    );
                    if (mounted) {
                      Navigator.of(context).pop();
                      _loadLinks();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pautan telah dikemaskini'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Gagal mengemaskini pautan: ${e.toString()}'),
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
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteLink(CommunityLink link) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam Pautan'),
        content: Text('Adakah anda pasti mahu memadam "${link.name}"?'),
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
        await _repo.deleteLink(link.id);
        if (mounted) {
          _loadLinks();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pautan telah dipadam'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memadam pautan: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
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
        title: const Text('Urus Pautan Komuniti'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLinks,
            tooltip: 'Muat semula',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _links.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadLinks,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _links.length,
                    itemBuilder: (context, index) {
                      return _buildLinkCard(_links[index]);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLinkDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Pautan'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Tiada pautan komuniti',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambah pautan Facebook, Telegram, atau platform lain',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard(CommunityLink link) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(link.platformIcon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          link.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!link.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Tidak Aktif',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    link.platformLabel,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  if (link.description != null && link.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      link.description!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, size: 20, color: Colors.red),
                      const SizedBox(width: 8),
                      Text('Padam', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditLinkDialog(link);
                } else if (value == 'delete') {
                  _deleteLink(link);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

