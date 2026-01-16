import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../services/onboarding_service.dart';
import '../../feedback/presentation/user_guide_page.dart';

/// Dashboard widget showing setup progress for new users
class SetupChecklistWidget extends StatefulWidget {
  final VoidCallback? onDismiss;

  const SetupChecklistWidget({
    super.key,
    this.onDismiss,
  });

  @override
  State<SetupChecklistWidget> createState() => _SetupChecklistWidgetState();
}

class _SetupChecklistWidgetState extends State<SetupChecklistWidget> {
  final OnboardingService _onboardingService = OnboardingService();
  bool _shouldShow = false;
  bool _loading = true;
  Map<String, dynamic> _progress = {};
  int _progressPercentage = 0;
  bool _requiredComplete = false;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final shouldShow = await _onboardingService.shouldShowSetupWidget();
    final progress = await _onboardingService.getSetupProgress();
    final percentage = await _onboardingService.getSetupProgressPercentage();
    final requiredComplete = await _onboardingService.isSetupComplete();

    if (mounted) {
      setState(() {
        _shouldShow = shouldShow;
        _progress = progress;
        _progressPercentage = percentage;
        _requiredComplete = requiredComplete;
        _loading = false;
      });
    }
  }

  Future<void> _dismissWidget() async {
    await _onboardingService.dismissSetupWidget();
    if (mounted) {
      setState(() => _shouldShow = false);
    }
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }

    if (!_shouldShow) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.checklist,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Setup Bisnes Anda',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Dismiss button
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: _dismissWidget,
                color: AppColors.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Sembunyikan',
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            _requiredComplete 
                ? 'Setup wajib selesai! Lengkapkan task optional di bawah.'
                : 'Complete setup untuk guna semua features!',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 16),

          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progressPercentage / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _progressPercentage >= 80 ? Colors.green : AppColors.primary,
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$_progressPercentage%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _progressPercentage >= 80 ? Colors.green : AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Congratulations banner when required tasks complete
          if (_requiredComplete)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tahniah! Setup Wajib Selesai',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Anda boleh mula guna app! Task di bawah adalah optional.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Checklist items
          _buildChecklistItem(
            icon: Icons.inventory_2,
            color: Colors.blue,
            title: 'Tambah bahan mentah',
            subtitle: _progress['stock_added'] == true
                ? 'Siap!'
                : '(${_progress['stock_count'] ?? 0}/3)',
            isCompleted: _progress['stock_added'] == true,
            route: '/stock',
          ),

          _buildChecklistItem(
            icon: Icons.cake,
            color: Colors.brown,
            title: 'Cipta produk pertama',
            subtitle: _progress['product_created'] == true ? 'Siap!' : null,
            isCompleted: _progress['product_created'] == true,
            route: '/products/create',
          ),

          _buildChecklistItem(
            icon: Icons.factory,
            color: Colors.purple,
            title: 'Rekod pengeluaran pertama',
            subtitle: _progress['production_recorded'] == true ? 'Siap!' : null,
            isCompleted: _progress['production_recorded'] == true,
            route: '/production',
          ),

          _buildChecklistItem(
            icon: Icons.point_of_sale,
            color: Colors.green,
            title: 'Rekod jualan pertama',
            subtitle: _progress['sale_recorded'] == true ? 'Siap!' : null,
            isCompleted: _progress['sale_recorded'] == true,
            route: '/sales/create',
          ),

          _buildChecklistItem(
            icon: Icons.business,
            color: Colors.orange,
            title: 'Isi profile bisnes',
            subtitle: _progress['profile_completed'] == true ? 'Siap!' : '(optional)',
            isCompleted: _progress['profile_completed'] == true,
            route: '/settings',
            isOptional: true,
          ),

          _buildChecklistItem(
            icon: Icons.local_shipping,
            color: Colors.teal,
            title: 'Hantar ke kedai vendor',
            subtitle: _progress['delivery_recorded'] == true ? 'Siap!' : '(optional)',
            isCompleted: _progress['delivery_recorded'] == true,
            route: '/deliveries',
            isOptional: true,
          ),

          const SizedBox(height: 12),

          // Guide link
          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserGuidePage()),
                );
              },
              icon: const Icon(Icons.menu_book, size: 18),
              label: const Text('Lihat Panduan Lengkap'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required bool isCompleted,
    required String route,
    bool isOptional = false,
  }) {
    return InkWell(
      onTap: isCompleted
          ? null
          : () async {
              await Navigator.pushNamed(context, route);
              // Refresh progress after returning
              _loadProgress();
            },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isCompleted ? Colors.green : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),

            const SizedBox(width: 12),

            // Icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 18),
            ),

            const SizedBox(width: 12),

            // Title & subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isCompleted
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isCompleted ? Colors.green : AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),

            // Action button
            if (!isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isOptional ? 'Tetapan' : 'Mula',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_forward, size: 14, color: color),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
