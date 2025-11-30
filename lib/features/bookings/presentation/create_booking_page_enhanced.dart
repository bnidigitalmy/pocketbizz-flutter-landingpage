import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/bookings_repository_supabase.dart';
import '../../../data/repositories/products_repository_supabase.dart';
import '../../../data/models/product.dart';

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
  String? _selectedProductId;
  String _discountType = 'percentage'; // 'percentage' or 'fixed'
  String _selectedQuantity = '1';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _addProduct() {
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila pilih produk'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final product = _availableProducts.firstWhere(
      (p) => p.id == _selectedProductId,
    );

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

    final quantity = double.tryParse(_selectedQuantity) ?? 1.0;
    final unitPrice = product.salePrice;
    final subtotal = quantity * unitPrice;

    setState(() {
      _selectedItems.add({
        'product_id': product.id,
        'product_name': product.name,
        'quantity': quantity,
        'unit_price': unitPrice,
      });
      _selectedProductId = null;
      _selectedQuantity = '1';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${product.name} ditambah ke tempahan'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
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
          // Add Product Row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _selectedProductId,
                  decoration: InputDecoration(
                    labelText: 'Pilih Produk',
                    prefixIcon: const Icon(Icons.shopping_bag),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _availableProducts.map((product) {
                    return DropdownMenuItem(
                      value: product.id,
                      child: Text(
                        '${product.name} - RM${product.salePrice.toStringAsFixed(2)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedProductId = value),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: _selectedQuantity,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Qty',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) => setState(() => _selectedQuantity = value),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addProduct,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.add),
              ),
            ],
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
}

