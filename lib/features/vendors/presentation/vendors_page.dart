import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/models/vendor.dart';
import '../../subscription/widgets/subscription_guard.dart';
import 'commission_dialog.dart';
import 'vendor_detail_page.dart';
import '../../onboarding/presentation/widgets/contextual_tooltip.dart';
import '../../onboarding/data/tooltip_content.dart';
import '../../onboarding/services/tooltip_service.dart';

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
  List<Vendor> _vendors = [];
  bool _isLoading = true;

  // Dialog states
  bool _addDialogOpen = false;
  bool _commissionDialogOpen = false;
  Vendor? _selectedVendorForCommission;

  // Form controllers
  final _nameController = TextEditingController();
  final _vendorNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadVendors();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTooltip();
    });
  }

  Future<void> _checkAndShowTooltip() async {
    final hasData = _vendors.isNotEmpty;
    
    final shouldShow = await TooltipHelper.shouldShowTooltip(
      context,
      TooltipKeys.vendors,
      checkEmptyState: !hasData,
      emptyStateChecker: () => !hasData,
    );
    
    if (shouldShow && mounted) {
      final content = hasData ? TooltipContent.vendors : TooltipContent.vendorsEmpty;
      await TooltipHelper.showTooltip(
        context,
        content.moduleKey,
        content.title,
        content.message,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vendorNumberController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
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

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await _vendorsRepo.createVendor(
        name: _nameController.text.trim(),
        vendorNumber: _vendorNumberController.text.trim().isEmpty ? null : _vendorNumberController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Vendor telah ditambah'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() => _addDialogOpen = false);
        _resetForm();
        _loadVendors();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show dialogs when state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_addDialogOpen) {
        showDialog(
          context: context,
          builder: (context) => _buildAddDialog(),
        ).then((_) {
          if (mounted) {
            setState(() => _addDialogOpen = false);
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

    return SubscriptionGuard(
      featureName: 'Pengurusan Vendor',
      allowTrial: true,
      child: Scaffold(
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _resetForm();
          },
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context);
              await _handleCreate();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Simpan Vendor'),
        ),
      ],
    );
  }
}
