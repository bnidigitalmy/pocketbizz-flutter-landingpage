import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/pricing_tier.dart';
import '../../data/repositories/subscription_repository_extension.dart';

/// Pricing Tier Card Widget
/// Displays a single pricing tier with all details
class PricingTierCard extends StatelessWidget {
  final PricingTier tier;
  final bool isSelected;
  final bool isUserTier;
  final VoidCallback? onTap;

  const PricingTierCard({
    super.key,
    required this.tier,
    this.isSelected = false,
    this.isUserTier = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSoldOut = tier.isSoldOut;
    final isCurrent = tier.isCurrentTier;

    return Card(
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected 
              ? AppColors.primary 
              : (isUserTier ? AppColors.success : Colors.grey.shade300),
          width: isSelected || isUserTier ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isSoldOut ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: isSoldOut ? 0.6 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tier.tierNameDisplay,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSoldOut 
                              ? AppColors.textSecondary 
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isCurrent && !isSoldOut)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'AKTIF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    if (isUserTier)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ANDA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    if (isSoldOut)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'HABIS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'RM${tier.priceMonthly.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isSoldOut 
                            ? AppColors.textSecondary 
                            : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '/bulan',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Slots remaining
                if (!tier.isUnlimited) ...[
                  _buildProgressBar(tier),
                  const SizedBox(height: 8),
                  Text(
                    tier.slotsRemainingText,
                    style: TextStyle(
                      fontSize: 12,
                      color: tier.isSoldOut 
                          ? Colors.red 
                          : (tier.slotsRemaining != null && tier.slotsRemaining! < 10)
                              ? Colors.orange
                              : AppColors.textSecondary,
                      fontWeight: tier.isSoldOut ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ] else ...[
                  Text(
                    '∞ Unlimited slots',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                
                const SizedBox(height: 8),

                // Description
                if (tier.description != null)
                  Text(
                    tier.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(PricingTier tier) {
    final percentage = tier.usagePercentage / 100;
    return Container(
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: Colors.grey.shade200,
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: percentage.clamp(0, 1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: tier.isSoldOut 
                ? Colors.red 
                : (percentage > 0.8 ? Colors.orange : AppColors.primary),
          ),
        ),
      ),
    );
  }
}

/// Pricing Tiers Widget
/// Displays all pricing tiers in a horizontal or vertical layout
class PricingTiersWidget extends StatefulWidget {
  final String? userLockedTier;
  final Axis direction;
  final void Function(PricingTier)? onTierSelected;

  const PricingTiersWidget({
    super.key,
    this.userLockedTier,
    this.direction = Axis.horizontal,
    this.onTierSelected,
  });

  @override
  State<PricingTiersWidget> createState() => _PricingTiersWidgetState();
}

class _PricingTiersWidgetState extends State<PricingTiersWidget> {
  final _pricingRepo = SubscriptionPricingRepository();
  List<PricingTier> _tiers = [];
  bool _loading = true;
  String? _selectedTierName;

  @override
  void initState() {
    super.initState();
    _loadTiers();
  }

  Future<void> _loadTiers() async {
    setState(() => _loading = true);
    try {
      final tiers = await _pricingRepo.getAllPricingTiers();
      if (mounted) {
        setState(() {
          _tiers = tiers;
          // Pre-select current tier
          _selectedTierName = tiers.firstWhere(
            (t) => t.isCurrentTier,
            orElse: () => tiers.first,
          ).tierName;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_tiers.isEmpty) {
      return const Center(
        child: Text('Tiada maklumat harga'),
      );
    }

    if (widget.direction == Axis.horizontal) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: _tiers.map((tier) {
            return SizedBox(
              width: 200,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: PricingTierCard(
                  tier: tier,
                  isSelected: _selectedTierName == tier.tierName,
                  isUserTier: widget.userLockedTier == tier.tierName,
                  onTap: () {
                    setState(() => _selectedTierName = tier.tierName);
                    widget.onTierSelected?.call(tier);
                  },
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    return Column(
      children: _tiers.map((tier) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PricingTierCard(
            tier: tier,
            isSelected: _selectedTierName == tier.tierName,
            isUserTier: widget.userLockedTier == tier.tierName,
            onTap: () {
              setState(() => _selectedTierName = tier.tierName);
              widget.onTierSelected?.call(tier);
            },
          ),
        );
      }).toList(),
    );
  }
}

/// Compact Pricing Banner Widget
/// Shows current pricing info in a compact banner format
class PricingBannerWidget extends StatefulWidget {
  final bool showUrgency;

  const PricingBannerWidget({
    super.key,
    this.showUrgency = true,
  });

  @override
  State<PricingBannerWidget> createState() => _PricingBannerWidgetState();
}

class _PricingBannerWidgetState extends State<PricingBannerWidget> {
  final _pricingRepo = SubscriptionPricingRepository();
  PricingInfo? _pricingInfo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPricingInfo();
  }

  Future<void> _loadPricingInfo() async {
    try {
      final info = await _pricingRepo.getPricingInfo();
      if (mounted) {
        setState(() {
          _pricingInfo = info;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }

    if (_pricingInfo == null) {
      return const SizedBox.shrink();
    }

    final currentTier = _pricingInfo!.currentTier;
    final isEarlyAdopter = currentTier.isEarlyAdopter;
    final isGrowth = currentTier.isGrowth;
    final slotsRemaining = currentTier.slotsRemaining ?? 0;
    final isUrgent = slotsRemaining < 20 && !currentTier.isUnlimited;

    Color bgColor;
    IconData icon;
    String message;

    if (isEarlyAdopter) {
      bgColor = Colors.orange.shade50;
      icon = Icons.local_fire_department;
      message = 'Early Adopter: RM29/bulan - Hanya $slotsRemaining slot lagi!';
    } else if (isGrowth) {
      bgColor = Colors.blue.shade50;
      icon = Icons.trending_up;
      message = 'Growth: RM39/bulan - $slotsRemaining slot sebelum naik ke RM49';
    } else {
      bgColor = Colors.grey.shade100;
      icon = Icons.star;
      message = 'Standard: RM49/bulan - Akses penuh semua features';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: isUrgent 
            ? Border.all(color: Colors.orange, width: 2)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isEarlyAdopter 
                ? Colors.orange 
                : (isGrowth ? Colors.blue : Colors.grey),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (widget.showUrgency && isUrgent)
                  Text(
                    '⚠️ Hampir habis! Daftar sekarang untuk lock harga ini',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Early Adopter Badge Widget
/// Small badge showing early adopter status
class EarlyAdopterBadge extends StatelessWidget {
  final bool isEarlyAdopter;
  final int? slotsRemaining;

  const EarlyAdopterBadge({
    super.key,
    required this.isEarlyAdopter,
    this.slotsRemaining,
  });

  @override
  Widget build(BuildContext context) {
    if (!isEarlyAdopter) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            slotsRemaining != null 
                ? 'Early Adopter ($slotsRemaining left)'
                : 'Early Adopter',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
