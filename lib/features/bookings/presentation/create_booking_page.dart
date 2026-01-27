import 'package:flutter/material.dart';
import '../../../core/utils/business_profile_error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/bookings_repository_supabase.dart';
import '../../../data/repositories/products_repository_supabase.dart';
import '../../../data/models/product.dart';
import '../../../shared/widgets/multi_select_product_modal.dart';

class CreateBookingPage extends StatefulWidget {
  const CreateBookingPage({super.key});

  @override
  State<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends State<CreateBookingPage> {
  final _formKey = GlobalKey<FormState>();
  final _bookingsRepo = BookingsRepositorySupabase();
  final _productsRepo = ProductsRepositorySupabase();

  // Controllers
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _eventTypeController = TextEditingController();
  final _deliveryDateController = TextEditingController();
  final _notesController = TextEditingController();

  bool _loading = false;
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
    _eventTypeController.dispose();
    _deliveryDateController.dispose();
    _notesController.dispose();
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

  Future<void> _createBooking() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
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
        eventType: _eventTypeController.text.trim(),
        deliveryDate: _deliveryDateController.text.trim(),
        items: _selectedItems,
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Handle duplicate key error (profile not setup)
        final duplicateKeyHandled = await BusinessProfileErrorHandler.handleDuplicateKeyError(
          context: context,
          error: e,
          actionName: 'Tambah Tempahan',
        );
        if (!duplicateKeyHandled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ralat mencipta tempahan: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _addProduct(Product product) {
    showDialog(
      context: context,
      builder: (context) {
        final qtyController = TextEditingController(text: '1');
        return AlertDialog(
          title: Text('Add ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Price: RM${product.salePrice.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(qtyController.text) ?? 1;
                setState(() {
                  _selectedItems.add({
                    'product_id': product.id,
                    'product_name': product.name,
                    'quantity': qty,
                    'unit_price': product.salePrice,
                  });
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = _selectedItems.fold<double>(
      0,
      (sum, item) => sum + (item['quantity'] * item['unit_price']),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Booking'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Customer Info Section
            const Text(
              'Customer Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (Optional)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            // Event Info Section
            const Text(
              'Event Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _eventTypeController,
              decoration: const InputDecoration(
                labelText: 'Event Type *',
                hintText: 'e.g., Wedding, Birthday, Corporate',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _deliveryDateController,
              decoration: const InputDecoration(
                labelText: 'Delivery Date *',
                hintText: 'YYYY-MM-DD',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
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
              readOnly: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            // Items Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _showMultiSelectProductModal,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_selectedItems.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No items yet. Click "Add Product" to add items.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ..._selectedItems.map((item) => Card(
                    child: ListTile(
                      title: Text(item['product_name']),
                      subtitle: Text(
                        'Qty: ${item['quantity']} × RM${item['unit_price'].toStringAsFixed(2)}',
                      ),
                      trailing: Text(
                        'RM${(item['quantity'] * item['unit_price']).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      leading: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          setState(() => _selectedItems.remove(item));
                        },
                      ),
                    ),
                  )),

            const SizedBox(height: 24),

            // Total
            Card(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'RM${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Submit button
            ElevatedButton(
              onPressed: _loading ? null : _createBooking,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Create Booking',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Select Product',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _availableProducts.isEmpty
                    ? const Center(child: Text('No products available'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _availableProducts.length,
                        itemBuilder: (context, index) {
                          final product = _availableProducts[index];
                          return ListTile(
                            title: Text(product.name),
                            subtitle: Text(
                              'RM${product.salePrice.toStringAsFixed(2)} | ${product.category ?? "No Category"}',
                            ),
                            trailing: const Icon(Icons.add_circle),
                            onTap: () {
                              Navigator.pop(context);
                              _addProduct(product);
                            },
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

          setState(() {
            _selectedItems.add({
              'product_id': product.id,
              'product_name': product.name,
              'quantity': qty,
              'unit_price': product.salePrice,
            });
          });
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

