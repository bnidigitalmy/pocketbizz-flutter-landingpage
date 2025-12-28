import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/bulk_production_preview.dart';
import '../../../../data/models/product.dart';
import '../../../../data/models/production_batch.dart';
import '../../../../data/repositories/production_repository_supabase.dart';
import '../../../../data/repositories/production_batch_rpc_repository.dart';
import '../../../../data/repositories/shopping_cart_repository_supabase.dart';

class BulkProductionPlanningDialog extends StatefulWidget {
  final List<Product> products;
  final ProductionRepository productionRepo;
  final ProductionBatchRpcRepository productionBatchRepo;
  final ShoppingCartRepository cartRepo;
  final VoidCallback onSuccess;

  const BulkProductionPlanningDialog({
    super.key,
    required this.products,
    required this.productionRepo,
    required this.productionBatchRepo,
    required this.cartRepo,
    required this.onSuccess,
  });

  @override
  State<BulkProductionPlanningDialog> createState() => _BulkProductionPlanningDialogState();
}

class _BulkProductionPlanningDialogState extends State<BulkProductionPlanningDialog> {
  String _step = 'select'; // select, preview
  final Map<String, int> _batchCounts = {};
  final Map<String, DateTime?> _expiryByProductId = {};
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final Map<String, bool> _expandedProducts = {};

  BulkProductionPlan? _plan;
  bool _isLoading = false;

  DateTime _batchDate = DateTime.now();
  DateTime? _expiryDate;
  bool _expiryPerProduct = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  int _getBatch(String productId) => _batchCounts[productId] ?? 0;

