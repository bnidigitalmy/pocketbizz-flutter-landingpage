/**
 * 🔒 STABLE CORE MODULE – DO NOT MODIFY
 * This file is production-tested.
 * Any changes must be isolated via extension or wrapper.
 */
// ❌ AI WARNING:
// DO NOT refactor, rename, optimize or restructure this logic.
// Only READ-ONLY reference allowed.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/repositories/vendor_commission_price_ranges_repository_supabase.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/vendor_commission_price_range.dart';
import '../../subscription/widgets/subscription_guard.dart';

/// Commission Setup Dialog
/// Allows setting up commission rates for vendors
class CommissionDialog extends StatefulWidget {
  final String vendorId;
  final String vendorName;
  final VoidCallback? onClose;

  const CommissionDialog({
    super.key,
    required this.vendorId,
    required this.vendorName,
    this.onClose,
  });

  @override
  State<CommissionDialog> createState() => _CommissionDialogState();
}

class _CommissionDialogState extends State<CommissionDialog> {
  final _vendorsRepo = VendorsRepositorySupabase();
  final _priceRangesRepo = VendorCommissionPriceRangesRepository();
  final _commissionController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;
  Vendor? _vendor;
  String _commissionType = 'percentage';
  List<VendorCommissionPriceRange> _priceRanges = [];

  @override
  void initState() {
    super.initState();
    _loadVendor();
  }

  @override
  void dispose() {
    _commissionController.dispose();
    super.dispose();
  }

