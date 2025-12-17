import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/admin_helper.dart';
import '../../../data/models/community_link.dart';
import '../../../data/repositories/community_links_repository_supabase.dart';
import 'admin/admin_community_links_page.dart';

/// Page for users to view and join community links
class CommunityLinksPage extends StatefulWidget {
  const CommunityLinksPage({super.key});

  @override
  State<CommunityLinksPage> createState() => _CommunityLinksPageState();
}

class _CommunityLinksPageState extends State<CommunityLinksPage> {
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
      final links = await _repo.getActiveLinks();
      setState(() {
        _links = links;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuatkan pautan komuniti: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openLink(CommunityLink link) async {
    try {
      final uri = Uri.parse(link.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tidak boleh membuka pautan: ${link.url}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat membuka pautan: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Komuniti PocketBizz'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (AdminHelper.isAdmin())
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminCommunityLinksPage(),
                  ),
                ).then((_) => _loadLinks());
              },
              tooltip: 'Urus Pautan',
            ),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Tiada pautan komuniti',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sertai komuniti PocketBizz untuk dapatkan bantuan dan berkongsi pengalaman',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
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
      child: InkWell(
        onTap: () => _openLink(link),
        borderRadius: BorderRadius.circular(12),
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
                child: Icon(
                  link.platformIcon,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      link.platformLabel,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (link.description != null && link.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        link.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

