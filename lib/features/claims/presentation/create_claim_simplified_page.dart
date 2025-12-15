import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/consignment_claims_repository_supabase.dart';
// Note: Using original repo for now, can switch to refactored version later
import '../../../data/repositories/deliveries_repository_supabase.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../../../data/repositories/carry_forward_repository_supabase.dart';
import '../../../data/models/claim_validation_result.dart';
import '../../../data/models/claim_summary.dart';
import '../../../data/models/delivery.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/consignment_claim.dart';
import '../../../data/models/business_profile.dart';
import '../../../data/models/carry_forward_item.dart';
import '../../../core/utils/pdf_generator.dart';
import 'widgets/claim_summary_card.dart';

/// Simplified Create Claim Page
/// Step-by-step flow yang mudah difahami untuk non-techy users
class CreateClaimSimplifiedPage extends StatefulWidget {
  const CreateClaimSimplifiedPage({super.key});

  @override
  State<CreateClaimSimplifiedPage> createState() =>
      _CreateClaimSimplifiedPageState();
}

class _CreateClaimSimplifiedPageState extends State<CreateClaimSimplifiedPage> {
  final _claimsRepo = ConsignmentClaimsRepositorySupabase();
  final _deliveriesRepo = DeliveriesRepositorySupabase();
  final _vendorsRepo = VendorsRepositorySupabase();
  final _businessProfileRepo = BusinessProfileRepository();
  final _carryForwardRepo = CarryForwardRepositorySupabase();

  // Data
  List<Vendor> _vendors = [];
  List<Delivery> _allDeliveries = [];
  List<Delivery> _availableDeliveries = []; // Only unclaimed deliveries
  Set<String> _claimedDeliveryIds = {}; // Track claimed delivery IDs
  List<Delivery> _claimedDeliveries = []; // Deliveries that have been claimed
  List<Delivery> _selectedDeliveries = [];
  List<Map<String, dynamic>> _deliveryItems =
      []; // Items with quantities to edit
  List<CarryForwardItem> _availableCarryForwardItems =
      []; // C/F items available for this vendor
  List<CarryForwardItem> _selectedCarryForwardItems =
      []; // C/F items selected for this claim
  Map<int, String> _cfStatus =
      {}; // Track user's choice per item: 'none', 'carry_forward', 'loss'

  // State
  int _currentStep = 1;
  String? _selectedVendorId;
  DateTime _claimDate = DateTime.now();
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  bool _isCreating = false;
  bool _isSavingQuantities = false;
  ClaimSummary? _claimSummary;
  ClaimValidationResult? _validationResult;
  ConsignmentClaim? _createdClaim; // Store created claim for Step 5
  BusinessProfile? _businessProfile;
  Vendor? _selectedVendor;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final vendors = await _vendorsRepo.getAllVendors(activeOnly: false);
      final deliveriesResult =
          await _deliveriesRepo.getAllDeliveries(limit: 1000, offset: 0);
      final deliveries = deliveriesResult['data'] as List<Delivery>;

      if (mounted) {
        setState(() {
          _vendors = vendors;
          _allDeliveries = deliveries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Ralat memuatkan data: $e');
      }
    }
  }

  void _onVendorSelected(String? vendorId) async {
    setState(() {
      _selectedVendorId = vendorId;
      _selectedDeliveries = [];
      _selectedCarryForwardItems = [];
      _claimSummary = null;
      _validationResult = null;
      _claimedDeliveryIds = {};
      _claimedDeliveries = [];
    });

    if (vendorId != null) {
      // Load claimed delivery IDs to track them
      try {
        final claimedDeliveryIds =
            await _claimsRepo.getClaimedDeliveryIds(vendorId);

        // Debug: Print claimed delivery IDs
        print(
            '🔍 Claimed delivery IDs for vendor $vendorId: ${claimedDeliveryIds.toList()}');
        print(
            '🔍 Total deliveries for vendor: ${_allDeliveries.where((d) => d.vendorId == vendorId && d.status == 'delivered').length}');

        if (mounted) {
          setState(() {
            _claimedDeliveryIds = claimedDeliveryIds;

            // Get all deliveries for vendor (both claimed and unclaimed)
            final allDeliveriesForVendor = _allDeliveries
                .where((d) => d.vendorId == vendorId && d.status == 'delivered')
                .toList();

            // Separate into available and claimed
            _availableDeliveries = allDeliveriesForVendor
                .where((d) => !claimedDeliveryIds.contains(d.id))
                .toList();

            _claimedDeliveries = allDeliveriesForVendor
                .where((d) => claimedDeliveryIds.contains(d.id))
                .toList();

            print('🔍 Available deliveries: ${_availableDeliveries.length}');
            print('🔍 Claimed deliveries: ${_claimedDeliveries.length}');
          });
        }

        // Load C/F items for this vendor
        _loadCarryForwardItems(vendorId);
      } catch (e) {
        // If error loading claimed IDs, show all deliveries (fallback)
        print('⚠️ Error loading claimed delivery IDs: $e');
        if (mounted) {
          setState(() {
            _availableDeliveries = _allDeliveries
                .where((d) => d.vendorId == vendorId && d.status == 'delivered')
                .toList();
            _claimedDeliveries = [];
          });
        }
        _loadCarryForwardItems(vendorId);
      }
    } else {
      setState(() {
        _availableDeliveries = [];
        _claimedDeliveries = [];
        _availableCarryForwardItems = [];
      });
    }

    if (vendorId != null && _currentStep == 1) {
      _nextStep();
    }
  }

