import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/business_profile_error_handler.dart';
import '../../../data/repositories/bookings_repository_supabase.dart';
import '../../../data/repositories/products_repository_supabase.dart';
import '../../../data/models/product.dart';
import '../../subscription/widgets/subscription_guard.dart';
import '../../../shared/widgets/multi_select_product_modal.dart';

/// Enhanced Create Booking Page
/// Full-featured with discount, deposit, and better UX
class CreateBookingPageEnhanced extends StatefulWidget {
  const CreateBookingPageEnhanced({super.key});

  @override
  State<CreateBookingPageEnhanced> createState() => _CreateBookingPageEnhancedState();
}

class _CreateBookingPageEnhancedState extends State<CreateBookingPageEnhanced> {
  final _formKey = GlobalKey<FormState>();
  final _bookingsRepo = BookingsRepositorySupabase();
  final _productsRepo = ProductsRepositorySupabase();

  // Controllers
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _eventDateController = TextEditingController();
  final _deliveryDateController = TextEditingController();
  final _deliveryTimeController = TextEditingController();
  final _deliveryLocationController = TextEditingController();
  final _notesController = TextEditingController();
  final _depositAmountController = TextEditingController();
  final _discountValueController = TextEditingController();

  bool _loading = false;
  String? _selectedEventType;
  String _discountType = 'percentage'; // 'percentage' or 'fixed'

  final List<Map<String, dynamic>> _selectedItems = [];
  List<Product> _availableProducts = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _eventDateController.dispose();
    _deliveryDateController.dispose();
    _deliveryTimeController.dispose();
    _deliveryLocationController.dispose();
    _notesController.dispose();
    _depositAmountController.dispose();
    _discountValueController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _productsRepo.listProducts();
      setState(() => _availableProducts = products);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  // Calculate totals
  double get _itemsTotal {
    return _selectedItems.fold<double>(
      0.0,
      (sum, item) => sum + (item['quantity'] as double) * (item['unit_price'] as double),
    );
  }

  double get _discountAmount {
    if (_discountValueController.text.isEmpty) return 0.0;
    final value = double.tryParse(_discountValueController.text) ?? 0.0;
    if (_discountType == 'percentage') {
      return (_itemsTotal * value) / 100;
    } else {
      return value;
    }
  }

  double get _finalTotal {
    return (_itemsTotal - _discountAmount).clamp(0.0, double.infinity);
  }

  double get _depositAmount {
    return double.tryParse(_depositAmountController.text) ?? 0.0;
  }

  double get _balance {
    return _finalTotal - _depositAmount;
  }

  Future<void> _createBooking() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila tambah sekurang-kurangnya satu produk'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedEventType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila pilih jenis majlis'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // PHASE: Subscriber Expired System - Protect create action
    await requirePro(context, 'Tambah Tempahan', () async {
      setState(() => _loading = true);

      try {
        await _bookingsRepo.createBooking(
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        customerEmail: _customerEmailController.text.trim().isEmpty
            ? null
            : _customerEmailController.text.trim(),
        eventType: _selectedEventType!,
        eventDate: _eventDateController.text.trim().isEmpty
            ? null
            : _eventDateController.text.trim(),
        deliveryDate: _deliveryDateController.text.trim(),
        deliveryTime: _deliveryTimeController.text.trim().isEmpty
            ? null
            : _deliveryTimeController.text.trim(),
        deliveryLocation: _deliveryLocationController.text.trim().isEmpty
            ? null
            : _deliveryLocationController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        items: _selectedItems,
        discountType: _discountValueController.text.isEmpty ? null : _discountType,
        discountValue: _discountValueController.text.isEmpty
            ? null
            : double.tryParse(_discountValueController.text),
        depositAmount: _depositAmountController.text.isEmpty
            ? null
            : double.tryParse(_depositAmountController.text),
      );

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Tempahan berjaya dicipta!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          
          // Handle subscription enforcement errors
          final subscriptionHandled = await SubscriptionEnforcement.maybePromptUpgrade(
            context,
            action: 'Tambah Tempahan',
            error: e,
          );
          if (subscriptionHandled) return;
          
          // Handle duplicate key error (profile not setup)
          final duplicateKeyHandled = await BusinessProfileErrorHandler.handleDuplicateKeyError(
            context: context,
            error: e,
            actionName: 'Tambah Tempahan',
          );
          if (duplicateKeyHandled) return;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ralat mencipta tempahan: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    });
  }

