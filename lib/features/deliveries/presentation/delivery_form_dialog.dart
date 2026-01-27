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
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/deliveries_repository_supabase.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/repositories/production_repository_supabase.dart';
import '../../../data/models/delivery.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/product.dart';
import '../../../core/utils/vendor_price_calculator.dart';
import '../../../core/utils/business_profile_error_handler.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../subscription/widgets/subscription_guard.dart';
import '../../onboarding/services/onboarding_service.dart';
import '../../../shared/widgets/multi_select_product_modal.dart';

/// Delivery Form Dialog
/// Handles creating new deliveries with items
class DeliveryFormDialog extends StatefulWidget {
  final List<Vendor> vendors;
  final List<Product> products;
  final DeliveriesRepositorySupabase deliveriesRepo;
  final Function(Delivery) onSuccess;
  final VoidCallback onCancel;

  const DeliveryFormDialog({
    super.key,
    required this.vendors,
    required this.products,
    required this.deliveriesRepo,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<DeliveryFormDialog> createState() => _DeliveryFormDialogState();
}

class _DeliveryFormDialogState extends State<DeliveryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _totalAmountController = TextEditingController();
  final _deliveryDateController = TextEditingController();
  final _productionRepo = ProductionRepository(supabase);

  String? _selectedVendorId;
  DateTime _deliveryDate = DateTime.now();
  String _status = 'delivered';
  final List<DeliveryItemForm> _items = [];
  double _totalAmount = 0.0;
  bool _isSubmitting = false;
  bool _isLoadingLastDelivery = false;
  Map<String, dynamic>? _vendorCommission;
  final Map<String, double> _productStockCache = {};

  @override
  void initState() {
    super.initState();
    _deliveryDateController.text = DateFormat('yyyy-MM-dd').format(_deliveryDate);
    _loadLastVendor();
    _totalAmountController.text = '0.00';
    _loadProductStock();
  }

  @override
  void dispose() {
    _deliveryDateController.dispose();
    _totalAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadProductStock() async {
    // Load stock availability for all products
    for (final product in widget.products) {
      try {
        final availableStock = await _productionRepo.getTotalRemainingForProduct(product.id);
        setState(() {
          _productStockCache[product.id] = availableStock;
        });
      } catch (e) {
        debugPrint('Error loading stock for ${product.id}: $e');
        setState(() {
          _productStockCache[product.id] = 0.0;
        });
      }
    }
  }

  Future<void> _loadLastVendor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastVendorId = prefs.getString('pocketbizz_last_delivery_vendor');
      if (lastVendorId != null && mounted) {
        // Only set vendor if it exists in the vendors list
        final vendorExists = widget.vendors.any((v) => v.id == lastVendorId);
        if (vendorExists) {
          setState(() => _selectedVendorId = lastVendorId);
          _onVendorChanged(lastVendorId);
        } else {
          // Clear invalid vendor ID from preferences
          await prefs.remove('pocketbizz_last_delivery_vendor');
        }
      }
    } catch (e) {
      debugPrint('Error loading last vendor: $e');
    }
  }

