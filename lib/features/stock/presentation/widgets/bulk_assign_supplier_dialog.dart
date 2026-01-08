import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/repositories/suppliers_repository_supabase.dart';
import '../../../../data/repositories/stock_repository_supabase.dart';
import '../../../../data/models/supplier.dart';
import '../../../../data/models/stock_item.dart';
import '../../../../core/supabase/supabase_client.dart' show supabase;

/// Dialog untuk bulk assign supplier kepada multiple stock items
class BulkAssignSupplierDialog extends StatefulWidget {
  final List<StockItem> selectedItems;

  const BulkAssignSupplierDialog({
    super.key,
    required this.selectedItems,
  });

  @override
  State<BulkAssignSupplierDialog> createState() => _BulkAssignSupplierDialogState();
}

class _BulkAssignSupplierDialogState extends State<BulkAssignSupplierDialog> {
  final _suppliersRepo = SuppliersRepository();
  final _stockRepo = StockRepository(supabase);
  
  List<Supplier> _suppliers = [];
  String? _selectedSupplierId;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    try {
      final suppliers = await _suppliersRepo.getAllSuppliers();
      if (mounted) {
        setState(() {
          _suppliers = suppliers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading suppliers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila pilih supplier terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      int successCount = 0;
      int failureCount = 0;
      List<String> errors = [];

      // Bulk update supplier untuk setiap item
      for (final item in widget.selectedItems) {
        try {
          final input = StockItemInput(
            name: item.name,
            unit: item.unit,
            packageSize: item.packageSize,
            purchasePrice: item.purchasePrice,
            lowStockThreshold: item.lowStockThreshold,
            notes: item.notes,
            supplierId: _selectedSupplierId, // Update supplier
          );

          await _stockRepo.updateStockItem(item.id, input);
          successCount++;
        } catch (e) {
          failureCount++;
          errors.add('${item.name}: $e');
        }
      }

      if (mounted) {
        setState(() => _isSaving = false);

        // Show result
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Keputusan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✅ Berjaya: $successCount item'),
                  Text('❌ Gagal: $failureCount item'),
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Ralat:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...errors.take(5).map((error) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        error,
                        style: const TextStyle(fontSize: 12),
                      ),
                    )),
                    if (errors.length > 5)
                      Text('... dan ${errors.length - 5} ralat lagi'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close result dialog
                  Navigator.pop(context, true); // Close main dialog with success
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedSupplier = _suppliers.firstWhere(
      (s) => s.id == _selectedSupplierId,
      orElse: () => Supplier(
        id: '',
        businessOwnerId: '',
        name: 'Tiada supplier',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.assignment_ind, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Assign Supplier'),
                Text(
                  '${widget.selectedItems.length} item dipilih',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih supplier untuk assign kepada semua item yang dipilih:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedSupplierId,
                    decoration: InputDecoration(
                      labelText: 'Supplier',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.store),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Tiada supplier'),
                      ),
                      ..._suppliers.map((supplier) {
                        return DropdownMenuItem<String>(
                          value: supplier.id,
                          child: Text(supplier.name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedSupplierId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Item yang akan di-update:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...widget.selectedItems.take(5).map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.inventory_2, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        )),
                        if (widget.selectedItems.length > 5)
                          Text(
                            '... dan ${widget.selectedItems.length - 5} item lagi',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

