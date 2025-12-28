/**
 * 🔒 STABLE CORE MODULE – DO NOT MODIFY
 * This file is production-tested.
 * Any changes must be isolated via extension or wrapper.
 */
// ❌ AI WARNING:
// DO NOT refactor, rename, optimize or restructure this logic.
// Only READ-ONLY reference allowed.

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/repositories/vendor_commission_price_ranges_repository_supabase.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/vendor_commission_price_range.dart';
import '../../subscription/widgets/subscription_guard.dart';
import 'commission_dialog.dart';
import 'vendor_detail_page.dart';

/// Vendors Page (Consignment System)
/// Manage Consignees (kedai yang jual produk untuk user)
/// 
/// This is part of the Consignment System:
/// - User (Consignor) = Pengeluar/owner produk
/// - Vendor (Consignee) = Kedai yang jual produk dengan commission
/// 
/// Features:
/// - Add/Edit/Delete vendors (consignees)
/// - Setup commission rates
/// - Track vendor claims and payments
class VendorsPage extends StatefulWidget {
  const VendorsPage({super.key});

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  final _vendorsRepo = VendorsRepositorySupabase();
  final _priceRangesRepo = VendorCommissionPriceRangesRepository();
  List<Vendor> _vendors = [];
  bool _isLoading = true;

  // Dialog states
  bool _addDialogOpen = false;
  bool _addDialogShowing = false; // Track if dialog is currently showing
  bool _commissionDialogOpen = false;
  Vendor? _selectedVendorForCommission;

  // Form controllers
  final _nameController = TextEditingController();
  final _vendorNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _commissionController = TextEditingController(text: '15.0');
  final _formKey = GlobalKey<FormState>();
  
  // Commission settings
  String _commissionType = 'percentage';
  List<Map<String, dynamic>> _priceRanges = []; // Temporary price ranges before vendor created