  Future<void> _loadCarryForwardItems(String vendorId) async {
    try {
      final items = await _carryForwardRepo.getAvailableItemsWithDetails(
          vendorId: vendorId);
      if (mounted) {
        setState(() {
          _availableCarryForwardItems = items;
        });
      }
    } catch (e) {
      // Silently fail - C/F items are optional
      if (mounted) {
        setState(() {
          _availableCarryForwardItems = [];
        });
      }
    }
  }

  void _toggleCarryForwardSelection(CarryForwardItem item) {
    setState(() {
      if (_selectedCarryForwardItems.any((i) => i.id == item.id)) {
        _selectedCarryForwardItems.removeWhere((i) => i.id == item.id);
      } else {
        _selectedCarryForwardItems.add(item);
      }
      _claimSummary = null; // Reset summary when selection changes
      _deliveryItems = []; // Reset items when selection changes
    });
  }

  void _toggleDeliverySelection(Delivery delivery) {
    setState(() {
      if (_selectedDeliveries.any((d) => d.id == delivery.id)) {
        _selectedDeliveries.removeWhere((d) => d.id == delivery.id);
      } else {
        _selectedDeliveries.add(delivery);
      }
      _claimSummary = null; // Reset summary when selection changes
      _deliveryItems = []; // Reset items when selection changes
    });
  }

