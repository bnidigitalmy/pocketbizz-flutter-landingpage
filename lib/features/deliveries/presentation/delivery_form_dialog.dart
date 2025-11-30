import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/deliveries_repository_supabase.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/models/delivery.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/product.dart';

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

  String? _selectedVendorId;
  DateTime _deliveryDate = DateTime.now();
  String _status = 'delivered';
  final List<DeliveryItemForm> _items = [];
  double _totalAmount = 0.0;
  bool _isSubmitting = false;
  bool _isLoadingLastDelivery = false;
  Map<String, dynamic>? _vendorCommission;

  @override
  void initState() {
    super.initState();
    _loadLastVendor();
    _items.add(DeliveryItemForm());
  }

  Future<void> _loadLastVendor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastVendorId = prefs.getString('pocketbizz_last_delivery_vendor');
      if (lastVendorId != null && mounted) {
        setState(() => _selectedVendorId = lastVendorId);
        _onVendorChanged(lastVendorId);
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
      setState(() => _vendorCommission = commission);
      
      // Recalculate prices for existing items
      _recalculateItemPrices();
    } catch (e) {
      debugPrint('Error loading commission: $e');
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

  void _addItem() {
    setState(() {
      _items.add(DeliveryItemForm());
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index);
        _calculateTotal();
      });
    }
  }

  void _onProductChanged(int index, String productId) {
    final product = widget.products.firstWhere((p) => p.id == productId);
    final retailPrice = product.salePrice.toStringAsFixed(2);
    final vendorPrice = _calculateVendorPrice(retailPrice);

    setState(() {
      _items[index].productId = productId;
      _items[index].productName = product.name;
      _items[index].retailPrice = retailPrice;
      _items[index].unitPrice = vendorPrice;
      _calculateTotal();
    });
  }

  void _onQuantityChanged(int index, String value) {
    setState(() {
      _items[index].quantity = double.tryParse(value) ?? 0.0;
      _calculateTotal();
    });
  }

  void _onPriceChanged(int index, String value) {
    setState(() {
      _items[index].unitPrice = value;
      _calculateTotal();
    });
  }

  String _calculateVendorPrice(String retailPrice) {
    final price = double.tryParse(retailPrice) ?? 0.0;
    if (_vendorCommission == null || price == 0) return retailPrice;

    if (_vendorCommission!['commissionType'] == 'percentage') {
      final commissionPercent = double.tryParse(_vendorCommission!['percentage'] ?? '0') ?? 0.0;
      final vendorPrice = price - (price * commissionPercent / 100);
      return vendorPrice.toStringAsFixed(2);
    }

    return retailPrice;
  }

  void _recalculateItemPrices() {
    for (var item in _items) {
      if (item.retailPrice != null && item.retailPrice!.isNotEmpty) {
        item.unitPrice = _calculateVendorPrice(item.retailPrice!);
      }
    }
    _calculateTotal();
  }

  void _calculateTotal() {
    final total = _items.fold<double>(
      0.0,
      (sum, item) {
        final price = double.tryParse(item.unitPrice) ?? 0.0;
        return sum + (price * item.quantity);
      },
    );
    setState(() => _totalAmount = total);
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

    if (_items.isEmpty || _items.any((item) => item.productId.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila tambah sekurang-kurangnya satu item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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

      if (mounted) {
        widget.onSuccess(delivery);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
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
    return AlertDialog(
      title: const Text('Rekod Penghantaran Baru'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan maklumat penghantaran',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              // Vendor dropdown
              DropdownButtonFormField<String>(
                value: _selectedVendorId,
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoadingLastDelivery ? null : _loadLastDelivery,
                    icon: _isLoadingLastDelivery
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.copy, size: 16),
                    label: Text(_isLoadingLastDelivery ? 'Memuat...' : 'Ulang Penghantaran Lepas'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Delivery date
              TextFormField(
                initialValue: DateFormat('yyyy-MM-dd').format(_deliveryDate),
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
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    setState(() => _deliveryDate = date);
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
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addItem,
                    tooltip: 'Tambah Item',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _buildItemCard(index, item);
              }),
              const SizedBox(height: 16),
              // Total amount
              TextFormField(
                initialValue: _totalAmount.toStringAsFixed(2),
                decoration: const InputDecoration(
                  labelText: 'Jumlah (RM)',
                  border: OutlineInputBorder(),
                  prefixText: 'RM ',
                ),
                readOnly: true,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () {
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Product dropdown
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: item.productId.isEmpty ? null : item.productId,
                    decoration: const InputDecoration(
                      labelText: 'Produk',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: widget.products.map((product) {
                      return DropdownMenuItem(
                        value: product.id,
                        child: Text(product.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _onProductChanged(index, value);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Pilih produk';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Quantity
                Expanded(
                  child: TextFormField(
                    initialValue: item.quantity.toStringAsFixed(1),
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => _onQuantityChanged(index, value),
                    validator: (value) {
                      final qty = double.tryParse(value ?? '0') ?? 0;
                      if (qty <= 0) {
                        return 'Qty > 0';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Price
                Expanded(
                  child: TextFormField(
                    initialValue: item.unitPrice,
                    decoration: const InputDecoration(
                      labelText: 'Harga',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => _onPriceChanged(index, value),
                    validator: (value) {
                      final price = double.tryParse(value ?? '0') ?? 0;
                      if (price < 0) {
                        return 'Harga >= 0';
                      }
                      return null;
                    },
                  ),
                ),
                // Remove button
                if (_items.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeItem(index),
                    tooltip: 'Padam',
                  ),
              ],
            ),
            // Rejection section (collapsible)
            ExpansionTile(
              title: const Text(
                'Rekod Tolakan (Optional)',
                style: TextStyle(fontSize: 12),
              ),
              children: [
                TextFormField(
                  initialValue: item.rejectedQty.toStringAsFixed(1),
                  decoration: const InputDecoration(
                    labelText: 'Kuantiti Ditolak',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    setState(() {
                      item.rejectedQty = double.tryParse(value) ?? 0.0;
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: item.rejectionReason ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Sebab Tolakan',
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'Cth: Expired, Rosak',
                  ),
                  maxLines: 2,
                  onChanged: (value) {
                    setState(() {
                      item.rejectionReason = value;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
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

