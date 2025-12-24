import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/shopping_cart_item.dart';
import '../../../data/models/stock_item.dart';
import '../../../data/models/vendor.dart';
import '../../../data/repositories/shopping_cart_repository_supabase.dart';
import '../../../data/repositories/stock_repository_supabase.dart';
import '../../../data/repositories/purchase_order_repository_supabase.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../../../data/models/business_profile.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../onboarding/presentation/widgets/contextual_tooltip.dart';
import '../../onboarding/data/tooltip_content.dart';
import '../../onboarding/services/tooltip_service.dart';

/// Upgraded Shopping List Page
/// Full-featured shopping cart with PO creation, print, and WhatsApp share
class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final _cartRepo = ShoppingCartRepository();
  final _stockRepo = StockRepository(supabase);
  final _poRepo = PurchaseOrderRepository(supabase);
  final _vendorRepo = VendorsRepositorySupabase();
  final _businessProfileRepo = BusinessProfileRepository();
  
  List<ShoppingCartItem> _cartItems = [];
  List<StockItem> _allStockItems = [];
  List<StockItem> _lowStockItems = [];
  List<Vendor> _suppliers = [];
  BusinessProfile? _businessProfile;
  bool _isLoading = true;
  
  // Editable quantities
  final Map<String, TextEditingController> _qtyControllers = {};
  
  // Manual add state
  String? _selectedStockId;
  final _manualQtyController = TextEditingController();
  final _manualNotesController = TextEditingController();
  
  // Supplier state
  String? _selectedSupplierId;
  final _customSupplierNameController = TextEditingController();
  final _customSupplierPhoneController = TextEditingController();
  final _customSupplierEmailController = TextEditingController();
  final _customSupplierAddressController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _poNotesController = TextEditingController();
  
  // Preview state (editable)
  final _previewSupplierNameController = TextEditingController();
  final _previewSupplierPhoneController = TextEditingController();
  final _previewSupplierEmailController = TextEditingController();
  final _previewSupplierAddressController = TextEditingController();
  final _previewDeliveryAddressController = TextEditingController();
  final _previewNotesController = TextEditingController();

  // Track if we need to refresh (e.g., after returning from PO page)
  bool _needsRefresh = false;
  DateTime? _lastRefreshTime;
  
  // Real-time subscriptions
  StreamSubscription? _stockSubscription;
  StreamSubscription? _lowStockSubscription;
  StreamSubscription? _poSubscription;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkAutoPO();
    _setupRealtimeSubscriptions();
    // Removed periodic refresh - hanya guna real-time subscription
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTooltip();
    });
  }

  Future<void> _checkAndShowTooltip() async {
    final hasData = _cartItems.isNotEmpty;
    
    final shouldShow = await TooltipHelper.shouldShowTooltip(
      context,
      TooltipKeys.shoppingList,
      checkEmptyState: !hasData,
      emptyStateChecker: () => !hasData,
    );
    
    if (shouldShow && mounted) {
      final content = hasData ? TooltipContent.shoppingList : TooltipContent.shoppingListEmpty;
      await TooltipHelper.showTooltip(
        context,
        content.moduleKey,
        content.title,
        content.message,
      );
    }
  }


  // Setup real-time subscriptions for stock updates
  void _setupRealtimeSubscriptions() {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Subscribe to stock_items table changes for current user only
      _stockSubscription = supabase
          .from('stock_items')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((data) {
            // Stock items updated - refresh data with debounce
            if (mounted) {
              _debouncedRefresh();
            }
          });

      // Subscribe to purchase_orders table to detect when PO is received
      // This will trigger refresh when PO status changes to 'received'
      try {
        _poSubscription = supabase
            .from('purchase_orders')
            .stream(primaryKey: ['id'])
            .eq('business_owner_id', userId)
            .listen((data) {
              // Check if any PO status changed to 'received'
              final receivedPOs = data.where((po) => po['status'] == 'received').toList();
              if (receivedPOs.isNotEmpty && mounted) {
                // PO received - refresh stock data
                _debouncedRefresh();
              }
            });
      } catch (e) {
        debugPrint('Error setting up PO subscription: $e');
      }
    } catch (e) {
      debugPrint('Error setting up real-time subscriptions: $e');
      // If real-time fails, periodic refresh will handle it
    }
  }

  // Debounce refresh to avoid excessive updates and blinking
  void _debouncedRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadData();
      }
    });
  }

  // Removed periodic refresh - hanya guna real-time subscription untuk avoid blinking

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when page becomes visible (e.g., returning from PO page after receiving)
    // But throttle to avoid excessive refreshes (max once per 2 seconds)
    final now = DateTime.now();
    if (_lastRefreshTime == null || 
        now.difference(_lastRefreshTime!).inSeconds >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadData();
          _lastRefreshTime = now;
        }
      });
    }
  }

  void _checkAutoPO() {
    // Check for autoPO URL parameter (web only)
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          // For web, we can check URL parameters via window.location
          // This is a simplified check - in production, use proper URL handling
          // For now, skip auto-open to avoid web-specific dependencies
          // Can be implemented later with proper web platform channel
        } catch (e) {
          // Ignore errors
        }
      });
    }
  }

  @override
  void dispose() {
    // Cancel real-time subscriptions
    _stockSubscription?.cancel();
    _lowStockSubscription?.cancel();
    _poSubscription?.cancel();
    _debounceTimer?.cancel();
    
    // Dispose controllers
    for (var controller in _qtyControllers.values) {
      controller.dispose();
    }
    _manualQtyController.dispose();
    _manualNotesController.dispose();
    _customSupplierNameController.dispose();
    _customSupplierPhoneController.dispose();
    _customSupplierEmailController.dispose();
    _customSupplierAddressController.dispose();
    _deliveryAddressController.dispose();
    _poNotesController.dispose();
    _previewSupplierNameController.dispose();
    _previewSupplierPhoneController.dispose();
    _previewSupplierEmailController.dispose();
    _previewSupplierAddressController.dispose();
    _previewDeliveryAddressController.dispose();
    _previewNotesController.dispose();
    super.dispose();
  }

  // Track if data is currently loading to prevent multiple simultaneous loads
  bool _isLoadingData = false;

  Future<void> _loadData() async {
    // Prevent multiple simultaneous loads
    if (_isLoadingData) return;
    
    setState(() {
      _isLoading = true;
      _isLoadingData = true;
    });
    
    try {
      // Load data with individual error handling to prevent one failure from breaking everything
      List<ShoppingCartItem> cartItems = [];
      List<StockItem> allStockItems = [];
      List<StockItem> lowStockItems = [];
      List<Vendor> suppliers = [];
      
      try {
        cartItems = await _cartRepo.getAllCartItems(limit: 100);
      } catch (e) {
        debugPrint('Error loading cart items: $e');
      }
      
      try {
        allStockItems = await _stockRepo.getAllStockItems(limit: 100);
      } catch (e) {
        debugPrint('Error loading stock items: $e');
      }
      
      try {
        lowStockItems = await _stockRepo.getLowStockItems();
      } catch (e) {
        debugPrint('Error loading low stock items: $e');
        // Don't show error to user, just use empty list
      }
      
      try {
        suppliers = await _vendorRepo.getAllVendors(activeOnly: true, limit: 100);
      } catch (e) {
        debugPrint('Error loading suppliers: $e');
      }
      
      // Load business profile
      BusinessProfile? businessProfile;
      try {
        businessProfile = await _businessProfileRepo.getBusinessProfile();
      } catch (e) {
        debugPrint('Error loading business profile: $e');
      }
      
      if (mounted) {
        setState(() {
          _cartItems = cartItems;
          _allStockItems = allStockItems;
          _lowStockItems = lowStockItems;
          _suppliers = suppliers;
          _businessProfile = businessProfile;
          _isLoading = false;
          _isLoadingData = false;
        });
      }
      
      // Initialize quantity controllers (convert from base unit to pek/pcs)
      for (var item in _cartItems) {
        final packageSize = item.stockItemPackageSize ?? 1.0;
        final qtyInPek = packageSize > 0 ? (item.shortageQty / packageSize).toStringAsFixed(0) : item.shortageQty.toStringAsFixed(1);
        _qtyControllers[item.id] = TextEditingController(
          text: qtyInPek,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingData = false;
        });
      }
      debugPrint('Unexpected error in _loadData: $e');
      // Don't show error snackbar to avoid UI clutter
    }
  }

  double _calculateTotalEstimated() {
    return _cartItems.fold<double>(0.0, (sum, item) {
      // qtyStr is in pek/pcs
      final qtyStr = _qtyControllers[item.id]?.text;
      final qtyInPek = qtyStr != null ? double.tryParse(qtyStr) : null;
      
      if (qtyInPek == null || item.stockItemPurchasePrice == null) {
        // Fallback: use stored shortageQty and calculate packages
        final packageSize = item.stockItemPackageSize ?? 1.0;
        final packagesNeeded = packageSize > 0 
            ? (item.shortageQty / packageSize).ceil()
            : 1;
        return sum + (packagesNeeded * (item.stockItemPurchasePrice ?? 0.0));
      }
      
      // qtyInPek is already in pek/pcs, so use directly
      return sum + (qtyInPek * (item.stockItemPurchasePrice ?? 0.0));
    });
  }

  Future<void> _removeItem(String id) async {
    try {
      await _cartRepo.removeFromCart(id);
      _qtyControllers.remove(id);
      _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Item dibuang dari senarai'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateQuantity(String itemId, String newQty) async {
    try {
      final qtyInPek = double.tryParse(newQty);
      if (qtyInPek == null || qtyInPek <= 0) return;
      
      // Get item to get package size
      final item = _cartItems.firstWhere((i) => i.id == itemId);
      final packageSize = item.stockItemPackageSize ?? 1.0;
      
      // Convert from pek/pcs to base unit
      final qty = qtyInPek * packageSize;
      
      // Use updateCartItem instead of remove/add
      final updatedItem = await _cartRepo.updateCartItem(
        id: itemId,
        shortageQty: qty,
      );
      
      // Update local state without full reload
      setState(() {
        final index = _cartItems.indexWhere((i) => i.id == itemId);
        if (index != -1) {
          _cartItems[index] = updatedItem;
          // Update controller (convert to pek/pcs)
          final packageSize = updatedItem.stockItemPackageSize ?? 1.0;
          final qtyInPek = packageSize > 0 
              ? (qty / packageSize).toStringAsFixed(0)
              : qty.toStringAsFixed(1);
          _qtyControllers[itemId]?.text = qtyInPek;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _addManualItem() async {
    if (_selectedStockId == null || _manualQtyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila pilih item dan masukkan kuantiti'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final qtyInPek = double.tryParse(_manualQtyController.text);
    if (qtyInPek == null || qtyInPek <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kuantiti mesti lebih daripada 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Get stock item untuk package size
    final stockItem = _allStockItems.firstWhere((s) => s.id == _selectedStockId);
    final packageSize = stockItem.packageSize;
    
    // Convert from pek/pcs to base unit
    final qty = qtyInPek * packageSize;
    
    try {
      await _cartRepo.addToCart(
        stockItemId: _selectedStockId!,
        shortageQty: qty,
        notes: _manualNotesController.text.trim().isEmpty 
            ? null 
            : _manualNotesController.text.trim(),
      );
      
      setState(() {
        _selectedStockId = null;
        _manualQtyController.clear();
        _manualNotesController.clear();
      });
      
      _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Item ditambah ke cart'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _quickAddLowStock(StockItem item) async {
    final currentQty = item.currentQuantity;
    final threshold = item.lowStockThreshold;
    final shortage = threshold - currentQty;
    
    // Calculate packages needed (rounded up)
    final packagesNeeded = shortage > 0 
        ? (shortage / item.packageSize).ceil()
        : 1; // At least 1 pek if no shortage
    
    // Convert to base unit
    final qty = packagesNeeded * item.packageSize;
    
    try {
      await _cartRepo.addToCart(
        stockItemId: item.id,
        shortageQty: qty,
      );
      
      _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${item.name} (${qty.toStringAsFixed(1)} ${item.unit}) ditambah'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _quickAddAllLowStock() async {
    final availableItems = _lowStockItems.where(
      (item) => !_cartItems.any((ci) => ci.stockItemId == item.id),
    ).toList();
    
    if (availableItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua item stok rendah sudah dalam cart'),
        ),
      );
      return;
    }
    
    try {
      for (var item in availableItems) {
        final currentQty = item.currentQuantity;
        final threshold = item.lowStockThreshold;
        final shortage = threshold - currentQty;
        
        // Calculate packages needed (rounded up)
        final packagesNeeded = shortage > 0 
            ? (shortage / item.packageSize).ceil()
            : 1; // At least 1 pek if no shortage
        
        // Convert to base unit
        final qty = packagesNeeded * item.packageSize;
        
        await _cartRepo.addToCart(
          stockItemId: item.id,
          shortageQty: qty,
        );
      }
      
      _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 ${availableItems.length} item ditambah!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _openPreviewDialog() {
    // Populate preview from supplier dialog
    String supplierName = 'Supplier Manual';
    String supplierPhone = '';
    String supplierEmail = '';
    String supplierAddress = '';
    
    if (_selectedSupplierId != null) {
      // Get supplier from list
      final supplier = _suppliers.firstWhere(
        (s) => s.id == _selectedSupplierId,
        orElse: () => Vendor(
          id: '',
          businessOwnerId: '',
          name: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      if (supplier.id.isNotEmpty) {
        supplierName = supplier.name;
        supplierPhone = supplier.phone ?? '';
        supplierEmail = supplier.email ?? '';
        supplierAddress = supplier.address ?? '';
      }
    } else if (_customSupplierNameController.text.trim().isNotEmpty) {
      supplierName = _customSupplierNameController.text.trim();
      supplierPhone = _customSupplierPhoneController.text.trim();
      supplierEmail = _customSupplierEmailController.text.trim();
      supplierAddress = _customSupplierAddressController.text.trim();
    }
    
    _previewSupplierNameController.text = supplierName;
    _previewSupplierPhoneController.text = supplierPhone;
    _previewSupplierEmailController.text = supplierEmail;
    _previewSupplierAddressController.text = supplierAddress;
    _previewDeliveryAddressController.text = _deliveryAddressController.text;
    _previewNotesController.text = _poNotesController.text;
    
    _showPreviewDialog();
  }

  Future<void> _createPO() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart kosong'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Update quantities first (qtyStr is in pek/pcs)
    for (var item in _cartItems) {
      final qtyStr = _qtyControllers[item.id]?.text;
      if (qtyStr != null) {
        // Convert to base unit for comparison
        final packageSize = item.stockItemPackageSize ?? 1.0;
        final qtyInPek = double.tryParse(qtyStr) ?? 0;
        final qtyInBaseUnit = qtyInPek * packageSize;
        
        // Only update if different
        if ((qtyInBaseUnit - item.shortageQty).abs() > 0.01) {
          await _updateQuantity(item.id, qtyStr);
        }
      }
    }
    
    // Create PO via repository
    try {
      final cartItemIds = _cartItems.map((item) => item.id).toList();
      
      await _poRepo.createPOFromCart(
        supplierId: _selectedSupplierId,
        supplierName: _previewSupplierNameController.text.trim(),
        supplierPhone: _previewSupplierPhoneController.text.trim().isEmpty
            ? null
            : _previewSupplierPhoneController.text.trim(),
        supplierEmail: _previewSupplierEmailController.text.trim().isEmpty
            ? null
            : _previewSupplierEmailController.text.trim(),
        supplierAddress: _previewSupplierAddressController.text.trim().isEmpty
            ? null
            : _previewSupplierAddressController.text.trim(),
        deliveryAddress: _previewDeliveryAddressController.text.trim().isEmpty
            ? null
            : _previewDeliveryAddressController.text.trim(),
        notes: _previewNotesController.text.trim().isEmpty
            ? null
            : _previewNotesController.text.trim(),
        cartItemIds: cartItemIds,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Purchase Order Dibuat!'),
            backgroundColor: AppColors.success,
          ),
        );
        
        setState(() {
          _selectedSupplierId = null;
          _customSupplierNameController.clear();
          _customSupplierPhoneController.clear();
          _customSupplierEmailController.clear();
          _customSupplierAddressController.clear();
          _deliveryAddressController.clear();
          _poNotesController.clear();
        });
        
        _loadData();
        
        // Navigate to PO page
        await Navigator.pushNamed(context, '/purchase-orders');
        
        // Refresh when returning from PO page (in case PO was received)
        if (mounted) {
          _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating PO: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareWhatsApp() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart kosong'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final date = DateFormat('dd MMMM yyyy', 'ms_MY').format(DateTime.now());
    var message = '*SENARAI BELIAN*\n';
    message += 'Tarikh: $date\n\n';
    
    for (var i = 0; i < _cartItems.length; i++) {
      final item = _cartItems[i];
      // qtyStr is in pek/pcs
      final qtyStr = _qtyControllers[item.id]?.text;
      final packageSize = item.stockItemPackageSize ?? 1.0;
      
      final qtyInPek = qtyStr != null 
          ? double.tryParse(qtyStr) 
          : (packageSize > 0 ? (item.shortageQty / packageSize).ceil() : 1);
      
      final qtyInBaseUnit = (qtyInPek ?? 1) * packageSize;
      
      message += '${i + 1}. ${item.stockItemName}\n';
      message += '   Kuantiti: $qtyInPek pek/pcs (${qtyInBaseUnit.toStringAsFixed(1)} ${item.stockItemUnit})\n\n';
    }
    
    message += '\nJumlah: ${_cartItems.length} item';
    
    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl = 'https://wa.me/?text=$encodedMessage';
    
    try {
      await launchUrl(Uri.parse(whatsappUrl));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _printList() {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart kosong'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (kIsWeb) {
      // For web, trigger browser print via JavaScript
      // Using platform channel would be better, but for now show message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Print: Gunakan Ctrl+P atau Cmd+P untuk cetak'),
        ),
      );
    } else {
      // For mobile, show message (can integrate printing package later)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Print functionality untuk mobile coming soon')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalEstimated = _calculateTotalEstimated();
    
    // Filter low stock items:
    // 1. Not already in cart (pending status)
    // 2. Actually still low stock - check against fresh stock data from allStockItems
    // 3. Cross-reference with allStockItems to get latest currentQuantity
    final availableLowStock = _lowStockItems.where((item) {
      // Check if item is in cart with pending status
      final inCartPending = _cartItems.any(
        (ci) => ci.stockItemId == item.id && ci.status == 'pending',
      );
      
      // Get fresh stock data from allStockItems (more up-to-date than low_stock_items view)
      final freshStockItem = _allStockItems.firstWhere(
        (si) => si.id == item.id,
        orElse: () => item, // Fallback to item from low stock list if not found
      );
      
      // Check if item is actually still low stock using fresh data
      final isStillLowStock = freshStockItem.currentQuantity <= freshStockItem.lowStockThreshold;
      
      // Only show if not in pending cart AND still actually low stock
      return !inCartPending && isStillLowStock;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🛒 Senarai Belian'),
            Text(
              'Atur pesanan pembelian untuk supplier',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.description),
            onPressed: () async {
              _needsRefresh = true;
              await Navigator.pushNamed(context, '/purchase-orders');
              // Refresh when returning from PO page
              if (mounted) {
                _loadData();
              }
            },
            tooltip: 'Sejarah PO',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareWhatsApp,
            tooltip: 'Kongsi WhatsApp',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printList,
            tooltip: 'Cetak',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Item dalam Cart',
                          '${_cartItems.length}',
                          Icons.shopping_cart,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Stok Rendah',
                          '${_lowStockItems.length}',
                          Icons.warning,
                          Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Anggaran',
                          'RM ${totalEstimated.toStringAsFixed(2)}',
                          Icons.inventory_2,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Shopping Cart Section
                  Card(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 400;
                              
                              if (isNarrow) {
                                // Stack vertically for narrow screens
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Senarai Belian',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _cartItems.isEmpty
                                          ? 'Cart kosong. Tambah item untuk buat PO.'
                                          : '${_cartItems.length} item. Klik \'Buat PO\' bila sedia.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () => _showManualAddDialog(),
                                            icon: const Icon(Icons.add, size: 18),
                                            label: const Text('Tambah Item'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ),
                                        if (_cartItems.isNotEmpty)
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: () => _showSupplierDialog(),
                                              icon: const Icon(Icons.description, size: 18),
                                              label: const Text('Buat PO'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.success,
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                );
                              } else {
                                // Horizontal layout for wider screens
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Senarai Belian',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            _cartItems.isEmpty
                                                ? 'Cart kosong. Tambah item untuk buat PO.'
                                                : '${_cartItems.length} item. Klik \'Buat PO\' bila sedia.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Flexible(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.end,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () => _showManualAddDialog(),
                                            icon: const Icon(Icons.add, size: 18),
                                            label: const Text('Tambah Item'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                          if (_cartItems.isNotEmpty)
                                            ElevatedButton.icon(
                                              onPressed: () => _showSupplierDialog(),
                                              icon: const Icon(Icons.description, size: 18),
                                              label: const Text('Buat PO'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.success,
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                        ),
                        if (_cartItems.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Cart Kosong',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Klik \'Tambah Item\' untuk mulakan pesanan',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._cartItems.map((item) => _buildCartItemCard(item)),
                        if (_cartItems.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Jumlah Anggaran Kos',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      '(${_cartItems.length} item)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'RM ${totalEstimated.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 24,
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
                  
                  // Low Stock Suggestions
                  if (availableLowStock.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Card(
                      color: Colors.amber[50],
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 400;
                                
                                if (isNarrow) {
                                  // Stack vertically for narrow screens
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.warning, color: Colors.amber[700]),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              'Cadangan: Item Stok Rendah',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Klik sekali untuk tambah terus ke cart dengan kuantiti cadangan',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      if (availableLowStock.length > 1) ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: _quickAddAllLowStock,
                                            icon: const Icon(Icons.add, size: 18),
                                            label: Text('Tambah Semua (${availableLowStock.length})'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.amber[600],
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                } else {
                                  // Horizontal layout for wider screens
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.warning, color: Colors.amber[700]),
                                                const SizedBox(width: 8),
                                                const Expanded(
                                                  child: Text(
                                                    'Cadangan: Item Stok Rendah',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.amber,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Klik sekali untuk tambah terus ke cart dengan kuantiti cadangan',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (availableLowStock.length > 1) ...[
                                        const SizedBox(width: 12),
                                        Flexible(
                                          child: ElevatedButton.icon(
                                            onPressed: _quickAddAllLowStock,
                                            icon: const Icon(Icons.add, size: 18),
                                            label: Text('Tambah Semua (${availableLowStock.length})'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.amber[600],
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                }
                              },
                            ),
                          ),
                          ...availableLowStock.take(5).map((item) {
                            // Use fresh stock data from allStockItems
                            final freshStockItem = _allStockItems.firstWhere(
                              (si) => si.id == item.id,
                              orElse: () => item,
                            );
                            final currentQty = freshStockItem.currentQuantity;
                            final threshold = freshStockItem.lowStockThreshold;
                            final shortage = threshold - currentQty;
                            
                            // Calculate packages needed (rounded up)
                            final packagesNeeded = shortage > 0 
                                ? (shortage / freshStockItem.packageSize).ceil()
                                : 1; // At least 1 pek if no shortage
                            final qty = packagesNeeded * freshStockItem.packageSize;
                            
                            final screenWidth = MediaQuery.of(context).size.width;
                            final isNarrow = screenWidth < 400;
                            
                            if (isNarrow) {
                              // Stack buttons vertically for narrow screens
                              return ListTile(
                                title: Text(freshStockItem.name),
                                subtitle: Text(
                                  'Stok: ${currentQty.toStringAsFixed(1)} ${freshStockItem.unit} • Cadangan: $packagesNeeded pek/pcs (${qty.toStringAsFixed(1)} ${freshStockItem.unit})',
                                ),
                                isThreeLine: true,
                                trailing: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: ElevatedButton(
                                        onPressed: () => _quickAddLowStock(item),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[600],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        ),
                                        child: const FittedBox(
                                          child: Text('Quick Add', style: TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: 100,
                                      child:                                     OutlinedButton(
                                      onPressed: () {
                                        _selectedStockId = item.id;
                                        _manualQtyController.text = packagesNeeded.toStringAsFixed(0);
                                        _showManualAddDialog();
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                      child: const FittedBox(
                                        child: Text('Edit', style: TextStyle(fontSize: 12)),
                                      ),
                                    ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              // Horizontal buttons for wider screens
                              return ListTile(
                                title: Text(freshStockItem.name),
                                subtitle: Text(
                                  'Stok: ${currentQty.toStringAsFixed(1)} ${freshStockItem.unit} • Cadangan: $packagesNeeded pek/pcs (${qty.toStringAsFixed(1)} ${freshStockItem.unit})',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => _quickAddLowStock(item),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[600],
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Quick Add'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: () {
                                        _selectedStockId = item.id;
                                        _manualQtyController.text = packagesNeeded.toStringAsFixed(0);
                                        _showManualAddDialog();
                                      },
                                      child: const Text('Edit'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemCard(ShoppingCartItem item) {
    // Convert from base unit to pek/pcs for display
    final packageSize = item.stockItemPackageSize ?? 1.0;
    final qtyInPek = packageSize > 0 
        ? (item.shortageQty / packageSize).toStringAsFixed(0)
        : item.shortageQty.toStringAsFixed(1);
    
    final qtyController = _qtyControllers[item.id] ?? 
        TextEditingController(text: qtyInPek);
    _qtyControllers[item.id] = qtyController;
    
    final estimatedCost = () {
      // qtyController.text is in pek/pcs
      final qtyStr = qtyController.text;
      final qtyInPek = double.tryParse(qtyStr);
      
      if (qtyInPek == null || item.stockItemPurchasePrice == null) {
        return 0.0;
      }
      
      // qtyInPek is already in pek/pcs, so use directly
      return qtyInPek * item.stockItemPurchasePrice!;
    }();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        item.stockItemName ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (item.notes != null && item.notes!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            item.notes!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDelete(item),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kuantiti (pek/pcs)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Show base unit quantity below
                      if (item.stockItemPackageSize != null) ...[
                        Text(
                          '(${(double.tryParse(qtyController.text) ?? 0) * item.stockItemPackageSize!} ${item.stockItemUnit})',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              final current = double.tryParse(qtyController.text) ?? 0;
                              if (current > 0) {
                                qtyController.text = (current - 1).toStringAsFixed(0);
                                _updateQuantity(item.id, qtyController.text);
                              }
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: qtyController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: false),
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              onChanged: (value) {
                                // Update on blur or enter
                              },
                              onEditingComplete: () {
                                _updateQuantity(item.id, qtyController.text);
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              final current = double.tryParse(qtyController.text) ?? 0;
                              qtyController.text = (current + 1).toStringAsFixed(0);
                              _updateQuantity(item.id, qtyController.text);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'pek/pcs',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Anggaran',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM ${estimatedCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ShoppingCartItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buang dari Senarai?'),
        content: Text(
          'Adakah anda pasti mahu membuang "${item.stockItemName}" dari senarai belian?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Buang'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _removeItem(item.id);
    }
  }

  void _showManualAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          title: const Text('Tambah Item Manual'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatefulBuilder(
                  builder: (context, setDialogState) {
                    return DropdownButtonFormField<String>(
                      value: _selectedStockId,
                      decoration: const InputDecoration(
                        labelText: 'Item Stok',
                        border: OutlineInputBorder(),
                      ),
                      items: _allStockItems.map((item) {
                        return DropdownMenuItem(
                          value: item.id,
                          child: Text('${item.name} (${item.unit})'),
                        );
                      }).toList(),
                      onChanged: (value) => setDialogState(() => _selectedStockId = value),
                    );
                  },
                ),
                const SizedBox(height: 16),
                StatefulBuilder(
                  builder: (context, setDialogState) {
                    final selectedItem = _selectedStockId != null
                        ? _allStockItems.firstWhere(
                            (s) => s.id == _selectedStockId,
                            orElse: () => _allStockItems.first,
                          )
                        : null;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _manualQtyController,
                          decoration: InputDecoration(
                            labelText: 'Kuantiti',
                            hintText: 'e.g., 5 (untuk 5 pek/pcs)',
                            suffixText: 'pek/pcs',
                            border: const OutlineInputBorder(),
                            helperText: selectedItem != null
                                ? 'Masukkan bilangan pek/pcs. Contoh: Jika beli 5 pek @ ${selectedItem.packageSize.toStringAsFixed(0)} ${selectedItem.unit}, masukkan: 5'
                                : 'Masukkan bilangan pek/pcs yang dibeli',
                            helperMaxLines: 2,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _manualNotesController,
                  decoration: const InputDecoration(
                    labelText: 'Nota (Opsional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _selectedStockId = null;
                  _manualQtyController.clear();
                  _manualNotesController.clear();
                });
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _addManualItem();
              },
              child: const Text('Tambah ke Cart'),
            ),
          ],
        ),
    );
  }

  void _showSupplierDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pilih Supplier'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Supplier Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedSupplierId,
                  decoration: const InputDecoration(
                    labelText: 'Supplier Sedia Ada',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('+ Supplier Baru (Manual)'),
                    ),
                    ..._suppliers.map((supplier) {
                      return DropdownMenuItem<String>(
                        value: supplier.id,
                        child: Text(supplier.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedSupplierId = value;
                      if (value != null) {
                        final supplier = _suppliers.firstWhere(
                          (s) => s.id == value,
                        );
                        _customSupplierNameController.text = supplier.name;
                        _customSupplierPhoneController.text = supplier.phone ?? '';
                        _customSupplierEmailController.text = supplier.email ?? '';
                        _customSupplierAddressController.text = supplier.address ?? '';
                      } else {
                        _customSupplierNameController.clear();
                        _customSupplierPhoneController.clear();
                        _customSupplierEmailController.clear();
                        _customSupplierAddressController.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Custom Supplier Fields (shown when no supplier selected or always)
                if (_selectedSupplierId == null) ...[
                  TextField(
                    controller: _customSupplierNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Supplier *',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _customSupplierPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Telefon Supplier (Opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _customSupplierEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Supplier (Opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _customSupplierAddressController,
                    decoration: const InputDecoration(
                      labelText: 'Alamat Supplier (Opsional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _deliveryAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Penghantaran (Opsional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _poNotesController,
                  decoration: const InputDecoration(
                    labelText: 'Nota PO (Opsional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: (_selectedSupplierId != null || _customSupplierNameController.text.trim().isNotEmpty)
                  ? () {
                      Navigator.pop(context);
                      _openPreviewDialog();
                    }
                  : null,
              child: const Text('Semak & Sahkan PO'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPreviewDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          title: const Text('Semak Purchase Order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Business Info
                Card(
                  color: Colors.grey[100],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📋 Maklumat Perniagaan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _businessProfile?.businessName ?? 'PocketBizz',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_businessProfile?.address != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _businessProfile!.address!,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                        if (_businessProfile?.phone != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Tel: ${_businessProfile!.phone}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Supplier Info (Editable)
                const Text(
                  '📤 Maklumat Supplier',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _previewSupplierNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Supplier *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _previewSupplierPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'No. Telefon',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _previewSupplierEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _previewSupplierAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Supplier',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                
                // Delivery Address
                const Text(
                  '📍 Alamat Penghantaran',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _previewDeliveryAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Alamat penghantaran',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                
                // Items Table
                const Text(
                  '📦 Senarai Item',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                DataTable(
                  columns: const [
                    DataColumn(label: Text('Item')),
                    DataColumn(label: Text('Kuantiti', textAlign: TextAlign.right)),
                    DataColumn(label: Text('Anggaran', textAlign: TextAlign.right)),
                  ],
                  rows: _cartItems.map((item) {
                    // qtyStr is in pek/pcs
                    final qtyStr = _qtyControllers[item.id]?.text;
                    final qtyInPek = qtyStr != null ? double.tryParse(qtyStr) : null;
                    
                    // Fallback: convert from base unit to pek/pcs
                    final packageSize = item.stockItemPackageSize ?? 1.0;
                    final displayPek = qtyInPek ?? (packageSize > 0 ? (item.shortageQty / packageSize).ceil() : 1);
                    final displayQty = displayPek * packageSize;
                    
                    final estimated = () {
                      if (item.stockItemPurchasePrice == null) {
                        return 0.0;
                      }
                      // displayPek is already in pek/pcs
                      return displayPek * item.stockItemPurchasePrice!;
                    }();
                    
                    return DataRow(
                      cells: [
                        DataCell(Text(item.stockItemName ?? 'Unknown')),
                        DataCell(Text(
                          '$displayPek pek/pcs\n(${displayQty.toStringAsFixed(1)} ${item.stockItemUnit})',
                          textAlign: TextAlign.right,
                        )),
                        DataCell(Text(
                          estimated > 0 ? 'RM ${estimated.toStringAsFixed(2)}' : '-',
                          textAlign: TextAlign.right,
                        )),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Jumlah Anggaran:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      'RM ${_calculateTotalEstimated().toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Notes
                const Text(
                  '📝 Nota',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _previewNotesController,
                  decoration: const InputDecoration(
                    labelText: 'Nota tambahan',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showSupplierDialog();
              },
              child: const Text('Kembali'),
            ),
            ElevatedButton(
              onPressed: _previewSupplierNameController.text.trim().isEmpty
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _createPO();
                    },
              child: const Text('Sahkan & Buat PO'),
            ),
          ],
        ),
    );
  }
}