  Future<void> _loadDeliveryItems() async {
    if (_selectedDeliveries.isEmpty && _selectedCarryForwardItems.isEmpty)
      return;

    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> allItems = [];

      // Load items from selected deliveries
      for (var delivery in _selectedDeliveries) {
        final deliveryData = await _deliveriesRepo.getDeliveryById(delivery.id);
        if (deliveryData != null) {
          for (var item in deliveryData.items) {
            final quantity = item.quantity;
            final soldRaw = item.quantitySold ?? 0.0;
            final unsoldRaw = item.quantityUnsold ?? 0.0;
            final expiredRaw = item.quantityExpired ?? 0.0;
            final damagedRaw = item.quantityDamaged ?? 0.0;
            final sum = soldRaw + unsoldRaw + expiredRaw + damagedRaw;

            double sold = soldRaw;
            double unsold = unsoldRaw;
            double expired = expiredRaw;
            double damaged = damagedRaw;

            // Jika tiada rekod, auto assume semua terjual
            if (sum == 0 && quantity > 0) {
              sold = quantity;
              unsold = 0;
              expired = 0;
              damaged = 0;
            } else if ((sum - quantity).abs() > 0.01 && quantity > 0) {
              // Jika tidak seimbang, set unsold supaya balance
              final diff = quantity - sum;
              if (diff > 0) {
                unsold = (unsold + diff).clamp(0.0, quantity);
              }
            }

            allItems.add({
              'itemId': item.id, // used for metadata
              'deliveryItemId': item.id, // used for saving back
              'deliveryId': delivery.id,
              'deliveryDate': delivery.deliveryDate,
              'productName': item.productName,
              'quantity': quantity,
              'unitPrice': item.unitPrice,
              'quantitySold': sold,
              'quantityUnsold': unsold,
              'quantityExpired': expired,
              'quantityDamaged': damaged,
              'isCarryForward': false, // Regular delivery item
            });
          }
        }
      }

      // Add C/F items as virtual delivery items
      for (var cfItem in _selectedCarryForwardItems) {
        // For C/F items, start with all quantity assumed as sold (user can change if some expire/damage/CF)
        final cfQuantity = cfItem.quantityAvailable;
        allItems.add({
          'itemId': cfItem.sourceDeliveryItemId ??
              cfItem.id, // Use source item ID if available
          'deliveryId': cfItem.sourceDeliveryId ??
              'cf-${cfItem.id}', // Virtual delivery ID
          'deliveryDate': cfItem.createdAt, // Use C/F creation date
          'productName': cfItem.displayName,
          'quantity': cfQuantity, // Available quantity from C/F
          'unitPrice': cfItem.unitPrice,
          'quantitySold': cfQuantity, // Auto: assume all will be sold initially
          'quantityUnsold': 0.0, // Can be C/F again if not sold
          'quantityExpired': 0.0,
          'quantityDamaged': 0.0,
          'isCarryForward': true, // Mark as C/F item
          'carryForwardItemId':
              cfItem.id, // Store C/F item ID for later reference
          'sourceClaimNumber': cfItem.originalClaimNumber,
        });
      }

      if (mounted) {
        setState(() {
          _deliveryItems = allItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Ralat memuatkan item: $e');
      }
    }
  }

  void _updateItemQuantity(int index, String type, double value) {
    setState(() {
      final item = _deliveryItems[index];
      final total = item['quantity'] as double;

      // Update the specific quantity
      _deliveryItems[index][type] = value.clamp(0.0, total);

      // Auto-calculate sold quantity: total - expired - damaged - carryForward
      final expired = _deliveryItems[index]['quantityExpired'] as double;
      final damaged = _deliveryItems[index]['quantityDamaged'] as double;
      final carryForward =
          _deliveryItems[index]['quantityUnsold'] as double; // This is now C/F
      final sold = total - expired - damaged - carryForward;

      _deliveryItems[index]['quantitySold'] = sold.clamp(0.0, total);
    });
  }

  void _incrementQuantity(int index, String type) {
    final item = _deliveryItems[index];
    final current = item[type] as double;
    final total = item['quantity'] as double;
    final max = total;

    // Calculate current totals
    final expired = item['quantityExpired'] as double;
    final damaged = item['quantityDamaged'] as double;
    final unsold = item['quantityUnsold'] as double;
    final used = expired + damaged + unsold;

    // For expired/damaged/unsold, max is total - other quantities
    double available = 0.0;
    if (type == 'quantityExpired') {
      available = total - damaged - unsold;
    } else if (type == 'quantityDamaged') {
      available = total - expired - unsold;
    } else if (type == 'quantityUnsold') {
      available = total - expired - damaged;
    }

    if (current < available) {
      _updateItemQuantity(index, type, current + 1.0);
    }
  }

  void _decrementQuantity(int index, String type) {
    final item = _deliveryItems[index];
    final current = item[type] as double;
    if (current > 0) {
      _updateItemQuantity(index, type, current - 1.0);
    }
  }

  Future<void> _saveQuantities() async {
    if (_deliveryItems.isEmpty) {
      _nextStep();
      return;
    }

    setState(() => _isSavingQuantities = true);
    try {
      // Only update delivery items (not C/F items which don't have delivery_item records)
      final updates = _deliveryItems
          .where((item) =>
              item['deliveryItemId'] != null) // Only regular delivery items
          .map((item) {
        return <String, dynamic>{
          'itemId': item['deliveryItemId'],
          'productName': item['productName'],
          'quantitySold': item['quantitySold'],
          'quantityUnsold': item['quantityUnsold'],
          'quantityExpired': item['quantityExpired'],
          'quantityDamaged': item['quantityDamaged'],
        };
      }).toList();

      if (updates.isNotEmpty) {
        await _deliveriesRepo.batchUpdateDeliveryItemQuantities(
            updates: updates);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Kuantiti berjaya dikemaskini'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
        _nextStep();
      }
    } catch (e) {
      if (mounted) {
        _showError('Ralat menyimpan kuantiti: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingQuantities = false);
      }
    }
  }

  Future<void> _calculateSummary() async {
    if (_deliveryItems.isEmpty) {
      _showError('Sila pilih penghantaran atau item C/F terlebih dahulu');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Kira secara lokal dari _deliveryItems (termasuk C/F)
      final summary = ClaimSummary.fromDeliveryItems(
        deliveryItems: _deliveryItems.map((item) {
          return {
            'quantity': item['quantity'],
            'unit_price': item['unitPrice'],
            'quantity_sold': item['quantitySold'],
            'quantity_unsold': item['quantityUnsold'],
            'quantity_expired': item['quantityExpired'],
            'quantity_damaged': item['quantityDamaged'],
          };
        }).toList(),
        commissionRate: _selectedVendor?.defaultCommissionRate ?? 0.0,
      );

      if (mounted) {
        setState(() {
          _claimSummary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Ralat mengira jumlah: $e');
      }
    }
  }

  Future<void> _validateAndCreate() async {
    if (_selectedVendorId == null ||
        (_selectedDeliveries.isEmpty && _selectedCarryForwardItems.isEmpty)) {
      _showError(
          'Sila pilih sekurang-kurangnya satu penghantaran atau item C/F');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Validate first
      final validation = await _claimsRepo.validateClaimRequest(
        vendorId: _selectedVendorId!,
        deliveryIds: _selectedDeliveries.map((d) => d.id).toList(),
      );

      if (mounted) {
        setState(() {
          _validationResult = validation;
          _isLoading = false;
        });
      }

      if (!validation.isValid) {
        _showValidationErrors(validation);
        return;
      }

      // Show warnings if any
      if (validation.warnings.isNotEmpty) {
        _showWarnings(validation.warnings);
      }

      // Create claim
      setState(() => _isCreating = true);

      // Build item metadata with carry_forward_status
      final itemMetadata = <String, Map<String, dynamic>>{};
      for (var item in _deliveryItems) {
        final itemId = item['itemId'] as String;
        final cfStatus = _cfStatus[_deliveryItems.indexOf(item)] ?? 'none';
        itemMetadata[itemId] = {'carry_forward_status': cfStatus};
      }

      // Build carry forward payloads (virtual items) to include in claim
      final carryForwardItemsPayload = _deliveryItems
          .where((item) => item['isCarryForward'] == true)
          .map((item) {
        return {
          'id': item['deliveryItemId'] ?? item['itemId'], // treat as delivery_item_id
          'delivery_id': item['deliveryId'],
          'product_name': item['productName'],
          'quantity': item['quantity'],
          'unit_price': item['unitPrice'],
          'quantity_sold': item['quantitySold'],
          'quantity_unsold': item['quantityUnsold'],
          'quantity_expired': item['quantityExpired'],
          'quantity_damaged': item['quantityDamaged'],
          'carry_forward_item_id': item['carryForwardItemId'],
        };
      }).toList();

      final claim = await _claimsRepo.createClaim(
        vendorId: _selectedVendorId!,
        deliveryIds: _selectedDeliveries.map((d) => d.id).toList(),
        claimDate: _claimDate,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        itemMetadata: itemMetadata,
        carryForwardItems: carryForwardItemsPayload,
      );

      if (mounted) {
        // Mark C/F items as used
        if (_selectedCarryForwardItems.isNotEmpty) {
          try {
            await _carryForwardRepo.markAsUsed(
              carryForwardItemIds:
                  _selectedCarryForwardItems.map((i) => i.id).toList(),
              claimId: claim.id,
            );
          } catch (e) {
            // Log error but don't fail the claim creation
            print('Warning: Failed to mark C/F items as used: $e');
          }
        }

        // Load business profile and vendor info for Step 5
        final businessProfile = await _businessProfileRepo.getBusinessProfile();
        final vendor = _vendors.firstWhere((v) => v.id == _selectedVendorId);

        setState(() {
          _createdClaim = claim;
          _businessProfile = businessProfile;
          _selectedVendor = vendor;
          _currentStep = 5; // Go to Step 5 (Preview)
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        if (e is ClaimValidationException) {
          _showValidationErrors(e.validation);
        } else {
          _showError('Ralat mencipta tuntutan: $e');
        }
      }
    }
  }

  void _showValidationErrors(ClaimValidationResult validation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terdapat Masalah'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(validation.errorMessage),
            if (validation.warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                validation.warningMessage,
                style: TextStyle(color: Colors.orange[700]),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showWarnings(List<String> warnings) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚠️ ${warnings.join(", ")}'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < 5) {
      setState(() => _currentStep++);
      if (_currentStep == 3 &&
          (_selectedDeliveries.isNotEmpty ||
              _selectedCarryForwardItems.isNotEmpty)) {
        _loadDeliveryItems();
      } else if (_currentStep == 4 &&
          (_selectedDeliveries.isNotEmpty ||
              _selectedCarryForwardItems.isNotEmpty)) {
        _calculateSummary();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cipta Tuntutan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _currentStep == 1
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Progress Indicator
                _buildProgressIndicator(),

                // Step Content
                Expanded(
                  child: _currentStep == 3
                      ? _buildStepContent() // Step 3 handles its own scrolling
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _buildStepContent(),
                        ),
                ),

                // Navigation Buttons
                _buildNavigationButtons(),
              ],
            ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          _buildProgressStep(1, 'Vendor'),
          _buildProgressLine(_currentStep > 1),
          _buildProgressStep(2, 'Penghantaran'),
          _buildProgressLine(_currentStep > 2),
          _buildProgressStep(3, 'Kuantiti'),
          _buildProgressLine(_currentStep > 3),
          _buildProgressStep(4, 'Semak'),
          _buildProgressLine(_currentStep > 4),
          _buildProgressStep(5, 'Selesai'),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int step, String label) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.success
                  : isActive
                      ? AppColors.primary
                      : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                      '$step',
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive || isCompleted
                  ? AppColors.primary
                  : Colors.grey[600],
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? AppColors.primary : Colors.grey[300],
        margin: const EdgeInsets.only(bottom: 16),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1VendorSelection();
      case 2:
        return _buildStep2DeliverySelection();
      case 3:
        return _buildStep3QuantityUpdate(); // NEW: Update quantities step
      case 4:
        return _buildStep4Review();
      case 5:
        return _buildStep5Summary();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1VendorSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Langkah 1: Pilih Vendor',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pilih vendor yang anda ingin tuntut bayaran',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: _selectedVendorId,
              decoration: const InputDecoration(
                labelText: 'Pilih Vendor',
                border: OutlineInputBorder(),
                helperText: 'Pilih vendor untuk lihat senarai penghantaran',
              ),
              items: _vendors.map((vendor) {
                return DropdownMenuItem(
                  value: vendor.id,
                  child: Text(
                    vendor.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _onVendorSelected,
              isExpanded: true,
            ),
          ),
        ),
        if (_selectedVendorId != null) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Vendor dipilih: ${_vendors.firstWhere((v) => v.id == _selectedVendorId).name}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStep2DeliverySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Langkah 2: Pilih Penghantaran',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pilih penghantaran yang anda ingin tuntut',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),

        // Available Deliveries Section
        if (_availableDeliveries.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green[600],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Penghantaran Belum Dituntut (${_availableDeliveries.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._availableDeliveries.map((delivery) {
                final isSelected =
                    _selectedDeliveries.any((d) => d.id == delivery.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected ? Colors.green[50] : null,
                  child: CheckboxListTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            delivery.vendorName,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Belum Dituntut',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No. Invois: ${delivery.invoiceNumber ?? delivery.id.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('dd MMM yyyy', 'ms_MY').format(delivery.deliveryDate)} - RM ${delivery.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    value: isSelected,
                    onChanged: (value) => _toggleDeliverySelection(delivery),
                    secondary: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? Colors.green[600] : Colors.grey,
                    ),
                  ),
                );
              }),
            ],
          ),

        // Claimed Deliveries Section
        if (_claimedDeliveries.isNotEmpty) ...[
          if (_availableDeliveries.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Penghantaran Sudah Dituntut (${_claimedDeliveries.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Penghantaran ini sudah dibuat tuntutan dan tidak boleh dipilih lagi',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              ..._claimedDeliveries.map((delivery) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.grey[100],
                  child: ListTile(
                    enabled: false,
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            delivery.vendorName,
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Sudah Dituntut',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No. Invois: ${delivery.invoiceNumber ?? delivery.id.substring(0, 8).toUpperCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('dd MMM yyyy', 'ms_MY').format(delivery.deliveryDate)} - RM ${delivery.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    leading: Icon(
                      Icons.lock,
                      color: Colors.grey[600],
                    ),
                  ),
                );
              }),
            ],
          ),
        ],

        // No deliveries at all
        if (_availableDeliveries.isEmpty && _claimedDeliveries.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 48, color: Colors.orange[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Tiada penghantaran untuk vendor ini',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sila pilih vendor lain atau tunggu penghantaran baru.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        if (_selectedDeliveries.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_selectedDeliveries.length} penghantaran dipilih',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Carry Forward Items Section
        if (_availableCarryForwardItems.isNotEmpty) ...[
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.forward, color: Colors.blue[700], size: 24),
              const SizedBox(width: 8),
              const Text(
                'Item Belum Terjual (C/F) dari Tuntutan Sebelumnya',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Item yang belum terjual dari tuntutan sebelumnya boleh digunakan untuk tuntutan ini',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ..._availableCarryForwardItems.map((item) {
            final isSelected =
                _selectedCarryForwardItems.any((i) => i.id == item.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isSelected ? Colors.blue[50] : null,
              child: CheckboxListTile(
                title: Text(
                  item.displayName,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kuantiti: ${item.quantityAvailable.toStringAsFixed(0)} unit @ RM ${item.unitPrice.toStringAsFixed(2)}',
                    ),
                    if (item.originalClaimNumber != null)
                      Text(
                        'Dari: ${item.originalClaimNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
                value: isSelected,
                onChanged: (value) => _toggleCarryForwardSelection(item),
                secondary: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? Colors.blue[700] : Colors.grey,
                ),
              ),
            );
          }),
          if (_selectedCarryForwardItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_selectedCarryForwardItems.length} item C/F dipilih',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildStep3QuantityUpdate() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Langkah 3: Kemaskini Kuantiti',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kemaskini kuantiti terjual, expired, rosak untuk setiap produk',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Terjual = Dihantar - Expired - Rosak - Belum Terjual (C/F). Kuantiti Terjual akan dikira secara automatik.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _deliveryItems.isEmpty
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Memuatkan item...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _deliveryItems.length,
                    itemBuilder: (context, index) {
                      final item = _deliveryItems[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['productName'] as String,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Dihantar: ${item['quantity'].toStringAsFixed(2)} unit @ RM ${item['unitPrice'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const Divider(height: 24),
                              // Terjual - Auto calculated (read-only display)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color:
                                          AppColors.success.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.shopping_cart,
                                        size: 24, color: AppColors.success),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Terjual (Auto)',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${item['quantitySold'].toStringAsFixed(0)} unit',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildQuantityField(
                                label: 'Expired',
                                value: item['quantityExpired'] as double,
                                icon: Icons.event_busy,
                                color: Colors.orange,
                                onChanged: (value) => _updateItemQuantity(
                                    index, 'quantityExpired', value),
                                max: item['quantity'] as double,
                                itemIndex: index,
                                quantityType: 'quantityExpired',
                              ),
                              const SizedBox(height: 12),
                              _buildQuantityField(
                                label: 'Rosak',
                                value: item['quantityDamaged'] as double,
                                icon: Icons.broken_image,
                                color: Colors.red,
                                onChanged: (value) => _updateItemQuantity(
                                    index, 'quantityDamaged', value),
                                max: item['quantity'] as double,
                                itemIndex: index,
                                quantityType: 'quantityDamaged',
                              ),
                              const SizedBox(height: 12),
                              // Belum Terjual (C/F) - User input with +/- buttons
                              _buildQuantityField(
                                label: 'Belum Terjual (C/F)',
                                value: item['quantityUnsold'] as double,
                                icon: Icons.forward,
                                color: Colors.blue,
                                onChanged: (value) => _updateItemQuantity(
                                    index, 'quantityUnsold', value),
                                max: item['quantity'] as double,
                                itemIndex: index,
                                quantityType: 'quantityUnsold',
                                showTooltip: true,
                                tooltipMessage:
                                    'Carry Forward - Item ini akan dibawa ke tuntutan seterusnya',
                              ),

                              // Carry Forward Status Selection (if unsold > 0)
                              if (((item['quantityUnsold'] as double?) ?? 0.0) >
                                  0)
                                _buildCarryForwardChoices(index, item),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityField({
    required String label,
    required double value,
    required IconData icon,
    required Color color,
    required Function(double) onChanged,
    required double max,
    required int itemIndex,
    required String quantityType,
    bool showTooltip = false,
    String? tooltipMessage,
  }) {
    final controller = TextEditingController(text: value.toStringAsFixed(0));

    return Row(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  if (showTooltip && tooltipMessage != null) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: tooltipMessage,
                      child: Icon(Icons.info_outline, size: 16, color: color),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  // Decrement button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.remove, size: 20),
                      onPressed: () =>
                          _decrementQuantity(itemIndex, quantityType),
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Input field
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: controller,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: false),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          hintText: '0',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                        ),
                        onChanged: (text) {
                          final newValue = double.tryParse(text) ?? 0.0;
                          if (newValue >= 0 && newValue <= max) {
                            onChanged(newValue);
                            controller.text = newValue.toStringAsFixed(0);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Increment button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.add, size: 20, color: color),
                      onPressed: () =>
                          _incrementQuantity(itemIndex, quantityType),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Maks: ${max.toStringAsFixed(0)} unit',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (showTooltip && quantityType == 'quantityUnsold') ...[
                    const SizedBox(width: 8),
                    Text(
                      '• Akan dibawa ke tuntutan seterusnya',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCarryForwardChoices(int itemIndex, Map<String, dynamic> item) {
    final unsoldQty = (item['quantityUnsold'] as double?) ?? 0.0;
    final currentStatus = _cfStatus[itemIndex] ?? 'none';

    return Card(
      margin: const EdgeInsets.only(top: 16),
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Belum Terjual: ${unsoldQty.toStringAsFixed(1)} unit - Apa yang anda ingin buat?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Option 1: Mark as Loss
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color:
                      currentStatus == 'loss' ? Colors.red : Colors.grey[300]!,
                  width: currentStatus == 'loss' ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: RadioListTile<String>(
                title: const Text(
                  '🔴 Rugi (Loss/Waste)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Item ini dianggap hilang, rosak, atau expired - tidak akan dibawa ke minggu depan',
                  style: TextStyle(fontSize: 11),
                ),
                value: 'loss',
                groupValue: currentStatus,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _cfStatus[itemIndex] = value);
                  }
                },
                tileColor: currentStatus == 'loss' ? Colors.red[50] : null,
              ),
            ),
            const SizedBox(height: 8),

            // Option 2: Carry Forward
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: currentStatus == 'carry_forward'
                      ? Colors.blue
                      : Colors.grey[300]!,
                  width: currentStatus == 'carry_forward' ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: RadioListTile<String>(
                title: const Text(
                  '🔵 Bawa ke Minggu Depan (C/F)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Item ini akan dibawa ke tuntutan minggu depan - masih boleh dijual',
                  style: TextStyle(fontSize: 11),
                ),
                value: 'carry_forward',
                groupValue: currentStatus,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _cfStatus[itemIndex] = value);
                  }
                },
                tileColor:
                    currentStatus == 'carry_forward' ? Colors.blue[50] : null,
              ),
            ),
            const SizedBox(height: 8),

            // Status indicator
            if (currentStatus != 'none')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: currentStatus == 'carry_forward'
                      ? Colors.blue[100]
                      : Colors.red[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getCfStatusText(currentStatus),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: currentStatus == 'carry_forward'
                        ? Colors.blue[700]
                        : Colors.red[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getCfStatusText(String status) {
    switch (status) {
      case 'carry_forward':
        return '✅ Akan dibawa ke minggu depan (C/F)';
      case 'loss':
        return '✅ Ditandai sebagai kerugian';
      default:
        return '⚠️ Sila pilih status untuk item yang belum terjual';
    }
  }

  Widget _buildStep4Review() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Langkah 4: Semak Jumlah',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Semak jumlah tuntutan sebelum cipta',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        if (_claimSummary == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Mengira jumlah tuntutan...'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _calculateSummary,
                    child: const Text('Kira Semula'),
                  ),
                ],
              ),
            ),
          )
        else
          _buildDetailedSummary(),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tarikh Tuntutan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _claimDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _claimDate = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat('dd MMMM yyyy', 'ms_MY').format(_claimDate),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nota (Pilihan)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Masukkan nota jika perlu...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedSummary() {
    if (_claimSummary == null) return const SizedBox();

    return Column(
      children: [
        // Header with Edit button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ringkasan Tuntutan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                // Go back to step 3 to edit quantities
                setState(() => _currentStep = 3);
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Summary Card
        ClaimSummaryCard(summary: _claimSummary!),

        const SizedBox(height: 16),

        // Detailed Breakdown
        Card(
          child: ExpansionTile(
            title: const Text(
              'Butiran Komisyen',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Kadar: ${_claimSummary!.commissionRate.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            leading: Icon(Icons.info_outline, color: AppColors.primary),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Jumlah Terjual',
                      'RM ${_claimSummary!.totalSoldValue.toStringAsFixed(2)}',
                      AppColors.success,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Kadar Komisyen',
                      '${_claimSummary!.commissionRate.toStringAsFixed(1)}%',
                      Colors.grey[700]!,
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      'Jumlah Komisyen',
                      '-RM ${_claimSummary!.commissionAmount.toStringAsFixed(2)}',
                      Colors.orange,
                      isBold: true,
                    ),
                    const Divider(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Jumlah Tuntutan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'RM ${_claimSummary!.netAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Item Breakdown
        Card(
          child: ExpansionTile(
            title: const Text(
              'Butiran Item',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${_deliveryItems.length} item (termasuk C/F jika ada)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            leading: Icon(Icons.list, color: AppColors.primary),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._deliveryItems
                        .where((item) => item['isCarryForward'] != true)
                        .map((item) {
                      final sold = item['quantitySold'] as double;
                      final unitPrice = item['unitPrice'] as double;
                      final itemValue = sold * unitPrice;
                      final commission =
                          itemValue * (_claimSummary!.commissionRate / 100);
                      final net = itemValue - commission;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['productName'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${sold.toStringAsFixed(0)} unit × RM ${unitPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  'RM ${itemValue.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Komisyen (${_claimSummary!.commissionRate.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '-RM ${commission.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Jumlah',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'RM ${net.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    if (_deliveryItems.any((i) => i['isCarryForward'] == true)) ...[
                      const Divider(height: 24),
                      Text(
                        'Item Carry Forward',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._deliveryItems
                          .where((item) => item['isCarryForward'] == true)
                          .map((item) {
                        final sold = item['quantitySold'] as double;
                        final unitPrice = item['unitPrice'] as double;
                        final itemValue = sold * unitPrice;
                        final commission =
                            itemValue * (_claimSummary!.commissionRate / 100);
                        final net = itemValue - commission;
                        final unsold = item['quantityUnsold'] as double;
                        final expired = item['quantityExpired'] as double;
                        final damaged = item['quantityDamaged'] as double;
                        final source = item['sourceClaimNumber'] as String?;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item['productName'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'C/F',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (source != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Dari tuntutan: $source',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                '${sold.toStringAsFixed(0)} unit terjual × RM ${unitPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (unsold > 0 || expired > 0 || damaged > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Belum terjual: ${unsold.toStringAsFixed(1)}, Expired: ${expired.toStringAsFixed(1)}, Rosak: ${damaged.toStringAsFixed(1)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Komisyen (${_claimSummary!.commissionRate.toStringAsFixed(1)}%)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    '-RM ${commission.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Jumlah',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'RM ${net.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, Color color,
      {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStep5Summary() {
    if (_createdClaim == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success Header
          Card(
            color: AppColors.success.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 48, color: AppColors.success),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tuntutan Berjaya Dicipta!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No. Tuntutan: ${_createdClaim!.claimNumber}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Invoice Preview
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pratonton Invois',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.fullscreen),
                        onPressed: () => _showFullInvoicePreview(),
                      ),
                    ],
                  ),
                  const Divider(),

                  // Business Info
                  if (_businessProfile != null) ...[
                    Text(
                      _businessProfile!.businessName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_businessProfile!.address != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _businessProfile!.address!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                    if (_businessProfile!.phone != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Tel: ${_businessProfile!.phone}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // Vendor Info
                  Text(
                    'Kepada:',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedVendor?.name ??
                        _createdClaim!.vendorName ??
                        'Vendor',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_selectedVendor?.phone != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tel: ${_selectedVendor!.phone}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],

                  const Divider(height: 32),

                  // Summary
                  _buildInvoiceSummaryRow('Jumlah Terjual',
                      _createdClaim!.grossAmount, AppColors.success),
                  const SizedBox(height: 8),
                  _buildInvoiceSummaryRow(
                    'Komisyen (${_createdClaim!.commissionRate.toStringAsFixed(1)}%)',
                    _createdClaim!.commissionAmount,
                    Colors.orange,
                    isSubtraction: true,
                  ),
                  const Divider(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Jumlah Tuntutan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'RM ${_createdClaim!.netAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _generateAndSavePDF,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Simpan PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareViaWhatsApp,
                  icon: const Icon(Icons.share),
                  label: const Text('Hantar WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _printPDF,
                  icon: const Icon(Icons.print),
                  label: const Text('Cetak'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, _createdClaim);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Selesai'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceSummaryRow(String label, double amount, Color color,
      {bool isSubtraction = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        Text(
          '${isSubtraction ? "-" : ""}RM ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _generateAndSavePDF() async {
    if (_createdClaim == null || _selectedVendor == null) return;

    try {
      // Get claim items
      final claimWithItems = await _claimsRepo.getClaimById(_createdClaim!.id);

      final items = (claimWithItems.items ?? []).map((item) {
        return ClaimItem(
          productName: item.productName ?? 'Unknown Product',
          quantitySold: item.quantitySold,
          unitPrice: item.unitPrice,
          grossAmount: item.grossAmount,
          commissionAmount: item.commissionAmount,
          netAmount: item.netAmount,
        );
      }).toList();

      final pdfBytes = await PDFGenerator.generateClaimInvoice(
        claimNumber: _createdClaim!.claimNumber,
        vendorName: _selectedVendor!.name,
        vendorPhone: _selectedVendor!.phone ?? '',
        claimDate: _createdClaim!.claimDate,
        grossAmount: _createdClaim!.grossAmount,
        commissionRate: _createdClaim!.commissionRate,
        commissionAmount: _createdClaim!.commissionAmount,
        netAmount: _createdClaim!.netAmount,
        paidAmount: _createdClaim!.paidAmount,
        balanceAmount: _createdClaim!.balanceAmount,
        items: items,
        notes: _createdClaim!.notes,
        businessName: _businessProfile?.businessName,
        businessAddress: _businessProfile?.address,
        businessPhone: _businessProfile?.phone,
      );

      // Save to file only (no auto-share)
      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/Claim_${_createdClaim!.claimNumber}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF disimpan: $filePath'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Ralat menjana PDF: $e');
      }
    }
  }

  Future<void> _printPDF() async {
    if (_createdClaim == null || _selectedVendor == null) return;

    try {
      final claimWithItems = await _claimsRepo.getClaimById(_createdClaim!.id);

      final items = (claimWithItems.items ?? []).map((item) {
        return ClaimItem(
          productName: item.productName ?? 'Unknown Product',
          quantitySold: item.quantitySold,
          unitPrice: item.unitPrice,
          grossAmount: item.grossAmount,
          commissionAmount: item.commissionAmount,
          netAmount: item.netAmount,
        );
      }).toList();

      final pdfBytes = await PDFGenerator.generateClaimInvoice(
        claimNumber: _createdClaim!.claimNumber,
        vendorName: _selectedVendor!.name,
        vendorPhone: _selectedVendor!.phone ?? '',
        claimDate: _createdClaim!.claimDate,
        grossAmount: _createdClaim!.grossAmount,
        commissionRate: _createdClaim!.commissionRate,
        commissionAmount: _createdClaim!.commissionAmount,
        netAmount: _createdClaim!.netAmount,
        paidAmount: _createdClaim!.paidAmount,
        balanceAmount: _createdClaim!.balanceAmount,
        items: items,
        notes: _createdClaim!.notes,
        businessName: _businessProfile?.businessName,
        businessAddress: _businessProfile?.address,
        businessPhone: _businessProfile?.phone,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
      );
    } catch (e) {
      if (mounted) {
        _showError('Ralat mencetak: $e');
      }
    }
  }

  Future<void> _shareViaWhatsApp() async {
    if (_createdClaim == null || _selectedVendor == null) return;

    try {
      // Generate PDF first
      final claimWithItems = await _claimsRepo.getClaimById(_createdClaim!.id);

      final items = (claimWithItems.items ?? []).map((item) {
        return ClaimItem(
          productName: item.productName ?? 'Unknown Product',
          quantitySold: item.quantitySold,
          unitPrice: item.unitPrice,
          grossAmount: item.grossAmount,
          commissionAmount: item.commissionAmount,
          netAmount: item.netAmount,
        );
      }).toList();

      final pdfBytes = await PDFGenerator.generateClaimInvoice(
        claimNumber: _createdClaim!.claimNumber,
        vendorName: _selectedVendor!.name,
        vendorPhone: _selectedVendor!.phone ?? '',
        claimDate: _createdClaim!.claimDate,
        grossAmount: _createdClaim!.grossAmount,
        commissionRate: _createdClaim!.commissionRate,
        commissionAmount: _createdClaim!.commissionAmount,
        netAmount: _createdClaim!.netAmount,
        paidAmount: _createdClaim!.paidAmount,
        balanceAmount: _createdClaim!.balanceAmount,
        items: items,
        notes: _createdClaim!.notes,
        businessName: _businessProfile?.businessName,
        businessAddress: _businessProfile?.address,
        businessPhone: _businessProfile?.phone,
      );

      // Save to temp file
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/Claim_${_createdClaim!.claimNumber}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      // Get vendor phone
      final phone =
          _selectedVendor!.phone?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
      if (phone.isEmpty) {
        _showError('Nombor telefon vendor tidak tersedia');
        return;
      }

      // Create WhatsApp message
      final message = '*Invois Tuntutan - ${_createdClaim!.claimNumber}*\n\n' +
          'Kepada: *${_selectedVendor!.name}*\n' +
          'Tarikh: ${DateFormat('dd MMMM yyyy', 'ms_MY').format(_createdClaim!.claimDate)}\n' +
          'Jumlah Tuntutan: *RM ${_createdClaim!.netAmount.toStringAsFixed(2)}*\n\n' +
          'Sila lihat lampiran PDF untuk butiran lengkap.';

      // Share with WhatsApp
      await Share.shareXFiles(
        [XFile(filePath)],
        text: message,
        subject: 'Invois Tuntutan ${_createdClaim!.claimNumber}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF sedia untuk dihantar melalui WhatsApp'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Ralat menghantar: $e');
      }
    }
  }

  void _showFullInvoicePreview() async {
    if (_createdClaim == null || _selectedVendor == null) return;

    try {
      final claimWithItems = await _claimsRepo.getClaimById(_createdClaim!.id);

      final items = (claimWithItems.items ?? []).map((item) {
        return ClaimItem(
          productName: item.productName ?? 'Unknown Product',
          quantitySold: item.quantitySold,
          unitPrice: item.unitPrice,
          grossAmount: item.grossAmount,
          commissionAmount: item.commissionAmount,
          netAmount: item.netAmount,
        );
      }).toList();

      final pdfBytes = await PDFGenerator.generateClaimInvoice(
        claimNumber: _createdClaim!.claimNumber,
        vendorName: _selectedVendor!.name,
        vendorPhone: _selectedVendor!.phone ?? '',
        claimDate: _createdClaim!.claimDate,
        grossAmount: _createdClaim!.grossAmount,
        commissionRate: _createdClaim!.commissionRate,
        commissionAmount: _createdClaim!.commissionAmount,
        netAmount: _createdClaim!.netAmount,
        paidAmount: _createdClaim!.paidAmount,
        balanceAmount: _createdClaim!.balanceAmount,
        items: items,
        notes: _createdClaim!.notes,
        businessName: _businessProfile?.businessName,
        businessAddress: _businessProfile?.address,
        businessPhone: _businessProfile?.phone,
      );

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: SizedBox(
              width: 800,
              height: 600,
              child: PdfPreview(
                canChangeOrientation: false,
                canChangePageFormat: false,
                build: (format) async => pdfBytes,
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        _showError('Ralat pratonton: $e');
      }
    }
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 1)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Kembali'),
              ),
            ),
          if (_currentStep > 1 && _currentStep < 4) const SizedBox(width: 16),
          if (_currentStep < 5)
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _currentStep == 1
                    ? (_selectedVendorId != null ? _nextStep : null)
                    : _currentStep == 2
                        ? (_selectedDeliveries.isNotEmpty ? _nextStep : null)
                        : _currentStep == 3
                            ? (_isSavingQuantities ? null : _saveQuantities)
                            : _currentStep == 4
                                ? (_isCreating ? null : _validateAndCreate)
                                : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: (_isCreating || _isSavingQuantities)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _currentStep == 3
                            ? 'Simpan & Seterusnya'
                            : _currentStep == 4
                                ? 'Cipta Tuntutan'
                                : 'Seterusnya',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
