import 'package:flutter/material.dart';
import 'package:pocketbizz/core/theme/app_colors.dart';

class PrimaryQuickActionsV2 extends StatelessWidget {
  final VoidCallback onAddSale;
  final VoidCallback onAddStock;
  final VoidCallback onStartProduction;
  final VoidCallback onDelivery;
  final VoidCallback onAddExpense;
  final List<MoreQuickActionV2> moreActions;

  const PrimaryQuickActionsV2({
    super.key,
    required this.onAddSale,
    required this.onAddStock,
    required this.onStartProduction,
    required this.onDelivery,
    required this.onAddExpense,
    required this.moreActions,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.flash_on_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tindakan Pantas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isMobile ? 3 : 5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: isMobile ? 1.05 : 1.25,
            children: [
              _ActionTile(
                label: 'Tambah Jualan',
                icon: Icons.add_shopping_cart_rounded,
                color: AppColors.primary,
                onTap: onAddSale,
              ),
              _ActionTile(
                label: 'Tambah Stok',
                icon: Icons.inventory_2_rounded,
                color: Colors.blue,
                onTap: onAddStock,
              ),
              _ActionTile(
                label: 'Produksi',
                icon: Icons.factory_rounded,
                color: Colors.purple,
                onTap: onStartProduction,
              ),
              _ActionTile(
                label: 'Penghantaran',
                icon: Icons.local_shipping_rounded,
                color: Colors.orange,
                onTap: onDelivery,
              ),
              _ActionTile(
                label: 'Belanja',
                icon: Icons.payments_rounded,
                color: Colors.red,
                onTap: onAddExpense,
              ),
              _ActionTile(
                label: 'Lain-lain',
                icon: Icons.grid_view_rounded,
                color: Colors.teal,
                onTap: () => _openMoreMenu(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openMoreMenu(BuildContext context) async {
    if (moreActions.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isMobile = MediaQuery.of(context).size.width < 768;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Menu Lain',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Tutup',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isMobile ? 3 : 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: isMobile ? 1.05 : 1.25,
                  children: moreActions
                      .map(
                        (a) => _ActionTile(
                          label: a.label,
                          icon: a.icon,
                          color: a.color,
                          onTap: () {
                            Navigator.of(context).pop();
                            a.onTap();
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MoreQuickActionV2 {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  MoreQuickActionV2({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withOpacity(0.2), // Smooth splash effect
        highlightColor: color.withOpacity(0.1), // Smooth highlight on press
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