  void _addProduct(Product product) {
    // Check if product already added
    if (_selectedItems.any((item) => item['product_id'] == product.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produk sudah ditambah. Sila edit kuantiti dari senarai.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final qtyController = TextEditingController(text: '1');
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.add_shopping_cart, color: Colors.blue),
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
                        'Harga: RM${product.salePrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
                  decoration: const InputDecoration(
                    labelText: 'Kuantiti',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
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

                  setState(() {
                    _selectedItems.add({
                      'product_id': product.id,
                      'product_name': product.name,
                      'quantity': qty,
                      'unit_price': product.salePrice,
                    });
                  });
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ ${product.name} ditambah ke tempahan'),
                      backgroundColor: AppColors.success,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Tambah'),
              ),
            ],
          );
        },
      ),
    );
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
                        Icons.shopping_bag,
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
                child: _availableProducts.isEmpty
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
                        itemCount: _availableProducts.length,
                        itemBuilder: (context, index) {
                          final product = _availableProducts[index];

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                _addProduct(product);
                              },
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
                                              color: Colors.grey,
                                              child: const Icon(
                                                Icons.inventory_2_outlined,
                                                color: Colors.white,
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
                                          if (product.category != null && product.category!.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              product.category!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Add Icon
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.add_circle,
                                        color: AppColors.primary,
                                        size: 28,
                                      ),
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

  void _removeItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
  }

  void _updateQuantity(int index, double delta) {
    setState(() {
      final item = _selectedItems[index];
      final newQuantity = ((item['quantity'] as double) + delta).clamp(1.0, double.infinity);
      item['quantity'] = newQuantity;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tempahan Baru'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Customer Information Section
            _buildSectionHeader(
              'Maklumat Pelanggan',
              Icons.person_outline_rounded,
            ),
            const SizedBox(height: 12),
            _buildCustomerSection(),

            const SizedBox(height: 24),

            // Event Information Section
            _buildSectionHeader(
              'Maklumat Majlis',
              Icons.event_rounded,
            ),
            const SizedBox(height: 12),
            _buildEventSection(),

            const SizedBox(height: 24),

            // Delivery Information Section
            _buildSectionHeader(
              'Penghantaran',
              Icons.local_shipping_rounded,
            ),
            const SizedBox(height: 12),
            _buildDeliverySection(),

            const SizedBox(height: 24),

            // Products Section
            _buildSectionHeader(
              'Produk Tempahan',
              Icons.shopping_bag_rounded,
            ),
            const SizedBox(height: 12),
            _buildProductsSection(),

            const SizedBox(height: 24),

            // Discount Section
            if (_selectedItems.isNotEmpty) ...[
              _buildSectionHeader(
                'Diskaun (Opsional)',
                Icons.percent_rounded,
              ),
              const SizedBox(height: 12),
              _buildDiscountSection(),
              const SizedBox(height: 24),
            ],

            // Deposit Section
            _buildSectionHeader(
              'Deposit',
              Icons.account_balance_wallet_rounded,
            ),
            const SizedBox(height: 12),
            _buildDepositSection(),

            const SizedBox(height: 24),

            // Notes Section
            _buildSectionHeader(
              'Nota Tambahan',
              Icons.note_rounded,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Sebarang nota atau permintaan khas...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),

            const SizedBox(height: 24),

            // Total Summary
            if (_selectedItems.isNotEmpty) _buildTotalSummary(),

            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _loading ? null : _createBooking,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Cipta Tempahan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _customerNameController,
            decoration: InputDecoration(
              labelText: 'Nama Pelanggan *',
              hintText: 'Cth: Ahmad bin Ali',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _customerPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Nombor Telefon *',
                    hintText: '0123456789',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email (Pilihan)',
              hintText: 'ahmad@example.com',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedEventType,
            decoration: InputDecoration(
              labelText: 'Jenis Majlis *',
              prefixIcon: const Icon(Icons.event),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            items: const [
              DropdownMenuItem(value: 'perkahwinan', child: Text('Perkahwinan')),
              DropdownMenuItem(value: 'kenduri', child: Text('Kenduri')),
              DropdownMenuItem(value: 'door_gifts', child: Text('Door Gifts')),
              DropdownMenuItem(value: 'birthday', child: Text('Hari Jadi')),
              DropdownMenuItem(value: 'aqiqah', child: Text('Aqiqah')),
              DropdownMenuItem(value: 'lain-lain', child: Text('Lain-lain')),
            ],
            onChanged: (value) => setState(() => _selectedEventType = value),
            validator: (v) => v == null ? 'Sila pilih jenis majlis' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _eventDateController,
            decoration: InputDecoration(
              labelText: 'Tarikh Majlis',
              prefixIcon: const Icon(Icons.calendar_today),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            readOnly: true,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                _eventDateController.text = date.toIso8601String().split('T')[0];
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _deliveryDateController,
                  decoration: InputDecoration(
                    labelText: 'Tarikh Hantar *',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  readOnly: true,
                  validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      _deliveryDateController.text = date.toIso8601String().split('T')[0];
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _deliveryTimeController,
                  decoration: InputDecoration(
                    labelText: 'Masa Hantar',
                    prefixIcon: const Icon(Icons.access_time),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  readOnly: true,
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      _deliveryTimeController.text =
                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _deliveryLocationController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Lokasi Penghantaran',
              hintText: 'Alamat lengkap...',
              prefixIcon: const Icon(Icons.location_on),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Product Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showMultiSelectProductModal,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Tambah Produk'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Selected Items List
          if (_selectedItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Center(
                child: Text(
                  'Tiada produk ditambah. Pilih produk dan klik butang + untuk menambah.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ..._selectedItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildItemCard(index, item);
            }),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index, Map<String, dynamic> item) {
    final quantity = item['quantity'] as double;
    final unitPrice = item['unit_price'] as double;
    final subtotal = quantity * unitPrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['product_name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM${unitPrice.toStringAsFixed(2)} × ${quantity.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'RM${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.red,
                onPressed: () => _updateQuantity(index, -1),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  quantity.toStringAsFixed(1),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.primary,
                onPressed: () => _updateQuantity(index, 1),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.red,
                onPressed: () => _removeItem(index),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _discountType,
                  decoration: InputDecoration(
                    labelText: 'Jenis Diskaun',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text('Peratusan (%)')),
                    DropdownMenuItem(value: 'fixed', child: Text('Jumlah Tetap (RM)')),
                  ],
                  onChanged: (value) => setState(() => _discountType = value ?? 'percentage'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _discountValueController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _discountType == 'percentage' ? 'Peratusan (%)' : 'Jumlah (RM)',
                    hintText: '0',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          if (_discountAmount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Diskaun:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '-RM${_discountAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDepositSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _depositAmountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Deposit Awal (RM)',
              hintText: '0.00',
              prefixIcon: const Icon(Icons.account_balance_wallet),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_depositAmount > 0 && _selectedItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Deposit:'),
                      Text(
                        'RM${_depositAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Baki Perlu Dibayar:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'RM${_balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal:',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                'RM${_itemsTotal.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          if (_discountAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Diskaun:',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  '-RM${_discountAmount.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 14),
                ),
              ],
            ),
          ],
          const Divider(color: Colors.white70),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'JUMLAH AKHIR:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'RM${_finalTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (_depositAmount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Baki:',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  Text(
                    'RM${_balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Show multi-select product modal for bulk adding products
  /// Note: Bookings don't require stock validation (future orders)
  void _showMultiSelectProductModal() {
    MultiSelectProductModal.show(
      context: context,
      products: _availableProducts,
      productStockCache: null, // No stock check for bookings
      validateStock: false,
      title: 'Pilih Produk Tempahan',
      confirmButtonText: 'Tambah',
      onConfirm: (selectedItems) {
        // Process each selected product
        for (final selectedItem in selectedItems) {
          final product = selectedItem.product;
          final qty = selectedItem.quantity;

          // Skip if invalid
          if (product.salePrice <= 0 || qty <= 0) {
            continue;
          }

          // Check if product already added
          final existingIndex = _selectedItems.indexWhere(
            (item) => item['product_id'] == product.id,
          );

          if (existingIndex >= 0) {
            // Update existing quantity
            setState(() {
              _selectedItems[existingIndex]['quantity'] =
                  (_selectedItems[existingIndex]['quantity'] as double) + qty;
            });
          } else {
            // Add new item
            setState(() {
              _selectedItems.add({
                'product_id': product.id,
                'product_name': product.name,
                'quantity': qty,
                'unit_price': product.salePrice,
              });
            });
          }
        }

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
}

