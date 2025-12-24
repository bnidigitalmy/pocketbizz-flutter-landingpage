import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart' show supabase;
import '../../../core/utils/admin_helper.dart';
import '../../../data/repositories/production_repository_supabase.dart';
import '../../../data/repositories/products_repository_supabase.dart';
import '../../../data/repositories/shopping_cart_repository_supabase.dart';
import '../../../data/repositories/planner_tasks_repository_supabase.dart';
import '../../../data/models/planner_task.dart';
import '../../../data/models/production_batch.dart';
import '../../../data/models/product.dart';
import 'widgets/production_planning_dialog.dart';
import 'widgets/bulk_production_planning_dialog.dart';

/// Production Planning Page - 3-Step Production Planning with Preview
class ProductionPlanningPage extends StatefulWidget {
  const ProductionPlanningPage({super.key});

  @override
  State<ProductionPlanningPage> createState() => _ProductionPlanningPageState();
}

class _ProductionPlanningPageState extends State<ProductionPlanningPage> {
  late final ProductionRepository _productionRepo;
  late final ProductsRepositorySupabase _productsRepo;
  late final ShoppingCartRepository _cartRepo;
  late final PlannerTasksRepositorySupabase _plannerRepo;

  List<Product> _products = [];
  List<ProductionBatch> _batches = [];
  List<PlannerTask> _scheduled = [];
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _productionRepo = ProductionRepository(supabase);
    _productsRepo = ProductsRepositorySupabase();
    _cartRepo = ShoppingCartRepository();
    _plannerRepo = PlannerTasksRepositorySupabase();
    // Initialize admin cache early so isAdminSync() works
    AdminHelper.initializeCache();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final [productsResult, batchesResult, scheduledResult] = await Future.wait([
        _productsRepo.listProducts(limit: 100),
        _productionRepo.getAllBatches(limit: 100),
        _plannerRepo.listTasks(scope: 'upcoming', tags: const ['production'], limit: 20),
      ]);

      // Sort batches: latest production date (or created) on top
      final sortedBatches = List<ProductionBatch>.from(batchesResult as List)
        ..sort((a, b) {
          final aDate = a.batchDate;
          final bDate = b.batchDate;
          return bDate.compareTo(aDate);
        });

