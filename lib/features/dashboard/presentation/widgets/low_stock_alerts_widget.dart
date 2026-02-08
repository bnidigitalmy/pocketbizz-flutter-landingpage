import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/supabase/supabase_client.dart' show supabase;
import '../../../../data/repositories/stock_repository_supabase.dart';
import '../../../../data/repositories/shopping_cart_repository_supabase.dart';
import '../../../../data/repositories/purchase_order_repository_supabase.dart';
import '../../../../data/models/stock_item.dart';
import '../../../../core/utils/unit_conversion.dart';
import '../../../stock/presentation/stock_detail_page.dart';
import '../../../shopping/presentation/shopping_list_page.dart';

/// Low Stock Alerts Widget for Dashboard
/// Shows stock items that are below their threshold
/// With real-time updates via Supabase subscriptions and periodic refresh
class LowStockAlertsWidget extends StatefulWidget {
  const LowStockAlertsWidget({super.key});

  @override
  State<LowStockAlertsWidget> createState() => _LowStockAlertsWidgetState();
}

class _LowStockAlertsWidgetState extends State<LowStockAlertsWidget> {
  late final StockRepository _stockRepository;
  late final ShoppingCartRepository _cartRepository;
  late final PurchaseOrderRepository _poRepository;
  List<StockItem> _lowStockItems = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  
  // Real-time subscription
  StreamSubscription? _stockSubscription;

  @override
  void initState() {
    super.initState();
    _stockRepository = StockRepository(supabase);
    _cartRepository = ShoppingCartRepository();
    _poRepository = PurchaseOrderRepository(supabase);
    _loadLowStockItems();
    _setupRealtimeSubscription();
    // Removed periodic refresh - hanya guna real-time subscription
  }

  @override
  void dispose() {
    _stockSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Setup real-time subscription for stock_items table
  void _setupRealtimeSubscription() {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Subscribe to stock_items changes for current user only
      _stockSubscription = supabase
          .from('stock_items')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((data) {
            // Stock items updated - refresh low stock list with debounce
            if (mounted) {
              _debouncedRefresh();
            }
          });
    } catch (e) {
      // If real-time fails, periodic refresh will handle it
      debugPrint('Error setting up real-time subscription: $e');
    }
  }

