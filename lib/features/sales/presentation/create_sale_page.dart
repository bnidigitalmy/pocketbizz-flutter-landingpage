import 'package:flutter/material.dart';
import '../../../data/repositories/sales_repository_supabase.dart';
import '../../../data/repositories/products_repository_supabase.dart';
import '../../../data/repositories/production_repository_supabase.dart';
import '../../../data/models/product.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../features/subscription/exceptions/subscription_limit_exception.dart';
import '../../../features/subscription/presentation/subscription_page.dart';
import '../../../features/subscription/widgets/subscription_guard.dart';

class CreateSalePage extends StatefulWidget {
  const CreateSalePage({super.key});

  @override
  State<CreateSalePage> createState() => _CreateSalePageState();
}

class _CreateSalePageState extends State<CreateSalePage> {
  final _formKey = GlobalKey<FormState>();
  final _salesRepo = SalesRepositorySupabase();
  final _productsRepo = ProductsRepositorySupabase();
  final _productionRepo = ProductionRepository(supabase);

  // Controllers
  final _customerNameController = TextEditingController();
  final _notesController = TextEditingController();

  String _channel = 'walk-in';
  bool _loading = false;
  final List<Map<String, dynamic>> _selectedItems = [];
  List<Product> _availableProducts = [];
  final Map<String, double> _productStockCache = {}; // Cache for stock availability

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _productsRepo.listProducts();
      
      // Load stock availability for all products
      for (final product in products) {
        try {
          final availableStock = await _productionRepo.getTotalRemainingForProduct(product.id);
          _productStockCache[product.id] = availableStock;
        } catch (e) {
          // If error, set to 0 (no stock available)
          _productStockCache[product.id] = 0.0;
        }
      }
      
      setState(() => _availableProducts = products);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  Future<void> _createSale() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sila tambah sekurang-kurangnya satu item')),
      );
      return;
    }

    // Validate stock availability before creating sale
    for (final item in _selectedItems) {
      final productId = item['product_id'] as String;
      final qty = (item['quantity'] as num).toDouble();
      final productName = item['product_name'] as String;
      final availableStock = _productStockCache[productId] ?? 0.0;
      
      if (qty > availableStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Stok tidak mencukupi untuk "$productName": '
              'Tersedia: ${availableStock.toStringAsFixed(1)}, '
              'Diperlukan: ${qty.toStringAsFixed(1)}'
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
    }

    // PHASE: Subscriber Expired System - Protect create action
    await requirePro(context, 'Tambah Jualan', () async {
      setState(() => _loading = true);

      try {
        await _salesRepo.createSale(
          customerName: _customerNameController.text.trim().isEmpty
              ? null
              : _customerNameController.text.trim(),
          channel: _channel,
          items: _selectedItems,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sale created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          // PHASE 3: Handle subscription limit exceptions with upgrade prompt
          if (e is SubscriptionLimitException) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.workspace_premium, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Had Langganan Dicapai'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.userMessage),
                  const SizedBox(height: 16),
                  const Text(
                    'Upgrade langganan anda untuk menambah lebih banyak transaksi.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Tutup'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SubscriptionPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Lihat Pakej'),
                ),
              ],
            ),
          );
        } else {
          final handled = await SubscriptionEnforcement.maybePromptUpgrade(
            context,
            action: 'Tambah Jualan',
            error: e,
          );
          if (handled) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
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
    final availableStock = _productStockCache[product.id] ?? 0.0;
    
    showDialog(
      context: context,
      builder: (context) {
        final qtyController = TextEditingController(text: '1');
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Add ${product.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Price: RM${product.salePrice.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: availableStock > 0 
                          ? Colors.green[50] 
                          : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: availableStock > 0 
                            ? Colors.green[300]! 
                            : Colors.red[300]!,
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
                  TextField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      border: const OutlineInputBorder(),
                      helperText: availableStock > 0 
                          ? 'Maksimum: ${availableStock.toStringAsFixed(1)} unit'
                          : 'Tiada stok tersedia',
                      errorText: () {
                        final qty = double.tryParse(qtyController.text) ?? 0;
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
                  child: const Text('Cancel'),
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
                    
                    if (qty > availableStock) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Kuantiti melebihi stok tersedia (${availableStock.toStringAsFixed(1)} unit)'
                          ),
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
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: availableStock > 0 ? null : Colors.grey,
                  ),
                  child: const Text('Add'),
                ),
              ],
            );
          },
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
        title: const Text('New Sale'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Channel Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sales Channel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'walk-in',
                          label: Text('Walk-in'),
                          icon: Icon(Icons.store),
                        ),
                        ButtonSegment(
                          value: 'online',
                          label: Text('Online'),
                          icon: Icon(Icons.shopping_cart),
                        ),
                        ButtonSegment(
                          value: 'delivery',
                          label: Text('Delivery'),
                          icon: Icon(Icons.delivery_dining),
                        ),
                      ],
                      selected: {_channel},
                      onSelectionChanged: (Set<String> selected) {
                        setState(() => _channel = selected.first);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Customer Name
            TextFormField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
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
                  onPressed: () => _showProductSelector(),
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
              ..._selectedItems.map((item) {
                final productId = item['product_id'] as String;
                final qty = (item['quantity'] as num).toDouble();
                final availableStock = _productStockCache[productId] ?? 0.0;
                final isStockSufficient = qty <= availableStock;
                
                return Card(
                  color: isStockSufficient ? null : Colors.red[50],
                  child: ListTile(
                    title: Row(
                      children: [
                        Expanded(child: Text(item['product_name'])),
                        if (!isStockSufficient)
                          const Icon(Icons.warning, color: Colors.red, size: 20),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Qty: ${item['quantity']} × RM${item['unit_price'].toStringAsFixed(2)}',
                        ),
                        if (!isStockSufficient)
                          Text(
                            '⚠️ Stok tidak mencukupi (Tersedia: ${availableStock.toStringAsFixed(1)})',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'RM${(item['quantity'] * item['unit_price']).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () {
                            setState(() => _selectedItems.remove(item));
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
              ),
            ),

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
              onPressed: _loading ? null : _createSale,
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
                      'Complete Sale',
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
}