      setState(() {
        _products = List<Product>.from(productsResult as List);
        _batches = sortedBatches;
        _scheduled = (scheduledResult as List<PlannerTask>)
            .where((t) => t.status != 'done' && t.status != 'cancelled')
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        // Show error in console for debugging
        debugPrint('Error loading production data: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error memuat data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }


  void _showPlanningDialog() {
    showDialog(
      context: context,
      builder: (context) => ProductionPlanningDialog(
        products: _products,
        productionRepo: _productionRepo,
        cartRepo: _cartRepo,
        onSuccess: _loadData,
      ),
    );
  }

  void _showBulkPlanningDialog() {
    showDialog(
      context: context,
      builder: (context) => BulkProductionPlanningDialog(
        products: _products,
        productionRepo: _productionRepo,
        cartRepo: _cartRepo,
        onSuccess: _loadData,
      ),
    );
  }

  Future<void> _showPlanChooser() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.restaurant_menu, color: AppColors.primary),
                  title: const Text('Rancang Produksi (1 Produk)'),
                  subtitle: const Text('Pilih 1 produk, semak bahan & rekod produksi'),
                  onTap: () {
                    Navigator.pop(context);
                    _showPlanningDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.factory, color: AppColors.primary),
                  title: const Text('Bulk Produksi (Banyak Produk)'),
                  subtitle: const Text('Pilih banyak produk + batch, auto gabung bahan & senarai belian'),
                  onTap: () {
                    Navigator.pop(context);
                    _showBulkPlanningDialog();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _getExpiryStatus(DateTime? expiryDate) {
    if (expiryDate == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = expiryDate.copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final twoDaysFromNow = today.add(const Duration(days: 2));

    if (expiry.isBefore(today)) return 'expired';
    if (expiry.isAfter(today) && expiry.isBefore(twoDaysFromNow)) return 'expiring';
    return 'fresh';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Produksi'),
            Text(
              '${_batches.length} rekod',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header text only (FAB used for action)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rancang & Rekod Produksi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih produk, semak bahan, rekod produksi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildScheduledSection(),
                    ],
                  ),
                ),

                // Production History
                Expanded(
                  child: _batches.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _batches.length,
                            itemBuilder: (context, index) {
                              return _buildBatchCard(_batches[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPlanChooser,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Rancang/Bulk'),
      ),
    );
  }

  Widget _buildScheduledSection() {
    final next = List<PlannerTask>.from(_scheduled)
      ..sort((a, b) {
        final ad = a.dueAt ?? DateTime.now().add(const Duration(days: 3650));
        final bd = b.dueAt ?? DateTime.now().add(const Duration(days: 3650));
        return ad.compareTo(bd);
      });

    final upcoming = next.take(3).toList();

    if (upcoming.isEmpty) {
      return Row(
        children: [
          Icon(Icons.event_available, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            'Tiada jadual produksi akan datang',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/planner'),
            child: const Text('Buka Planner'),
          ),
        ],
      );
    }

    return Card(
      elevation: 0,
      color: Colors.blue.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_note, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Jadual Produksi (akan datang)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/planner'),
                  child: const Text('Lihat semua'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...upcoming.map((t) {
              final due = t.dueAt;
              final when = due != null
                  ? DateFormat('dd MMM, hh:mm a', 'ms_MY').format(due)
                  : 'Tiada masa';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      when,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'Tiada Rekod Produksi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mulakan dengan merancang produksi pertama',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(ProductionBatch batch) {
    final expiryStatus = _getExpiryStatus(batch.expiryDate);
    final isAdmin = AdminHelper.isAdminSync();
    final canEdit = batch.canBeEdited(isAdmin: isAdmin);
    
    // Find product to get image
    final product = _products.firstWhere(
      (p) => p.id == batch.productId || p.name == batch.productName,
      orElse: () => Product(
        id: '',
        businessOwnerId: '',
        sku: '',
        name: batch.productName ?? 'Unknown',
        unit: '',
        salePrice: 0.0,
        costPrice: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final productionDate = batch.batchDate;
    final expiryDate = batch.expiryDate;
    final dateFormat = DateFormat('dd MMM yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Product Image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            product.imageUrl!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  color: Colors.grey[400],
                                  size: 28,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.grey[400],
                            size: 28,
                          ),
                        ),
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
                              batch.productName ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          // Edit/Delete buttons (if allowed)
                          if (canEdit)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20),
                              onSelected: (value) {
                                if (value == 'edit_notes') {
                                  _showEditNotesDialog(batch);
                                } else if (value == 'delete') {
                                  _showDeleteConfirmDialog(batch);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit_notes',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_note, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit Nota'),
                                    ],
                                  ),
                                ),
                                if (canEdit) // Only show delete if can edit
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Padam', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Chip(
                            label: Text('${batch.quantity} unit'),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                          ),
                          if (productionDate != null)
                            Chip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.event_note, size: 14, color: Colors.blueGrey),
                                  const SizedBox(width: 4),
                                  Text('Produksi: ${dateFormat.format(productionDate)}'),
                                ],
                              ),
                              backgroundColor: Colors.blueGrey.withOpacity(0.12),
                            ),
                          if (expiryDate != null)
                            Chip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    expiryStatus == 'expired'
                                        ? Icons.warning
                                        : expiryStatus == 'expiring'
                                            ? Icons.warning_amber
                                            : Icons.event_available,
                                    size: 14,
                                    color: expiryStatus == 'expired'
                                        ? Colors.red
                                        : expiryStatus == 'expiring'
                                            ? Colors.orange
                                            : Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('Luput: ${dateFormat.format(expiryDate)}'),
                                ],
                              ),
                              backgroundColor: expiryStatus == 'expired'
                                  ? Colors.red.withOpacity(0.12)
                                  : expiryStatus == 'expiring'
                                      ? Colors.orange.withOpacity(0.12)
                                      : Colors.green.withOpacity(0.12),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Kos',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'RM ${batch.totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (batch.notes != null && batch.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Nota: ${batch.notes}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showEditNotesDialog(ProductionBatch batch) async {
    final notesController = TextEditingController(text: batch.notes ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Nota'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(
            hintText: 'Masukkan nota...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await _productionRepo.updateBatchNotes(
          batch.id,
          notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nota berjaya dikemaskini'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal kemaskini nota: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showDeleteConfirmDialog(ProductionBatch batch) async {
    final isAdmin = AdminHelper.isAdminSync();
    final hoursSinceCreation = DateTime.now().difference(batch.createdAt).inHours;
    final canDelete = isAdmin || hoursSinceCreation < 24;

    if (!canDelete) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rekod produksi hanya boleh dipadam dalam tempoh 24 jam selepas dicipta, atau oleh admin'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam Rekod Produksi?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Produk: ${batch.productName}'),
            const SizedBox(height: 8),
            Text('Kuantiti: ${batch.quantity} unit'),
            const SizedBox(height: 8),
            Text('Kos: RM ${batch.totalCost.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ PERINGATAN:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tindakan ini akan:',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text('• Memadam rekod produksi', style: TextStyle(fontSize: 12)),
                  Text('• Membalikkan semua potongan stok bahan', style: TextStyle(fontSize: 12)),
                  Text('• Memadam rekod penggunaan bahan', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            if (batch.hasBeenUsed) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: const Text(
                  '⚠️ Rekod ini telah digunakan dalam jualan. Memadam mungkin mempengaruhi laporan.',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Padam'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _productionRepo.deleteBatchWithStockReversal(batch.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rekod produksi berjaya dipadam. Stok telah dibalikkan.'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal padam rekod: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