  @override
  void initState() {
    super.initState();
    _loadVendors();
    WidgetsBinding.instance.addPostFrameCallback((_) {
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vendorNumberController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  Future<void> _loadVendors() async {
    setState(() => _isLoading = true);
    try {
      final vendors = await _vendorsRepo.getAllVendors(activeOnly: false);
      if (mounted) {
        setState(() {
          _vendors = vendors;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading vendors: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetForm() {
    _nameController.clear();
    _vendorNumberController.clear();
    _phoneController.clear();
    _addressController.clear();
    _commissionController.text = '15.0';
    _commissionType = 'percentage';
    _priceRanges.clear();
    _formKey.currentState?.reset();
  }

  void _openAddDialog() {
    _resetForm();
    setState(() => _addDialogOpen = true);
  }

  void _openCommissionDialog(Vendor vendor) {
    setState(() {
      _selectedVendorForCommission = vendor;
      _commissionDialogOpen = true;
    });
  }

  Future<void> _handleCreate(BuildContext dialogContext) async {
    if (!_formKey.currentState!.validate()) return;

    // Validate price ranges if commission type is price_range
    if (_commissionType == 'price_range' && _priceRanges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila tambah sekurang-kurangnya satu price range'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Parse commission rate
      final commissionRate = _commissionType == 'percentage'
          ? double.tryParse(_commissionController.text.trim()) ?? 15.0
          : 0.0;
      
      // Create vendor
      final vendor = await _vendorsRepo.createVendor(
        name: _nameController.text.trim(),
        vendorNumber: _vendorNumberController.text.trim().isEmpty ? null : _vendorNumberController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        commissionType: _commissionType,
        defaultCommissionRate: commissionRate,
      );

      // Create price ranges if commission type is price_range
      if (_commissionType == 'price_range' && _priceRanges.isNotEmpty) {
        for (int i = 0; i < _priceRanges.length; i++) {
          await _priceRangesRepo.createPriceRange(
            vendorId: vendor.id,
            minPrice: _priceRanges[i]['minPrice'] as double,
            maxPrice: _priceRanges[i]['maxPrice'] as double?,
            commissionAmount: _priceRanges[i]['commission'] as double,
            position: i,
          );
        }
      }

      // Close dialog first
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }

      // Set state to prevent dialog from reopening
      if (mounted) {
        setState(() {
          _addDialogOpen = false;
          _addDialogShowing = false;
        });
      }

      // Then show success and refresh
      if (mounted) {
        _resetForm();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Vendor telah ditambah'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadVendors();
      }
    } catch (e) {
      if (mounted) {
        // PHASE: Handle subscription enforcement errors
        final handled = await SubscriptionEnforcement.maybePromptUpgrade(
          context,
          action: 'Tambah Vendor',
          error: e,
        );
        if (handled) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal simpan: Sila cuba lagi'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show dialogs when state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_addDialogOpen && !_addDialogShowing) {
        setState(() => _addDialogShowing = true);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildAddDialog(),
        ).then((_) {
          if (mounted) {
            setState(() {
              _addDialogOpen = false;
              _addDialogShowing = false;
            });
          }
        });
      }
      if (_commissionDialogOpen && _selectedVendorForCommission != null) {
        showDialog(
          context: context,
          builder: (context) => CommissionDialog(
            vendorId: _selectedVendorForCommission!.id,
            vendorName: _selectedVendorForCommission!.name,
            onClose: () {
              if (mounted) {
                setState(() {
                  _commissionDialogOpen = false;
                  _selectedVendorForCommission = null;
                });
                _loadVendors(); // Refresh to show updated commission
              }
            },
          ),
        ).then((_) {
          if (mounted) {
            setState(() {
              _commissionDialogOpen = false;
              _selectedVendorForCommission = null;
            });
          }
        });
      }
    });

    final canPop = ModalRoute.of(context)?.canPop ?? false;

    // NOTE: SubscriptionGuard removed - expired users can VIEW vendors (read-only)
    // Write operations are protected by SubscriptionEnforcement in catch blocks
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (canPop) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/');
            }
          },
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vendor'),
            Text(
              'Urus senarai vendor anda',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memuat vendor...'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadVendors,
              child: _vendors.isEmpty
                  ? _buildEmptyState()
                  : _buildVendorsGrid(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Vendor'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 200,
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.store,
                      size: 32,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tiada Vendor',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tambah vendor untuk mula merekod penghantaran',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVendorsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.85,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _vendors.length,
          itemBuilder: (context, index) {
            return _buildVendorCard(_vendors[index]);
          },
        );
      },
    );
  }

  Widget _buildVendorCard(Vendor vendor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VendorDetailPage(vendorId: vendor.id),
            ),
          ).then((_) => _loadVendors()); // Refresh after returning
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and name
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.store,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vendor.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (vendor.phone != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.phone,
                                size: 12,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  vendor.phone!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Address
              if (vendor.address != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        vendor.address!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              const Spacer(),
              // Commission setup button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openCommissionDialog(vendor),
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('Setup Komisyen'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddDialog() {
    return StatefulBuilder(
      builder: (context, setDialogState) {
    return AlertDialog(
      title: const Text('Tambah Vendor Baru'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan maklumat vendor',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Vendor',
                  hintText: 'cth: Kedai Kak Ani',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama vendor diperlukan';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vendorNumberController,
                decoration: const InputDecoration(
                  labelText: 'Nombor Vendor (NV)',
                  hintText: 'cth: NV001, V-001',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                  helperText: 'Nombor vendor untuk invois (optional)',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'No. Telefon',
                  hintText: 'cth: 012-3456789',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Alamat',
                  hintText: 'Alamat kedai/lokasi vendor',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),
              // Commission Settings Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.percent, size: 20, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Tetapan Komisyen',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _commissionType,
                      decoration: const InputDecoration(
                        labelText: 'Jenis Komisyen',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.settings),
                        helperText: 'Pilih jenis komisyen untuk vendor ini',
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
                          setDialogState(() {
                            _commissionType = value;
                          });
                        }
                      },
                    ),
                    if (_commissionType == 'percentage') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _commissionController,
                        decoration: const InputDecoration(
                          labelText: 'Kadar Komisyen (%)',
                          hintText: 'cth: 15.0',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.percent),
                          suffixText: '%',
                          helperText: 'Kadar komisyen default untuk vendor ini (0-100%)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Kadar komisyen diperlukan';
                          }
                          final rate = double.tryParse(value);
                          if (rate == null || rate < 0 || rate > 100) {
                            return 'Sila masukkan kadar yang sah (0-100%)';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (_commissionType == 'price_range') ...[
                      const SizedBox(height: 12),
                      _buildPriceRangesSection(setDialogState),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            if (mounted) {
              setState(() {
                _addDialogOpen = false;
                _addDialogShowing = false;
              });
            }
            _resetForm();
          },
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () async {
            await _handleCreate(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Simpan Vendor'),
        ),
      ],
    );
      },
    );
  }

  // Price Range Management Methods
  Widget _buildPriceRangesSection(StateSetter setDialogState) {
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
              icon: const Icon(Icons.add_circle, color: AppColors.primary),
              onPressed: () => _showAddPriceRangeDialog(setDialogState),
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
          ..._priceRanges.asMap().entries.map((entry) {
            final index = entry.key;
            final range = entry.value;
            return _buildPriceRangeCard(range, index, setDialogState);
          }),
      ],
    );
  }

  Widget _buildPriceRangeCard(Map<String, dynamic> range, int index, StateSetter setDialogState) {
    final minPrice = range['minPrice'] as double;
    final maxPrice = range['maxPrice'] as double?;
    final commission = range['commission'] as double;
    
    final maxPriceText = maxPrice == null 
        ? 'dan ke atas' 
        : 'hingga RM${maxPrice.toStringAsFixed(2)}';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          'RM${minPrice.toStringAsFixed(2)} $maxPriceText',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Komisyen: RM${commission.toStringAsFixed(2)}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _removePriceRange(index, setDialogState),
        ),
      ),
    );
  }

  Future<void> _showAddPriceRangeDialog(StateSetter setDialogState) async {
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

                if (minPrice == null || commission == null) {
                  return;
                }

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
      setDialogState(() {
        _priceRanges.add(result);
      });
    }
  }

  void _removePriceRange(int index, StateSetter setDialogState) {
    setDialogState(() {
      _priceRanges.removeAt(index);
    });
  }
}
