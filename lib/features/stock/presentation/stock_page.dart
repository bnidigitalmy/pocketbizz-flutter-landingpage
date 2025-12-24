import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart' show supabase;
import '../../../data/repositories/stock_repository_supabase.dart';
import '../../../data/models/stock_item.dart';
import '../../../core/utils/unit_conversion.dart';
import '../../../core/utils/stock_export_import.dart';
import 'add_edit_stock_item_page.dart';
import 'stock_detail_page.dart';
import 'stock_history_page.dart';
import 'widgets/replenish_stock_dialog.dart';
import 'widgets/smart_filters_widget.dart';
import 'widgets/shopping_list_dialog.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../../onboarding/presentation/widgets/contextual_tooltip.dart';
import '../../onboarding/data/tooltip_content.dart';
import '../../onboarding/services/tooltip_service.dart';

/// Stock Management Page - List all stock items
class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  late final StockRepository _stockRepository;
  List<StockItem> _stockItems = [];
  List<StockItem> _filteredItems = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _showOnlyLowStock = false;
  bool _isExporting = false;
  Map<String, Map<String, dynamic>> _batchSummaries = {}; // stockItemId -> summary
  
  // Smart Filters state
  final Map<String, bool> _quickFilters = {
    'lowStock': false,
    'outOfStock': false,
    'inStock': false,
  };

  // Selection mode state
  bool _isSelectionMode = false;
  final Set<String> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    _stockRepository = StockRepository(supabase);
    _loadStockItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTooltip();
    });
  }

  Future<void> _checkAndShowTooltip() async {
    final hasData = _stockItems.isNotEmpty;
    
    final shouldShow = await TooltipHelper.shouldShowTooltip(
      context,
      TooltipKeys.inventory,
      checkEmptyState: !hasData,
      emptyStateChecker: () => !hasData,
    );
    
    if (shouldShow && mounted) {
      final content = hasData ? TooltipContent.inventory : TooltipContent.inventoryEmpty;
      await TooltipHelper.showTooltip(
        context,
        content.moduleKey,
        content.title,
        content.message,
      );
    }
  }

  Future<void> _loadStockItems() async {
    setState(() => _isLoading = true);

    try {
      final items = await _stockRepository.getAllStockItems(limit: 100);
      
      // Load batch summaries for all items
      final summaries = <String, Map<String, dynamic>>{};
      for (final item in items) {
        try {
          final summary = await _stockRepository.getBatchSummary(item.id);
          summaries[item.id] = summary;
        } catch (e) {
          // Ignore errors for batch summary (might not have batches)
          summaries[item.id] = {
            'total_batches': 0,
            'expired_batches': 0,
            'earliest_expiry': null,
          };
        }
      }
      
      setState(() {
        _stockItems = items;
        _filteredItems = items;
        _batchSummaries = summaries;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredItems = _stockItems.where((item) {
        // Search filter
        final matchesSearch = _searchQuery.isEmpty ||
            item.name.toLowerCase().contains(_searchQuery.toLowerCase());

        // Quick filters
        if (_quickFilters['lowStock'] == true && !item.isLowStock) return false;
        if (_quickFilters['outOfStock'] == true && item.currentQuantity > 0) return false;
        if (_quickFilters['inStock'] == true && item.currentQuantity <= 0) return false;

        return matchesSearch;
      }).toList();
    });
  }

  void _toggleQuickFilter(String key) {
    setState(() {
      _quickFilters[key] = !(_quickFilters[key] ?? false);
    });
    _applyFilters();
  }

  void _clearAllFilters() {
    setState(() {
      _quickFilters.updateAll((key, value) => false);
      _searchQuery = '';
    });
    _applyFilters();
  }

  Future<void> _handleExportExcel() async {
    setState(() => _isExporting = true);
    
    try {
      final filePath = await StockExportImport.exportToExcel(_stockItems);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Exported to: $filePath'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _handleExportCSV() async {
    setState(() => _isExporting = true);
    
    try {
      final filePath = await StockExportImport.exportToCSV(_stockItems);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Exported to: $filePath'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _handleImport() async {
    try {
      final filePath = await StockExportImport.pickFile();
      if (filePath == null) return;

      // Parse file
      List<Map<String, dynamic>> data;
      if (filePath.endsWith('.csv')) {
        data = await StockExportImport.parseCSVFile(filePath);
      } else {
        data = await StockExportImport.parseExcelFile(filePath);
      }

      // Validate
      final validation = StockExportImport.validateImportData(data);
      
      if (!validation['valid']) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Validation Errors'),
              content: SingleChildScrollView(
                child: Text(validation['errors'].join('\n')),
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
        return;
      }

      // Import to database
      setState(() => _isLoading = true);
      
      try {
        final result = await _stockRepository.bulkImportStockItems(data);
        
        if (mounted) {
          setState(() => _isLoading = false);
          
          if (result['success'] == true) {
            final successCount = result['successCount'] as int;
            final failureCount = result['failureCount'] as int;
            final errors = result['errors'] as List<String>;
            
            // Show result dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Import Results'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('✅ Success: $successCount items'),
                      Text('❌ Failed: $failureCount items'),
                      if (errors.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Errors:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...errors.take(10).map((error) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            error,
                            style: const TextStyle(fontSize: 12),
                          ),
                        )),
                        if (errors.length > 10)
                          Text('... and ${errors.length - 10} more errors'),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _loadStockItems();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Import failed: ${result['error']}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error importing: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showReplenishDialog(StockItem item) {
    showDialog(
      context: context,
      builder: (context) => ReplenishStockDialog(
        stockItem: item,
        onSuccess: _loadStockItems,
      ),
    );
  }

  void _navigateToHistory(StockItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StockHistoryPage(stockItemId: item.id),
      ),
    );
  }

  // Selection mode methods
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedItemIds.clear();
      }
    });
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
      } else {
        _selectedItemIds.add(itemId);
      }
    });
  }

  void _selectAllLowStock() {
    setState(() {
      _selectedItemIds.clear();
      _selectedItemIds.addAll(
        _filteredItems.where((item) => item.isLowStock).map((item) => item.id),
      );
    });
  }

  void _selectAllFiltered() {
    setState(() {
      _selectedItemIds.clear();
      _selectedItemIds.addAll(_filteredItems.map((item) => item.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedItemIds.clear();
    });
  }

  void _showShoppingListDialog() {
    if (_selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sila pilih item terlebih dahulu')),
      );
      return;
    }

    final selectedItems = _stockItems
        .where((item) => _selectedItemIds.contains(item.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) => ShoppingListDialog(
        selectedItems: selectedItems,
        onSuccess: () {
          setState(() {
            _isSelectionMode = false;
            _selectedItemIds.clear();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lowStockCount = _stockItems.where((item) => item.isLowStock).length;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isSelectionMode ? 'Pilih Item' : 'Stok Gudang'),
            Text(
              _isSelectionMode
                  ? '${_selectedItemIds.length} dipilih'
                  : '${_filteredItems.length} item',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: _isSelectionMode
            ? [
                // Select All Low Stock
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'all') _selectAllFiltered();
                    if (value == 'low') _selectAllLowStock();
                    if (value == 'clear') _clearSelection();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'all',
                      child: Row(
                        children: [
                          Icon(Icons.select_all, size: 20),
                          SizedBox(width: 8),
                          Text('Pilih Semua'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'low',
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, size: 20, color: AppColors.warning),
                          SizedBox(width: 8),
                          Text('Pilih Stok Rendah'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.clear, size: 20),
                          SizedBox(width: 8),
                          Text('Kosongkan'),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : [
                // Selection Mode Toggle
                IconButton(
                  icon: const Icon(Icons.check_box_outlined),
                  onPressed: _toggleSelectionMode,
                  tooltip: 'Mode Pilihan',
                ),
                // Export Excel
                IconButton(
                  icon: const Icon(Icons.table_chart),
                  onPressed: _isExporting ? null : _handleExportExcel,
                  tooltip: 'Export Excel',
                ),
                // Export CSV
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: _isExporting ? null : _handleExportCSV,
                  tooltip: 'Export CSV',
                ),
                // Import
                IconButton(
                  icon: const Icon(Icons.upload),
                  onPressed: _handleImport,
                  tooltip: 'Import',
                ),
              ],
      ),
      body: Column(
        children: [
          // Low Stock Alert
          if (lowStockCount > 0)
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.warning.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '⚠️ $lowStockCount item stok rendah!',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Smart Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SmartFiltersWidget(
              quickFilters: _quickFilters,
              onQuickFilterToggle: _toggleQuickFilter,
              searchQuery: _searchQuery,
              onSearchChanged: (value) {
                setState(() => _searchQuery = value);
                _applyFilters();
              },
              onClearAll: _clearAllFilters,
            ),
          ),
          
          const Divider(height: 1),

          // Stock Stats
          _buildStockStats(),

          // Stock List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadStockItems,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            return _buildStockItemCard(_filteredItems[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode && _selectedItemIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showShoppingListDialog,
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.shopping_cart),
              label: Text('Tambah ${_selectedItemIds.length} ke Senarai'),
            )
          : FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddEditStockItemPage(),
                  ),
                );
                if (result == true) _loadStockItems();
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Item'),
            ),
    );
  }

  Widget _buildStockStats() {
    final lowStockCount = _stockItems.where((item) => item.isLowStock).length;
    final outOfStockCount =
        _stockItems.where((item) => item.currentQuantity <= 0).length;
    final totalValue = _stockItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.currentQuantity * item.costPerUnit),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Items',
              '${_stockItems.length}',
              Icons.inventory_2,
              AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Low Stock',
              '$lowStockCount',
              Icons.warning_amber_rounded,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Out of Stock',
              '$outOfStockCount',
              Icons.error_outline,
              Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStockItemCard(StockItem item) {
    final isLowStock = item.isLowStock;
    final isOutOfStock = item.currentQuantity <= 0;
    final isSelected = _selectedItemIds.contains(item.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: _isSelectionMode && isSelected
            ? BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () async {
          if (_isSelectionMode) {
            _toggleItemSelection(item.id);
          } else {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StockDetailPage(stockItem: item),
              ),
            );
            if (result == true) _loadStockItems();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Checkbox (selection mode)
                  if (_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleItemSelection(item.id),
                        activeColor: AppColors.primary,
                      ),
                    ),

                  // Status indicator
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? Colors.red
                          : isLowStock
                              ? Colors.orange
                              : Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Item name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (item.notes != null)
                          Text(
                            item.notes!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // Action Buttons (hidden in selection mode)
                  if (!_isSelectionMode)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // History
                        IconButton(
                          icon: const Icon(Icons.history, size: 20),
                          onPressed: () => _navigateToHistory(item),
                          tooltip: 'Sejarah',
                          color: Colors.blue,
                        ),
                        // Replenish
                        IconButton(
                          icon: const Icon(Icons.add_circle, size: 20),
                          onPressed: () => _showReplenishDialog(item),
                          tooltip: 'Tambah Stok',
                          color: AppColors.success,
                        ),
                        // Edit
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AddEditStockItemPage(stockItem: item),
                              ),
                            );
                            if (result == true) _loadStockItems();
                          },
                          tooltip: 'Edit',
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Stock info
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      'Current Stock',
                      UnitConversion.formatQuantity(
                        item.currentQuantity,
                        item.unit,
                      ),
                      Icons.inventory,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      'Cost/Unit',
                      'RM ${item.costPerUnit.toStringAsFixed(4)}',
                      Icons.attach_money,
                    ),
                  ),
                ],
              ),

              if (isLowStock) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isOutOfStock
                        ? Colors.red.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOutOfStock ? Icons.error : Icons.warning_amber_rounded,
                        size: 16,
                        color: isOutOfStock ? Colors.red : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOutOfStock
                            ? 'OUT OF STOCK!'
                            : 'Low stock (${item.stockLevelPercentage.toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOutOfStock ? Colors.red : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Batch Expiry Alerts
              if (_batchSummaries.containsKey(item.id)) ...[
                _buildBatchExpiryAlert(item),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchExpiryAlert(StockItem item) {
    final summary = _batchSummaries[item.id];
    if (summary == null) return const SizedBox.shrink();

    final expiredCount = summary['expired_batches'] ?? 0;
    final earliestExpiry = summary['earliest_expiry'] as DateTime?;
    final totalBatches = summary['total_batches'] ?? 0;

    if (totalBatches == 0) return const SizedBox.shrink();

    final isExpired = earliestExpiry != null && earliestExpiry.isBefore(DateTime.now());
    final isExpiringSoon = earliestExpiry != null &&
        !isExpired &&
        earliestExpiry.difference(DateTime.now()).inDays <= 7;

    if (expiredCount == 0 && !isExpiringSoon) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: expiredCount > 0
                ? Colors.red.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                expiredCount > 0 ? Icons.error : Icons.event_busy,
                size: 16,
                color: expiredCount > 0 ? Colors.red : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (expiredCount > 0)
                      Text(
                        '⚠️ $expiredCount batch expired',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (isExpiringSoon && expiredCount == 0)
                      Text(
                        '⏰ Expires ${DateFormat('dd MMM').format(earliestExpiry!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No stock items yet'
                : 'No items found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Add your first stock item to get started'
                : 'Try a different search term',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