  // Debounce refresh to avoid excessive updates
  Timer? _debounceTimer;
  void _debouncedRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadLowStockItems();
      }
    });
  }

  // Removed periodic refresh - hanya guna real-time subscription untuk avoid blinking

  // Track last refresh time to avoid excessive refreshes
  DateTime? _lastRefresh;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when page becomes visible (e.g., returning from PO page after receiving)
    // But only if it's been more than 1 second since last refresh
    final now = DateTime.now();
    if (_lastRefresh == null || now.difference(_lastRefresh!).inSeconds >= 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadLowStockItems();
          _lastRefresh = now;
        }
      });
    }
  }

  // Track if data is currently loading to prevent multiple simultaneous loads
  bool _isLoadingData = false;

  /// Calculate recommended quantity for purchase
  /// Returns quantity in base unit (not pek/pcs)
  double _calculateRecommendedQuantity(StockItem item) {
    final shortage = item.lowStockThreshold - item.currentQuantity;
    if (shortage <= 0) {
      // If already above threshold, recommend minimum 1 package
      return item.packageSize;
    }
    
    // Round up to nearest package
    final packagesNeeded = (shortage / item.packageSize).ceil();
    return packagesNeeded * item.packageSize; // Return in base unit
  }

  /// Calculate packages needed (pek/pcs)
  int _calculatePackagesNeeded(StockItem item) {
    final recommendedQty = _calculateRecommendedQuantity(item);
    return (recommendedQty / item.packageSize).ceil();
  }

  Future<void> _addAllToCart() async {
    if (_lowStockItems.isEmpty || _isProcessing) return;
    
    setState(() => _isProcessing = true);
    
    try {
      int successCount = 0;
      
      for (final item in _lowStockItems) {
        try {
          final recommendedQty = _calculateRecommendedQuantity(item);
          await _cartRepository.addToCart(
            stockItemId: item.id,
            shortageQty: recommendedQty,
            priority: 'high',
          );
          successCount++;
        } catch (e) {
          debugPrint('Error adding ${item.name} to cart: $e');
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successCount > 0
                  ? '✅ $successCount item ditambah ke senarai belian'
                  : '❌ Gagal menambah item',
            ),
            backgroundColor: successCount > 0 ? Colors.green : Colors.red,
          ),
        );
        
        // Navigate to shopping list
        if (successCount > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ShoppingListPage()),
          );
        }
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
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _createPOFromRecommendations() async {
    if (_lowStockItems.isEmpty || _isProcessing) return;
    
    setState(() => _isProcessing = true);
    
    try {
      // First, add all items to cart
      final cartItemIds = <String>[];
      
      for (final item in _lowStockItems) {
        try {
          final recommendedQty = _calculateRecommendedQuantity(item);
          final cartItem = await _cartRepository.addToCart(
            stockItemId: item.id,
            shortageQty: recommendedQty,
            priority: 'high',
          );
          cartItemIds.add(cartItem.id);
        } catch (e) {
          debugPrint('Error adding ${item.name} to cart: $e');
        }
      }
      
      if (cartItemIds.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Tiada item untuk buat PO'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Navigate to shopping list page where user can create PO
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ShoppingListPage(),
          ),
        ).then((_) => _loadLowStockItems());
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
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _shareToWhatsApp() async {
    if (_lowStockItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tiada cadangan pembelian'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final date = DateFormat('dd MMMM yyyy', 'ms_MY').format(DateTime.now());
    var message = '*CADANGAN PEMBELIAN*\n';
    message += 'Tarikh: $date\n\n';
    
    for (var i = 0; i < _lowStockItems.length; i++) {
      final item = _lowStockItems[i];
      final recommendedQty = _calculateRecommendedQuantity(item);
      final packagesNeeded = _calculatePackagesNeeded(item);
      
      message += '${i + 1}. ${item.name}\n';
      message += '   Kuantiti disyorkan: $packagesNeeded pek/pcs (${recommendedQty.toStringAsFixed(1)} ${item.unit})\n';
      if (item.purchasePrice > 0) {
        final estimatedCost = packagesNeeded * item.purchasePrice;
        message += '   Anggaran kos: RM ${estimatedCost.toStringAsFixed(2)}\n';
      }
      message += '\n';
    }
    
    message += '\nJumlah: ${_lowStockItems.length} item';
    
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

  Future<void> _loadLowStockItems() async {
    // Prevent multiple simultaneous loads
    if (_isLoadingData) return;
    
    _isLoadingData = true;
    try {
      final items = await _stockRepository.getLowStockItems();
      if (mounted) {
        setState(() {
          _lowStockItems = items.take(5).toList(); // Show top 5
          _isLoading = false;
          _isLoadingData = false;
        });
      } else {
        _isLoadingData = false;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingData = false;
        });
      } else {
        _isLoadingData = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildCard(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_lowStockItems.isEmpty) {
      return _buildCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: Colors.green[400],
              ),
              const SizedBox(height: 12),
              Text(
                'All Stock Levels Good!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'No low stock items',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Low Stock Alerts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Items need restocking',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_lowStockItems.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Low Stock Items List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _lowStockItems.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _lowStockItems[index];
              return _buildLowStockItem(item);
            },
          ),

          const Divider(height: 1),

          // Action Buttons (Purchase Recommendations)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _addAllToCart,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Tambah ke Senarai'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _createPOFromRecommendations,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.description, size: 18),
                    label: const Text('Buat PO'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareToWhatsApp,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: child,
    );
  }

  Widget _buildLowStockItem(StockItem item) {
    final isOutOfStock = item.currentQuantity <= 0;
    final stockPercentage = item.stockLevelPercentage.toStringAsFixed(0);
    final recommendedQty = _calculateRecommendedQuantity(item);
    final packagesNeeded = _calculatePackagesNeeded(item);
    final estimatedCost = packagesNeeded * item.purchasePrice;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StockDetailPage(stockItem: item),
          ),
        ).then((_) => _loadLowStockItems());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Status Indicator
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isOutOfStock ? Colors.red : Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),

            // Item Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        isOutOfStock ? Icons.error_outline : Icons.inventory_2_outlined,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOutOfStock
                            ? 'OUT OF STOCK'
                            : UnitConversion.formatQuantity(
                                item.currentQuantity,
                                item.unit,
                              ),
                        style: TextStyle(
                          fontSize: 12,
                          color: isOutOfStock ? Colors.red : Colors.grey[600],
                          fontWeight: isOutOfStock ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Recommended Purchase Quantity
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 12,
                        color: Colors.blue[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Cadangan: $packagesNeeded pek/pcs',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Stock Level & Recommended Quantity
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Stock Level Bar (if not out of stock)
                if (!isOutOfStock)
                  Container(
                    width: 60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$stockPercentage%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: item.stockLevelPercentage / 100,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              item.stockLevelPercentage < 50 ? Colors.red : Colors.orange,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Recommended Quantity
                const SizedBox(height: 4),
                Text(
                  '$packagesNeeded pek',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                if (item.purchasePrice > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'RM ${estimatedCost.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),

            // Out of Stock Badge
            if (isOutOfStock)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Text(
                  'OUT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

