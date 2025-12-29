import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';

/// Komuniti PocketBizz - Join our community
class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  // Community Links
  static const String _facebookGroupUrl = 'https://www.facebook.com/groups/1322714392872778';
  static const String _telegramGroupUrl = 'https://t.me/+mt3lnFqb6cllNjVl';
  static const String _telegramChannelUrl = 'https://t.me/+LEQ2DsbJnt4wYjll';

  Future<void> _openLink(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak boleh membuka pautan'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Komuniti PocketBizz'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Banner
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  // Banner Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/Pocketbizz banner - white.png',
                      height: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 100,
                          color: Colors.white.withOpacity(0.1),
                          child: const Center(
                            child: Icon(Icons.image, color: Colors.white54, size: 40),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '🎉 Jom Sertai Keluarga PocketBizz!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Berkongsi pengalaman, dapatkan tips & bantuan dari pengguna lain',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Community Links
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 12),
                    child: Text(
                      '👥 Komuniti',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),

                  // Facebook Group
                  _buildCommunityCard(
                    context: context,
                    title: 'PocketBizz Communities',
                    subtitle: 'Facebook Group',
                    description: 'Berbincang, kongsi tips & dapatkan bantuan dari komuniti',
                    imagePath: 'assets/images/Pocketbizz Communities - facebook.png',
                    color: const Color(0xFF1877F2),
                    icon: Icons.facebook,
                    url: _facebookGroupUrl,
                    buttonText: 'Sertai Group',
                  ),

                  const SizedBox(height: 16),

                  // Telegram Group
                  _buildCommunityCard(
                    context: context,
                    title: 'PocketBizz Communities',
                    subtitle: 'Telegram Group',
                    description: 'Group chat untuk perbincangan & soal jawab',
                    imagePath: 'assets/images/Pocketbizz Communities - telegram.png',
                    color: const Color(0xFF0088CC),
                    icon: Icons.telegram,
                    url: _telegramGroupUrl,
                    buttonText: 'Sertai Group',
                  ),

                  const SizedBox(height: 24),

                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 12),
                    child: Text(
                      '📢 Info & Pengumuman',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),

                  // Telegram Channel
                  _buildCommunityCard(
                    context: context,
                    title: 'PocketBizz Info',
                    subtitle: 'Telegram Channel',
                    description: 'Dapatkan info terkini, update & tips bisnes',
                    imagePath: 'assets/images/Pocketbizz Channel - info.png',
                    color: const Color(0xFF0088CC),
                    icon: Icons.campaign,
                    url: _telegramChannelUrl,
                    buttonText: 'Langgan Channel',
                  ),

                  const SizedBox(height: 32),

                  // Benefits Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✨ Kelebihan Sertai Komuniti',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildBenefitRow(Icons.help_outline, 'Dapat bantuan dari pengguna lain'),
                        _buildBenefitRow(Icons.lightbulb_outline, 'Tips & trick guna PocketBizz'),
                        _buildBenefitRow(Icons.campaign_outlined, 'Info update & feature baru'),
                        _buildBenefitRow(Icons.people_outline, 'Network dengan usahawan lain'),
                        _buildBenefitRow(Icons.card_giftcard, 'Promo eksklusif untuk ahli'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String description,
    required String imagePath,
    required Color color,
    required IconData icon,
    required String url,
    required String buttonText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 160,
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(icon, size: 48, color: color),
                  );
                },
              ),
            ),
          ),
          // Content
          Padding(
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
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openLink(context, url),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: Text(buttonText),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