  List<Product> get _filteredProducts {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = List<Product>.from(widget.products);
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (q.isEmpty) return list;
    return list.where((p) => p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q)).toList();
  }

  List<BulkProductionSelection> _buildSelections() {
    final selections = <BulkProductionSelection>[];
    for (final e in _batchCounts.entries) {
      if (e.value > 0) {
        selections.add(BulkProductionSelection(productId: e.key, batchCount: e.value));
      }
    }
    return selections;
  }

  Future<void> _handlePreview() async {
    final selections = _buildSelections();
    if (selections.isEmpty) {
      _getRootScaffoldMessenger()?.showSnackBar(
        const SnackBar(content: Text('Sila pilih sekurang-kurangnya 1 produk dan kuantiti batch.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final plan = await widget.productionRepo.previewBulkProductionPlan(selections: selections);
      setState(() {
        _plan = plan;
        _step = 'preview';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _getRootScaffoldMessenger()?.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Helper method to get root ScaffoldMessenger for showing snackbars above dialogs
  ScaffoldMessengerState? _getRootScaffoldMessenger() {
    try {
      // Get the root navigator and find ScaffoldMessenger in its overlay
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      final rootOverlay = rootNavigator.overlay;
      if (rootOverlay != null) {
        final rootContext = rootOverlay.context;
        final scaffoldMessenger = ScaffoldMessenger.maybeOf(rootContext);
        if (scaffoldMessenger != null) return scaffoldMessenger;
      }
      // Try finding ScaffoldMessenger by traversing up the widget tree
      return context.findAncestorStateOfType<ScaffoldMessengerState>();
    } catch (_) {
      // Fallback to regular context if root navigator not available
    }
    return ScaffoldMessenger.maybeOf(context);
  }

  Future<void> _addShortagesToShoppingList() async {
    if (_plan == null) return;
    final shortages = _plan!.materials.where((m) => !m.isSufficient).toList();
    if (shortages.isEmpty) {
      _getRootScaffoldMessenger()?.showSnackBar(
        const SnackBar(content: Text('✅ Semua bahan mencukupi. Tiada yang perlu dibeli.'), backgroundColor: AppColors.success),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      int success = 0;
      int fail = 0;

      for (final m in shortages) {
        try {
          await widget.cartRepo.addToCart(
            stockItemId: m.stockItemId,
            shortageQty: m.suggestedBuyQty,
            priority: 'high',
            notes: 'Bulk produksi - kurang: ${m.shortageStockQty.toStringAsFixed(2)} ${m.stockUnit} '
                '(cadangan: ${m.packagesNeeded} pek/pcs)',
          );
          success++;
        } catch (_) {
          fail++;
        }
      }

      setState(() => _isLoading = false);
      if (mounted) {
        _getRootScaffoldMessenger()?.showSnackBar(
          SnackBar(
            content: Text(fail > 0 ? '✅ $success item ditambah. ❌ $fail gagal.' : '✅ $success item ditambah ke Senarai Belian.'),
            backgroundColor: fail > 0 ? Colors.orange : AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _getRootScaffoldMessenger()?.showSnackBar(
          SnackBar(content: Text('Gagal tambah ke senarai belian: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _produceNowPartial() async {
    if (_plan == null) return;

    final producible = _plan!.products.where((p) => p.canProduceNow && p.hasActiveRecipe && p.batchCount > 0).toList();
    final skipped = _plan!.products.where((p) => !p.canProduceNow || !p.hasActiveRecipe).toList();

    if (producible.isEmpty) {
      _getRootScaffoldMessenger()?.showSnackBar(
        const SnackBar(
          content: Text('❌ Tiada produk yang boleh diproduce sekarang (stok tak cukup / tiada resipi).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final produced = <BulkProductionProductPlan>[];
    final failed = <String, String>{}; // productId -> error

    try {
      for (final p in producible) {
        try {
          final expiryForProduct =
              _expiryPerProduct ? _expiryByProductId[p.productId] : null;
          final expiryToUse = expiryForProduct ?? _expiryDate;

          final input = ProductionBatchInput(
            productId: p.productId,
            quantity: p.totalUnits,
            batchDate: _batchDate,
            expiryDate: expiryToUse,
            notes: _notesCtrl.text.trim().isEmpty ? 'Bulk produksi' : 'Bulk produksi: ${_notesCtrl.text.trim()}',
          );
          await widget.productionBatchRepo.recordProductionBatch(input);
          produced.add(p);
        } catch (e) {
          failed[p.productId] = e.toString();
        }
      }

      setState(() => _isLoading = false);
      if (!mounted) return;

      widget.onSuccess();

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Ringkasan Bulk Produksi'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('✅ Berjaya produce: ${produced.length} produk', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...produced.map((p) => Text('• ${p.productName} (${p.batchCount} batch = ${p.totalUnits} unit)')),
                    const SizedBox(height: 16),
                    Text('⛔ Tidak diproduce: ${skipped.length + failed.length} produk', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...skipped.map((p) {
                      if (!p.hasActiveRecipe) {
                        return Text('• ${p.productName}: tiada resipi aktif');
                      }
                      if (p.blockers.isEmpty) return Text('• ${p.productName}: stok tidak cukup');
                      final b = p.blockers.take(3).map((x) => '${x.stockItemName} (-${x.shortageInStockUnit.toStringAsFixed(2)} ${x.stockUnit})').join(', ');
                      return Text('• ${p.productName}: stok tidak cukup ($b)');
                    }),
                    ...failed.entries.map((e) {
                      final name = _plan!.products.firstWhere((p) => p.productId == e.key).productName;
                      return Text('• $name: gagal produce (${e.value})');
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _getRootScaffoldMessenger()?.showSnackBar(
          SnackBar(content: Text('Gagal bulk produce: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickDate({required bool isExpiry}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isExpiry ? (_expiryDate ?? DateTime.now()) : _batchDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null) return;
    setState(() {
      if (isExpiry) {
        _expiryDate = date;
      } else {
        _batchDate = date;
      }
    });
  }

  Future<void> _pickExpiryForProduct(String productId) async {
    final initial = _expiryByProductId[productId] ?? _expiryDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null) return;
    setState(() {
      _expiryByProductId[productId] = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 860),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.factory, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _step == 'select' ? 'Bulk Produksi' : 'Preview Bulk Produksi',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _step == 'select'
                              ? 'Pilih banyak produk & kuantiti batch'
                              : 'Semak bahan diperlukan & produce separa jika perlu',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _step == 'select' ? _buildSelectStep() : _buildPreviewStep(),
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: _buildFooter(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Cari produk...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _searchCtrl.clear()),
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              _buildDateRow(
                label: 'Tarikh Produksi',
                value: DateFormat('dd MMM yyyy', 'ms_MY').format(_batchDate),
                onTap: () => _pickDate(isExpiry: false),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Expiry ikut produk',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: const Text(
                        'Jika ON, setiap produk boleh set tarikh luput berbeza (optional).',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: _expiryPerProduct,
                      onChanged: (v) => setState(() => _expiryPerProduct = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildDateRow(
                label: _expiryPerProduct ? 'Expiry Default (Optional)' : 'Tarikh Luput (Optional)',
                value: _expiryDate == null ? 'Tidak set' : DateFormat('dd MMM yyyy', 'ms_MY').format(_expiryDate!),
                onTap: () => _pickDate(isExpiry: true),
                clearable: _expiryDate != null,
                onClear: () => setState(() => _expiryDate = null),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nota (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Pilih Produk (${_buildSelections().length} dipilih)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._filteredProducts.map(_buildProductRow),
      ],
    );
  }

  Widget _buildDateRow({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool clearable = false,
    VoidCallback? onClear,
  }) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              child: Text(value),
            ),
          ),
        ),
        if (clearable)
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.clear),
            onPressed: onClear,
          ),
      ],
    );
  }

  Widget _buildProductRow(Product p) {
    final count = _getBatch(p.id);
    final expiry = _expiryByProductId[p.id];
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: count > 0 ? AppColors.primary.withOpacity(0.4) : Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    '${p.unitsPerBatch} unit/batch',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (_expiryPerProduct && count > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.event_available, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          expiry == null
                              ? 'Expiry: ikut default'
                              : 'Expiry: ${DateFormat('dd MMM yyyy', 'ms_MY').format(expiry)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (_expiryPerProduct && count > 0) ...[
              OutlinedButton(
                onPressed: _isLoading ? null : () => _pickExpiryForProduct(p.id),
                child: const Text('Luput'),
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              tooltip: 'Kurang',
              onPressed: () => setState(() {
                final next = (count - 1);
                if (next <= 0) {
                  _batchCounts.remove(p.id);
                  _expiryByProductId.remove(p.id);
                } else {
                  _batchCounts[p.id] = next;
                }
              }),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 44,
              child: Center(
                child: Text(
                  count.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Tambah',
              onPressed: () => setState(() {
                _batchCounts[p.id] = count + 1;
              }),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewStep() {
    final plan = _plan;
    if (plan == null) return const SizedBox.shrink();

    final insufficientMaterials = plan.materials.where((m) => !m.isSufficient).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: AppColors.primary.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ringkasan',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                const SizedBox(height: 8),
                Text('Produk dipilih: ${plan.selectedCount}'),
                Text('Produk boleh diproduksi sekarang: ${plan.producibleCount}/${plan.selectedCount}'),
                Text('Bahan tidak mencukupi (perlu dibeli): ${insufficientMaterials.length} item'),
              ],
            ),
          ),
        ),
        if (insufficientMaterials.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withOpacity(0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Stok tidak mencukupi untuk produce semua produk.\n'
                    'Sila beli bahan terlebih dahulu (atau guna “Produce Yang Boleh” untuk hasilkan yang cukup stok).',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text('Produk Dipilih (dengan bahan digunakan)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...plan.products.map((p) => _buildProductPreviewCard(p)),
        const SizedBox(height: 16),
        const Text('Bahan Yang Tidak Mencukupi (Perlu dibeli)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (insufficientMaterials.isEmpty)
          Text(
            '✅ Semua bahan mencukupi.',
            style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w600),
          ),
        ...insufficientMaterials.map((m) => _buildInsufficientMaterialCard(m)),
      ],
    );
  }

  Widget _buildInsufficientMaterialCard(BulkMaterialSummary m) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.red.withOpacity(0.05),
      child: ListTile(
        leading: const Icon(Icons.cancel, color: Colors.red),
        title: Text(
          m.stockItemName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Diperlukan: ${m.requiredStockQty.toStringAsFixed(2)} ${m.stockUnit}'),
            Text('Stok: ${m.currentStock.toStringAsFixed(2)} ${m.stockUnit}'),
            Text(
              'Kurang: ${m.shortageStockQty.toStringAsFixed(2)} ${m.stockUnit}',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.shopping_bag, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Cadangan Beli: ${m.packagesNeeded} pek/pcs '
                      '(${m.suggestedBuyQty.toStringAsFixed(2)} ${m.stockUnit})',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductPreviewCard(BulkProductionProductPlan p) {
    final statusColor = p.canProduceNow ? Colors.green : Colors.red;
    final isExpanded = _expandedProducts[p.productId] ?? false;
    final reason = !p.hasActiveRecipe
        ? 'Tiada resipi aktif'
        : p.canProduceNow
            ? 'Boleh produce'
            : 'Stok tidak mencukupi';
    final expiry = _expiryPerProduct ? _expiryByProductId[p.productId] : null;
    final expiryToShow = expiry ?? _expiryDate;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.25)),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        onExpansionChanged: (expanded) => setState(() {
          _expandedProducts[p.productId] = expanded;
        }),
        leading: const Icon(Icons.check_circle, color: AppColors.primary),
        title: Text('${p.productName} (${p.batchCount} batch = ${p.totalUnits} unit)'),
        subtitle: Text(expiryToShow == null ? reason : '$reason • Expiry: ${DateFormat('dd MMM yyyy', 'ms_MY').format(expiryToShow)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!p.hasActiveRecipe)
              Icon(Icons.info_outline, color: Colors.grey[600])
            else if (!p.canProduceNow)
              const Icon(Icons.warning_amber_rounded, color: Colors.red)
            else
              const Icon(Icons.check_circle_outline, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              'RM ${p.estimatedTotalCost.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey[600],
            ),
          ],
        ),
        children: [
          if (!p.hasActiveRecipe)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Tiada bahan untuk dipreview kerana resipi aktif belum diset.'),
            )
          else if (p.materials.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Tiada bahan ditemui untuk produk ini.'),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bahan digunakan:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...p.materials.map((m) {
                    final usageText = '${m.quantityUsageUnit.toStringAsFixed(2)} ${m.usageUnit}';
                    final convertedSameUnit =
                        (m.usageUnit.toLowerCase().trim() == m.stockUnit.toLowerCase().trim());
                    final convertedText =
                        convertedSameUnit ? null : '≈ ${m.quantityStockUnit.toStringAsFixed(2)} ${m.stockUnit}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.circle, size: 6, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              m.stockItemName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                usageText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (convertedText != null)
                                Text(
                                  convertedText,
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                            ],
                          )
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    if (_step == 'select') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _handlePreview,
              icon: const Icon(Icons.visibility),
              label: const Text('Preview'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 520;
        if (wide) {
          return Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => setState(() => _step = 'select'),
                  child: const Text('Kembali'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _addShortagesToShoppingList,
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Tambah ke Senarai'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _produceNowPartial,
                  icon: const Icon(Icons.factory),
                  label: const Text('Produce Yang Boleh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => setState(() => _step = 'select'),
                    child: const Text('Kembali'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _produceNowPartial,
                    icon: const Icon(Icons.factory),
                    label: const Text('Produce Yang Boleh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _addShortagesToShoppingList,
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Tambah ke Senarai Belian'),
              ),
            ),
          ],
        );
      },
    );
  }
}