  Future<void> _loadVendor() async {
    setState(() => _isLoading = true);
    try {
      final vendor = await _vendorsRepo.getVendorById(widget.vendorId);
      if (mounted && vendor != null) {
        setState(() {
          _vendor = vendor;
          _commissionType = vendor.commissionType;
          _commissionController.text = vendor.defaultCommissionRate.toStringAsFixed(2);
        });
        
        // Load price ranges if commission type is price_range
        if (_commissionType == 'price_range') {
          final ranges = await _priceRangesRepo.getPriceRanges(widget.vendorId);
          if (mounted) {
            setState(() {
              _priceRanges = ranges;
              _isLoading = false;
            });
          }
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading vendor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveCommission() async {
    if (_commissionType == 'percentage') {
      final commissionRate = double.tryParse(_commissionController.text);
      if (commissionRate == null || commissionRate < 0 || commissionRate > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sila masukkan kadar komisyen yang sah (0-100%)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else if (_commissionType == 'price_range') {
      if (_priceRanges.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sila tambah sekurang-kurangnya satu price range'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final updateData = <String, dynamic>{
        'commission_type': _commissionType,
      };
      
      if (_commissionType == 'percentage') {
        final commissionRate = double.tryParse(_commissionController.text);
        if (commissionRate == null) {
          if (mounted) {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sila masukkan kadar komisyen yang sah'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        updateData['default_commission_rate'] = commissionRate;
        debugPrint('💾 Saving commission: type=$_commissionType, rate=$commissionRate');
      } else if (_commissionType == 'price_range') {
        debugPrint('💾 Saving commission: type=$_commissionType, ranges=${_priceRanges.length}');
      }

      debugPrint('📝 Update data: $updateData');
      await _vendorsRepo.updateVendor(widget.vendorId, updateData);
      debugPrint('✅ Vendor commission updated successfully');

      // Reload vendor data to reflect changes in the dialog
      await _loadVendor();

      // Reset saving state before closing
      if (mounted) {
        setState(() => _isSaving = false);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Komisyen berjaya dikemaskini'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onClose?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        // PHASE: Handle subscription enforcement errors
        final handled = await SubscriptionEnforcement.maybePromptUpgrade(
          context,
          action: 'Kemaskini Komisyen',
          error: e,
        );
        if (handled) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal kemaskini: Sila cuba lagi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Setup Komisyen'),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vendor: ${widget.vendorName}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tetapkan kadar komisyen default untuk vendor ini. Kadar ini akan digunakan untuk semua produk kecuali ditetapkan sebaliknya.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  // Commission Type Selector
                  DropdownButtonFormField<String>(
                    value: _commissionType,
                    decoration: InputDecoration(
                      labelText: 'Jenis Komisyen *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.settings),
                      helperText: _commissionType == 'percentage'
                          ? 'Komisyen berdasarkan peratusan harga jualan (cth: 10%, 15%, 20%)'
                          : 'Komisyen berdasarkan julat harga (cth: RM0.1-RM5=RM1, RM5.01-RM10=RM1.50)',
                      helperMaxLines: 2,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'percentage',
                        child: Text('Peratus (%)'),
                      ),
                      DropdownMenuItem(
                        value: 'price_range',
                        child: Text('Price Range'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _commissionType = value);
                        if (value == 'price_range' && _priceRanges.isEmpty) {
                          _loadPriceRanges();
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Commission Input based on type
                  if (_commissionType == 'percentage') ...[
                    TextFormField(
                      controller: _commissionController,
                      decoration: const InputDecoration(
                        labelText: 'Kadar Komisyen (%)',
                        hintText: 'cth: 10.0',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.percent),
                        suffixText: '%',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ] else if (_commissionType == 'price_range') ...[
                    _buildPriceRangesSection(),
                  ],
                  if (_vendor != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _commissionType == 'percentage'
                                  ? 'Kadar semasa: ${_vendor!.defaultCommissionRate.toStringAsFixed(2)}%'
                                  : _priceRanges.isEmpty
                                      ? 'Tiada price range ditetapkan'
                                      : 'Price range: ${_priceRanges.length} julat harga',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveCommission,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
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

  Future<void> _loadPriceRanges() async {
    try {
      final ranges = await _priceRangesRepo.getPriceRanges(widget.vendorId);
      if (mounted) {
        setState(() => _priceRanges = ranges);
      }
    } catch (e) {
      debugPrint('Error loading price ranges: $e');
    }
  }

  Widget _buildPriceRangesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Price Ranges',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddPriceRangeDialog,
              tooltip: 'Tambah Price Range',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_priceRanges.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Tiada price range. Klik + untuk tambah.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          )
        else
          ..._priceRanges.map((range) => _buildPriceRangeCard(range)),
      ],
    );
  }

  Widget _buildPriceRangeCard(VendorCommissionPriceRange range) {
    final maxPriceText = range.maxPrice == null 
        ? 'dan ke atas' 
        : 'hingga RM${range.maxPrice!.toStringAsFixed(2)}';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          'RM${range.minPrice.toStringAsFixed(2)} $maxPriceText',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Komisyen: RM${range.commissionAmount.toStringAsFixed(2)}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deletePriceRange(range.id),
        ),
      ),
    );
  }

  Future<void> _showAddPriceRangeDialog() async {
    final minPriceController = TextEditingController();
    final maxPriceController = TextEditingController();
    final commissionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, double?>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Price Range'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: minPriceController,
                decoration: const InputDecoration(
                  labelText: 'Harga Min (RM) *',
                  hintText: '0.10',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Harga min diperlukan';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price < 0) {
                      return 'Sila masukkan harga yang sah';
                    }
                    return null;
                  },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: maxPriceController,
                decoration: const InputDecoration(
                  labelText: 'Harga Max (RM) - Kosongkan untuk unlimited',
                  hintText: '5.00',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final price = double.tryParse(value);
                      if (price == null || price < 0) {
                        return 'Sila masukkan harga yang sah';
                      }
                      final minPrice = double.tryParse(minPriceController.text);
                      if (minPrice != null && price <= minPrice) {
                        return 'Harga max mesti lebih besar dari harga min';
                      }
                    }
                    return null;
                  },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: commissionController,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Komisyen (RM) *',
                  hintText: '1.00',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Jumlah komisyen diperlukan';
                    }
                    final commission = double.tryParse(value);
                    if (commission == null || commission < 0) {
                      return 'Sila masukkan jumlah komisyen yang sah';
                    }
                    return null;
                  },
              ),
            ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final minPrice = double.tryParse(minPriceController.text);
                final maxPrice = maxPriceController.text.trim().isEmpty
                    ? null
                    : double.tryParse(maxPriceController.text);
                final commission = double.tryParse(commissionController.text);

                // Double check (validation should catch this, but just in case)
                if (minPrice == null || commission == null) {
                  return;
                }

                // Check max price > min price
                if (maxPrice != null && maxPrice <= minPrice) {
                  return;
                }

                Navigator.pop(context, {
                  'minPrice': minPrice,
                  'maxPrice': maxPrice,
                  'commission': commission,
                });
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );

    if (result != null) {
      final minPrice = result['minPrice']!;
      final maxPrice = result['maxPrice'];
      final commission = result['commission']!;

      try {
        await _priceRangesRepo.createPriceRange(
          vendorId: widget.vendorId,
          minPrice: minPrice,
          maxPrice: maxPrice,
          commissionAmount: commission,
          position: _priceRanges.length,
        );
        
        await _loadPriceRanges();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Price range berjaya ditambah'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // PHASE: Handle subscription enforcement errors
          final handled = await SubscriptionEnforcement.maybePromptUpgrade(
            context,
            action: 'Tambah Price Range',
            error: e,
          );
          if (handled) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal tambah: Sila cuba lagi'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deletePriceRange(String rangeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam Price Range?'),
        content: const Text('Adakah anda pasti untuk memadam price range ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Padam', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _priceRangesRepo.deletePriceRange(rangeId);
        await _loadPriceRanges();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Price range berjaya dipadam'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // PHASE: Handle subscription enforcement errors
          final handled = await SubscriptionEnforcement.maybePromptUpgrade(
            context,
            action: 'Padam Price Range',
            error: e,
          );
          if (handled) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal padam: Sila cuba lagi'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

