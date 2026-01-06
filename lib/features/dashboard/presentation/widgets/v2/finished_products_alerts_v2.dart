import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbizz/core/supabase/supabase_client.dart';
import 'package:pocketbizz/core/theme/app_colors.dart';
import 'package:pocketbizz/data/models/finished_product.dart';
import 'package:pocketbizz/data/repositories/finished_products_repository_supabase.dart';

class FinishedProductsAlertsV2 extends StatefulWidget {
  final VoidCallback onViewAll;

  const FinishedProductsAlertsV2({
    super.key,
    required this.onViewAll,
  });

  @override
  State<FinishedProductsAlertsV2> createState() => _FinishedProductsAlertsV2State();
}

class _FinishedProductsAlertsV2State extends State<FinishedProductsAlertsV2> {
  final _repo = FinishedProductsRepository();

  bool _loading = true;
  List<FinishedProductSummary> _items = [];

  // Real-time subscription for production_batches
  StreamSubscription? _productionBatchesSubscription;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _productionBatchesSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Setup real-time subscription for production_batches table
  void _setupRealtimeSubscription() {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Subscribe to production_batches changes for current user only
      _productionBatchesSubscription = supabase
          .from('production_batches')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((data) {
            // Production batches updated - refresh finished products list with debounce
            if (mounted) {
              _debouncedRefresh();
            }
          });

      debugPrint('✅ Finished Products real-time subscription setup complete');
    } catch (e) {
      debugPrint('⚠️ Error setting up finished products real-time subscription: $e');
      // Continue without real-time - fallback to manual refresh
    }
  }

  /// Debounced refresh to avoid excessive updates
  void _debouncedRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _load();
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _repo.getFinishedProductsSummary();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _card(
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Center(child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      );
    }

    if (_items.isEmpty) {
      return _card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: AppColors.success, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stok Produk Siap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('Belum ada batch produksi yang aktif', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              TextButton(
                onPressed: widget.onViewAll,
                child: const Text('Lihat'),
              ),
            ],
          ),
        ),
      );
    }

    final low = _items
        .where((p) => p.totalRemaining > 0)
        .toList()
      ..sort((a, b) => a.totalRemaining.compareTo(b.totalRemaining));
    // Heuristic threshold (no user config yet): only warn if stock is truly low.
    // Default: ≤ 5 unit remaining.
    final lowTop3 = low.where((p) => p.totalRemaining <= 5).take(3).toList();

    final now = DateTime.now();
    final expiryCutoff = now.add(const Duration(days: 3));
    final expiring = _items
        .where((p) => p.nearestExpiry != null && p.totalRemaining > 0)
        .where((p) => !p.nearestExpiry!.isAfter(expiryCutoff))
        .toList()
      ..sort((a, b) => a.nearestExpiry!.compareTo(b.nearestExpiry!));
    final expTop3 = expiring.take(3).toList();

    // If neither low nor expiring has anything interesting, keep it simple.
    if (lowTop3.isEmpty && expTop3.isEmpty) {
      return _card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stok Produk Siap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('Semua stok produk siap nampak okay', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              TextButton(onPressed: widget.onViewAll, child: const Text('Lihat')),
            ],
          ),
        ),
      );
    }

    return _card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: Colors.green, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stok Produk Siap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('Alert awal untuk tindakan pantas', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                TextButton(onPressed: widget.onViewAll, child: const Text('Lihat Stok')),
              ],
            ),
            const SizedBox(height: 14),

            if (lowTop3.isNotEmpty) ...[
              _sectionTitle(icon: Icons.warning_amber_rounded, color: Colors.orange, title: 'Hampir Habis'),
              const SizedBox(height: 8),
              ...lowTop3.map((p) => _rowLow(p)).toList(),
              const SizedBox(height: 14),
            ],

            if (expTop3.isNotEmpty) ...[
              _sectionTitle(icon: Icons.timer_rounded, color: Colors.red, title: 'Hampir Luput (≤ 3 hari)'),
              const SizedBox(height: 8),
              ...expTop3.map((p) => _rowExpiry(p)).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle({required IconData icon, required Color color, required String title}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _rowLow(FinishedProductSummary p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              p.productName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.orange.withOpacity(0.22)),
            ),
            child: Text(
              '${_formatQty(p.totalRemaining)} unit',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowExpiry(FinishedProductSummary p) {
    final exp = p.nearestExpiry!;
    final now = DateTime.now();
    final days = exp.difference(DateTime(now.year, now.month, now.day)).inDays;
    final label = days <= 0 ? 'Hari ini' : '$days hari';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.productName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Luput: ${DateFormat('d MMM', 'ms_MY').format(exp)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.red.withOpacity(0.22)),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppColors.cardShadow,
      ),
      child: child,
    );
  }

  String _formatQty(double v) {
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}