  Future<void> _onVendorChanged(String vendorId) async {
    setState(() {
      _selectedVendorId = vendorId;
    });

    // Load vendor commission
    try {
      final commission = await widget.deliveriesRepo.getVendorCommission(vendorId);
      debugPrint('📊 Vendor commission loaded: $commission');
      
      // Check if commission is valid
      if (commission != null) {
        final commissionType = commission['commissionType'] as String? ?? 'percentage';
        final commissionRate = double.tryParse(commission['percentage'] ?? '0') ?? 0.0;
        
        if (commissionType == 'percentage' && commissionRate <= 0) {
          debugPrint('⚠️ WARNING: Vendor has no commission setup (rate: $commissionRate). Commission will NOT be deducted!');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '⚠️ Vendor ini tidak ada tetapan komisyen. Sila setup komisyen vendor sebelum membuat penghantaran.',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
      
      setState(() {
        _vendorCommission = commission;
      });
      
      // Recalculate prices for existing items
      if (_items.isNotEmpty) {
        debugPrint('🔄 Recalculating prices for ${_items.length} items...');
        await _recalculateItemPrices();
      }
    } catch (e) {
      debugPrint('❌ Error loading commission: $e');
      setState(() {
        _vendorCommission = null;
      });
    }
  }

  Future<void> _loadLastDelivery() async {
    if (_selectedVendorId == null) return;

    setState(() => _isLoadingLastDelivery = true);
    try {
      final lastDelivery = await widget.deliveriesRepo.getLastDeliveryForVendor(_selectedVendorId!);
      
      if (lastDelivery != null && mounted) {
        setState(() {
          _items.clear();
          _items.addAll(lastDelivery.items.map((item) => DeliveryItemForm(
            productId: item.productId,
            productName: item.productName,
            quantity: item.quantity,
            unitPrice: item.unitPrice.toStringAsFixed(2),
            retailPrice: item.retailPrice?.toStringAsFixed(2) ?? '0',
          )));
          _calculateTotal();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Penghantaran lepas telah disalin. Sila semak dan kemaskini tarikh.'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tiada rekod penghantaran lepas untuk vendor ini'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLastDelivery = false);
      }
    }
  }

  void _showProductSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Pilih Produk',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Product List
              Expanded(
                child: widget.products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tiada produk tersedia',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: widget.products.length,
                        itemBuilder: (context, index) {
                          final product = widget.products[index];
                          final hasPrice = product.salePrice > 0;
                          final stock = _productStockCache[product.id] ?? 0.0;
                          final isAvailable = stock > 0;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: hasPrice
                                    ? Colors.grey[200]!
                                    : Colors.orange[200]!,
                                width: 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: hasPrice
                                  ? () {
                                      Navigator.pop(context);
                                      _addProduct(product);
                                    }
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
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
                                                hasPrice
                                                    ? Icons.inventory_2_outlined
                                                    : Icons.warning_amber_rounded,
                                                color: hasPrice
                                                    ? Colors.grey[400]
                                                    : Colors.orange[400],
                                                size: 28,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Product Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[50],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  'RM${product.salePrice.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: Colors.blue[700],
                                                  ),
                                                ),
                                              ),
                                              // Stock Badge
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isAvailable
                                                      ? Colors.green[50]
                                                      : Colors.red[50],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isAvailable
                                                          ? Icons.inventory_2
                                                          : Icons.inventory_2_outlined,
                                                      size: 14,
                                                      color: isAvailable
                                                          ? Colors.green[700]
                                                          : Colors.red[700],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Stok: ${stock.toStringAsFixed(1)}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                        color: isAvailable
                                                            ? Colors.green[700]
                                                            : Colors.red[700],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (!hasPrice) ...[
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange[50],
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  child: const Text(
                                                    'Tiada harga',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: Colors.orange,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Add Icon
                                    if (hasPrice)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.add_circle,
                                          color: AppColors.primary,
                                          size: 28,
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.block,
                                        color: Colors.grey,
                                        size: 28,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show multi-select product modal for bulk adding products
  void _showMultiSelectProductModal() {
    MultiSelectProductModal.show(
      context: context,
      products: widget.products,
      productStockCache: _productStockCache,
      onConfirm: (selectedItems) async {
        // Process each selected product
        for (final selectedItem in selectedItems) {
          final product = selectedItem.product;
          final qty = selectedItem.quantity;
          final stock = _productStockCache[product.id] ?? 0.0;

          // Skip if invalid
          if (product.salePrice <= 0 || qty <= 0 || qty > stock) {
            continue;
          }

          final retailPrice = product.salePrice.toStringAsFixed(2);
          final vendorPrice = await _calculateVendorPrice(retailPrice);

          setState(() {
            _items.add(DeliveryItemForm(
              productId: product.id,
              productName: product.name,
              quantity: qty,
              unitPrice: vendorPrice,
              retailPrice: retailPrice,
            ));
          });
        }

        // Recalculate total after all items added
        setState(() {
          _calculateTotal();
        });

        // Show success message
        if (selectedItems.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${selectedItems.length} produk telah ditambah'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  void _addProduct(Product product) {
    // Check if product has valid sale price
    if (product.salePrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Produk "${product.name}" tidak ada harga jualan. Sila update harga produk dahulu.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final availableStock = _productStockCache[product.id] ?? 0.0;

    showDialog(
      context: context,
      builder: (context) {
        final qtyController = TextEditingController(text: '1');
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final retailPrice = product.salePrice.toStringAsFixed(2);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(Icons.local_shipping, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_money, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Harga Runcit: RM$retailPrice',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stock Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: availableStock > 0 ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: availableStock > 0 ? Colors.green[300]! : Colors.red[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          availableStock > 0 ? Icons.check_circle : Icons.warning,
                          color: availableStock > 0 ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Stok Tersedia: ${availableStock.toStringAsFixed(1)} unit',
                            style: TextStyle(
                              color: availableStock > 0 ? Colors.green[700] : Colors.red[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Quantity Input
                  TextField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Kuantiti',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.numbers),
                      helperText: availableStock > 0
                          ? 'Maksimum: ${availableStock.toStringAsFixed(1)} unit'
                          : 'Tiada stok tersedia',
                      errorText: () {
                        final qty = double.tryParse(qtyController.text) ?? 0;
                        if (qty <= 0) {
                          return 'Kuantiti mesti lebih daripada 0';
                        }
                        if (qty > availableStock) {
                          return 'Kuantiti melebihi stok tersedia';
                        }
                        return null;
                      }(),
                    ),
                    onChanged: (value) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: availableStock > 0 ? () async {
                    final qty = double.tryParse(qtyController.text) ?? 0;

                    if (qty <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kuantiti mesti lebih daripada 0'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (qty > availableStock) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Kuantiti melebihi stok tersedia (${availableStock.toStringAsFixed(1)} unit)',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final vendorPrice = await _calculateVendorPrice(retailPrice);

                    setState(() {
                      _items.add(DeliveryItemForm(
                        productId: product.id,
                        productName: product.name,
                        quantity: qty,
                        unitPrice: vendorPrice,
                        retailPrice: retailPrice,
                      ));
                      _calculateTotal();
                    });
                    Navigator.pop(context);
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: availableStock > 0 ? AppColors.primary : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Tambah'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index);
        _calculateTotal();
      });
    }
  }


  // Price is auto-calculated, no manual editing needed

  Future<String> _calculateVendorPrice(String retailPrice) async {
    final price = double.tryParse(retailPrice) ?? 0.0;
    
    // If price is 0 or invalid, return as is
    if (price <= 0) {
      return retailPrice;
    }
    
    // If no vendor selected or no commission info, return retail price
    if (_selectedVendorId == null || _vendorCommission == null) {
      debugPrint('⚠️ Cannot calculate vendor price: vendor=${_selectedVendorId}, commission=${_vendorCommission}');
      return retailPrice;
    }

    final commissionType = _vendorCommission!['commissionType'] as String? ?? 'percentage';
    final commissionRate = double.tryParse(_vendorCommission!['percentage'] ?? '0') ?? 0.0;

    debugPrint('💰 Calculating vendor price: retail=$price, type=$commissionType, rate=$commissionRate');

    try {
      final vendorPrice = await VendorPriceCalculator.calculateVendorPrice(
        vendorId: _selectedVendorId!,
        retailPrice: price,
        commissionType: commissionType,
        commissionRate: commissionRate,
      );

      debugPrint('✅ Vendor price calculated: $retailPrice -> $vendorPrice (commission: ${price - vendorPrice})');
      return vendorPrice.toStringAsFixed(2);
    } catch (e) {
      debugPrint('❌ Error calculating vendor price: $e');
      // Return retail price if calculation fails
      return retailPrice;
    }
  }

  Future<void> _recalculateItemPrices() async {
    if (_selectedVendorId == null || _vendorCommission == null) {
      debugPrint('⚠️ Cannot recalculate: vendor or commission not loaded');
      return;
    }

    for (var item in _items) {
      if (item.retailPrice != null && item.retailPrice!.isNotEmpty) {
        final oldPrice = item.unitPrice;
        item.unitPrice = await _calculateVendorPrice(item.retailPrice!);
        debugPrint('📝 Item "${item.productName}": ${item.retailPrice} -> ${item.unitPrice} (was: $oldPrice)');
      }
    }
    setState(() {
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    final total = _items.fold<double>(
      0.0,
      (sum, item) {
        final price = double.tryParse(item.unitPrice) ?? 0.0;
        return sum + (price * item.quantity);
      },
    );
    setState(() {
      _totalAmount = total;
      _totalAmountController.text = total.toStringAsFixed(2);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila pilih vendor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila tambah sekurang-kurangnya satu item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate that all items have valid prices
    final itemsWithInvalidPrice = _items.where((item) {
      final price = double.tryParse(item.unitPrice) ?? 0.0;
      return price <= 0;
    }).toList();

    if (itemsWithInvalidPrice.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ ${itemsWithInvalidPrice.length} produk tidak ada harga yang sah. Sila pastikan semua produk ada harga jualan.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Validate stock availability for all items
    for (final item in _items) {
      final productId = item.productId;
      final qty = item.quantity;
      final productName = item.productName;
      final availableStock = _productStockCache[productId] ?? 0.0;

      if (qty > availableStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Stok tidak mencukupi untuk "$productName": '
              'Tersedia: ${availableStock.toStringAsFixed(1)}, '
              'Diperlukan: ${qty.toStringAsFixed(1)}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
    }

    // PHASE: Subscriber Expired System - Protect create action
    await requirePro(context, 'Tambah Penghantaran', () async {
      setState(() => _isSubmitting = true);

      try {
        // Save last vendor
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pocketbizz_last_delivery_vendor', _selectedVendorId!);

        // Prepare items data
        final itemsData = _items.map((item) {
          return {
            'product_id': item.productId,
            'product_name': item.productName,
            'quantity': item.quantity,
            'unit_price': double.tryParse(item.unitPrice) ?? 0.0,
            'retail_price': double.tryParse(item.retailPrice ?? '0') ?? 0.0,
            'rejected_qty': item.rejectedQty,
            'rejection_reason': item.rejectionReason,
          };
        }).toList();

        // Create delivery
        final delivery = await widget.deliveriesRepo.createDelivery(
          vendorId: _selectedVendorId!,
          deliveryDate: _deliveryDate,
          status: _status,
          items: itemsData,
        );

        // Update onboarding progress
        OnboardingService().markDeliveryRecorded();

        if (mounted) {
          widget.onSuccess(delivery);
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          
          // Handle subscription enforcement errors
          final subscriptionHandled = await SubscriptionEnforcement.maybePromptUpgrade(
            context,
            action: 'Tambah Penghantaran',
            error: e,
          );
          if (subscriptionHandled) return;
          
          // Handle duplicate invoice key error (profile not setup)
          final duplicateKeyHandled = await BusinessProfileErrorHandler.handleDuplicateKeyError(
            context: context,
            error: e,
            actionName: 'Tambah Penghantaran',
          );
          if (duplicateKeyHandled) return;
          
          // Generic error message
          String errorMessage = 'Ralat mencipta penghantaran';
          final errorStr = e.toString();
          if (errorStr.contains('stock') || errorStr.contains('insufficient')) {
            errorMessage = 'Stok tidak mencukupi untuk penghantaran ini.';
          } else if (errorStr.contains('vendor')) {
            errorMessage = 'Vendor tidak dijumpai atau tidak sah.';
          } else if (errorStr.contains('product')) {
            errorMessage = 'Produk tidak dijumpai atau tidak sah.';
          } else {
            final parts = errorStr.split(':');
            if (parts.length > 1) {
              errorMessage = parts.last.trim();
            }
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Rekod Penghantaran Baru'),
          SizedBox(height: 4),
          Text(
            'Lengkapkan vendor, tarikh dan item. Harga vendor auto ikut komisen.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vendor dropdown
                DropdownButtonFormField<String>(
                  value: _selectedVendorId != null && 
                         widget.vendors.any((v) => v.id == _selectedVendorId)
                      ? _selectedVendorId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Vendor *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                  ),
                  items: widget.vendors.map((vendor) {
                    return DropdownMenuItem(
                      value: vendor.id,
                      child: Text(vendor.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _onVendorChanged(value);
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Sila pilih vendor';
                    }
                    return null;
                  },
                ),
                // Repeat last delivery button
                if (_selectedVendorId != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Harga vendor auto dari komisen. Boleh ulang penghantaran lepas.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _isLoadingLastDelivery ? null : _loadLastDelivery,
                        icon: _isLoadingLastDelivery
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.copy, size: 16),
                        label: Text(_isLoadingLastDelivery ? 'Memuat...' : 'Ulang'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                // Delivery date
                TextFormField(
                  controller: _deliveryDateController,
                  decoration: const InputDecoration(
                    labelText: 'Tarikh Penghantaran *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _deliveryDate,
                      firstDate: DateTime(2020, 1, 1), // Allow dates from 2020 onwards
                      lastDate: DateTime.now().add(const Duration(days: 1)), // Allow today and past dates
                    );
                    if (date != null) {
                      setState(() {
                        _deliveryDate = date;
                        _deliveryDateController.text = DateFormat('yyyy-MM-dd').format(date);
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Items section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Item Dihantar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showMultiSelectProductModal,
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Produk'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_items.isEmpty)
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey[200]!,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 48.0,
                          horizontal: 32.0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.local_shipping_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Tiada item lagi',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Klik "Tambah Produk" untuk menambah item',
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
                  )
                else
                  ..._items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return _buildItemCard(index, item);
                  }),
                const SizedBox(height: 16),
                // Total amount
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Jumlah (RM)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'RM ${_totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  widget.onCancel();
                  Navigator.pop(context);
                },
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Simpan Penghantaran'),
        ),
      ],
    );
  }

  Widget _buildItemCard(int index, DeliveryItemForm item) {
    final price = double.tryParse(item.unitPrice) ?? 0.0;
    final itemTotal = price * item.quantity;
    
    // Find product to get image
    final product = widget.products.firstWhere(
      (p) => p.id == item.productId,
      orElse: () => widget.products.first,
    );

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: Colors.grey,
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
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.grey,
                            size: 28,
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item.quantity.toStringAsFixed(1)} × RM${item.unitPrice}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (item.retailPrice != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Runcit: RM${item.retailPrice}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Amount & Actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'RM${itemTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit quantity button
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.blue,
                              size: 18,
                            ),
                          ),
                          onPressed: () => _editItemQuantity(index, item),
                          tooltip: 'Edit kuantiti',
                        ),
                        // Remove button
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                          ),
                          onPressed: () => _removeItem(index),
                          tooltip: 'Padam item',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            // Rejection section (collapsible)
            if (item.rejectedQty > 0 || item.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.rejectedQty > 0)
                            Text(
                              'Tolakan: ${item.rejectedQty.toStringAsFixed(1)} unit',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          if (item.rejectionReason != null && item.rejectionReason!.isNotEmpty)
                            Text(
                              'Sebab: ${item.rejectionReason}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange[700],
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _editRejection(index, item),
                      child: const Text('Edit', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _editRejection(index, item),
                icon: const Icon(Icons.warning_amber_rounded, size: 16),
                label: const Text('Rekod Tolakan (Opsyenal)', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange[700],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _editItemQuantity(int index, DeliveryItemForm item) {
    final qtyController = TextEditingController(text: item.quantity.toStringAsFixed(1));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Kuantiti'),
        content: TextField(
          controller: qtyController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Kuantiti',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(qtyController.text) ?? 0.0;
              if (qty > 0) {
                setState(() {
                  _items[index].quantity = qty;
                  _calculateTotal();
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _editRejection(int index, DeliveryItemForm item) {
    final rejectedQtyController = TextEditingController(text: item.rejectedQty.toStringAsFixed(1));
    final reasonController = TextEditingController(text: item.rejectionReason ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rekod Tolakan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rejectedQtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Kuantiti Tolak',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.remove_circle_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Sebab Tolakan',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description_outlined),
                hintText: 'Cth: Expired, Rosak, Kerosakan',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _items[index].rejectedQty = double.tryParse(rejectedQtyController.text) ?? 0.0;
                _items[index].rejectionReason = reasonController.text.trim().isEmpty ? null : reasonController.text.trim();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

/// Delivery Item Form Model
class DeliveryItemForm {
  String productId;
  String productName;
  double quantity;
  String unitPrice;
  String? retailPrice;
  double rejectedQty;
  String? rejectionReason;

  DeliveryItemForm({
    this.productId = '',
    this.productName = '',
    this.quantity = 1.0,
    this.unitPrice = '0',
    this.retailPrice,
    this.rejectedQty = 0.0,
    this.rejectionReason,
  });
}

