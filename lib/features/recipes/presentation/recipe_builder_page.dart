import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/unit_conversion.dart';
import '../../../core/widgets/stock_item_search_field.dart';
import '../../../data/repositories/recipes_repository_supabase.dart';
import '../../../data/repositories/stock_repository_supabase.dart' as stock_repo;
import '../../../data/models/recipe.dart';
import '../../../data/models/recipe_item.dart';
import '../../../data/models/stock_item.dart';
import '../../onboarding/presentation/widgets/contextual_tooltip.dart';
import '../../onboarding/data/tooltip_content.dart';
import '../../onboarding/services/tooltip_service.dart';

/// Enhanced Recipe Builder Page
/// User-friendly recipe management with search, edit, and stock info
class RecipeBuilderPage extends StatefulWidget {
  final String productId;
  final String productName;
  final String productUnit;

  const RecipeBuilderPage({
    super.key,
    required this.productId,
    required this.productName,
    required this.productUnit,
  });

  @override
  State<RecipeBuilderPage> createState() => _RecipeBuilderPageState();
}

class _RecipeBuilderPageState extends State<RecipeBuilderPage> {
  final _recipesRepo = RecipesRepositorySupabase();
  late final stock_repo.StockRepository _stockRepo;
  final _searchController = TextEditingController();
  
  Recipe? _activeRecipe;
  List<RecipeItem> _recipeItems = [];
  List<RecipeItem> _filteredItems = [];
  List<StockItem> _availableStock = [];
  Map<String, StockItem> _stockMap = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _stockRepo = stock_repo.StockRepository(supabase);
    _searchController.addListener(_onSearchChanged);
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTooltip();
    });
  }

  Future<void> _checkAndShowTooltip() async {
    final hasData = _recipeItems.isNotEmpty;
    
    final shouldShow = await TooltipHelper.shouldShowTooltip(
      context,
      TooltipKeys.recipes,
      checkEmptyState: !hasData,
      emptyStateChecker: () => !hasData,
    );
    
    if (shouldShow && mounted) {
      final content = hasData ? TooltipContent.recipes : TooltipContent.recipesEmpty;
      await TooltipHelper.showTooltip(
        context,
        content.moduleKey,
        content.title,
        content.message,
      );
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredItems = List.from(_recipeItems);
    } else {
      _filteredItems = _recipeItems.where((item) {
        final name = item.stockItemName?.toLowerCase() ?? '';
        return name.contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Get active recipe for this product
      _activeRecipe = await _recipesRepo.getActiveRecipe(widget.productId);
      
      // If no recipe exists, create one
      if (_activeRecipe == null) {
        _activeRecipe = await _createDefaultRecipe();
      }
      
      // Get recipe items
      if (_activeRecipe != null) {
        _recipeItems = await _recipesRepo.getRecipeItems(_activeRecipe!.id);
        _applyFilter();
      }
      
      // Get all stock items
      _availableStock = await _stockRepo.getAllStockItems(limit: 100);
      _stockMap = {for (var stock in _availableStock) stock.id: stock};

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat memuatkan data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<Recipe> _createDefaultRecipe() async {
    return await _recipesRepo.createRecipe(
      productId: widget.productId,
      name: '${widget.productName} Recipe',
      yieldQuantity: 1,
      yieldUnit: widget.productUnit,
    );
  }

  Future<void> _addIngredient() async {
    if (_activeRecipe == null) return;
    _showIngredientSelector();
  }

  void _showIngredientSelector() {
    final searchController = TextEditingController();
    List<StockItem> filteredStock = List.from(_availableStock);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          String searchQuery = '';

          void updateFilter(String query) {
            setModalState(() {
              searchQuery = query;
              if (query.isEmpty) {
                filteredStock = List.from(_availableStock);
              } else {
                final lowerQuery = query.toLowerCase();
                filteredStock = _availableStock.where((stock) {
                  return stock.name.toLowerCase().contains(lowerQuery);
                }).toList();
              }
            });
          }

          return DraggableScrollableSheet(
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
                            Icons.restaurant_menu,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Pilih Bahan',
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
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari bahan...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchController.clear();
                                  updateFilter('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onChanged: updateFilter,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  // Stock Items List
                  Expanded(
                    child: filteredStock.isEmpty
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
                                  searchQuery.isNotEmpty
                                      ? 'Tiada bahan ditemui'
                                      : 'Tiada bahan tersedia',
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
                            itemCount: filteredStock.length,
                            itemBuilder: (context, index) {
                              final stock = filteredStock[index];
                              final isAvailable = stock.currentQuantity > 0;
                              final costPerUnit = stock.costPerUnit;
                              final packageInfo = '${stock.packageSize}${stock.unit} @ RM${stock.purchasePrice.toStringAsFixed(2)}';

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isAvailable
                                        ? Colors.grey[200]!
                                        : Colors.red[200]!,
                                    width: 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: isAvailable
                                      ? () {
                                          Navigator.pop(context);
                                          _showQuantityDialog(stock);
                                        }
                                      : null,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Stock Icon
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: isAvailable
                                                ? Colors.green[50]
                                                : Colors.red[50],
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isAvailable
                                                  ? Colors.green[200]!
                                                  : Colors.red[200]!,
                                              width: 1,
                                            ),
                                          ),
                                          child: Icon(
                                            isAvailable
                                                ? Icons.inventory_2
                                                : Icons.warning_amber_rounded,
                                            color: isAvailable
                                                ? Colors.green[600]
                                                : Colors.orange[600],
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Stock Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                stock.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
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
                                                      'RM${costPerUnit.toStringAsFixed(4)}/${stock.unit}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                        color: Colors.blue[700],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
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
                                                    child: Text(
                                                      'Stok: ${stock.currentQuantity.toStringAsFixed(1)}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                        color: isAvailable
                                                            ? Colors.green[700]
                                                            : Colors.red[700],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                packageInfo,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Add Icon
                                        if (isAvailable)
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
          );
        },
      ),
    );
  }

  void _showQuantityDialog(StockItem stock) {
    final quantityController = TextEditingController(text: '1');
    final unitController = TextEditingController(text: stock.unit);
    List<String> compatibleUnits = UnitConversion.getCompatibleUnits(stock.unit)
      ..sort();
    if (!compatibleUnits.map((u) => u.toLowerCase()).contains(stock.unit.toLowerCase())) {
      compatibleUnits.insert(0, stock.unit);
    }

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
                const Icon(Icons.add_circle, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stock.name,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Kuantiti',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: unitController.text.trim(),
                    decoration: const InputDecoration(
                      labelText: 'Unit Resepi',
                      border: OutlineInputBorder(),
                      helperText: 'Unit mesti serasi dengan unit stok bahan.',
                    ),
                    items: compatibleUnits
                        .map(
                          (u) => DropdownMenuItem<String>(
                            value: u,
                            child: Text(u),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        unitController.text = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Stok tersedia: ${stock.currentQuantity.toStringAsFixed(1)} ${stock.unit}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
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
                onPressed: () {
                  final quantity = double.tryParse(quantityController.text) ?? 0.0;
                  if (quantity <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kuantiti mesti lebih daripada 0'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  _addIngredientToRecipe(stock, quantity, unitController.text.trim());
                },
                child: const Text('Tambah'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addIngredientToRecipe(StockItem stock, double quantity, String unit) async {
    if (_activeRecipe == null) return;

    try {
      await _recipesRepo.addRecipeItem(
        recipeId: _activeRecipe!.id,
        stockItemId: stock.id,
        quantityNeeded: quantity,
        usageUnit: unit,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Bahan berjaya ditambah'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editIngredient(RecipeItem item) async {
    final stock = _stockMap[item.stockItemId];
    if (stock == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddIngredientDialog(
        availableStock: _availableStock,
        initialStock: stock,
        initialQuantity: item.quantityNeeded,
        initialUnit: item.usageUnit,
        isEdit: true,
      ),
    );

    if (result != null && mounted) {
      final quantity = result['quantity'] as double;
      final unit = result['unit'] as String;

      try {
        // Recalculate cost using unit conversion:
        // total_cost = (quantity converted to stock.unit) * stock.costPerUnit
        if (unit.toLowerCase().trim() != stock.unit.toLowerCase().trim() &&
            !UnitConversion.canConvert(unit, stock.unit)) {
          throw Exception(
            'Unit tidak serasi. Resepi: "$unit", Stok: "${stock.unit}". '
            'Sila pilih unit yang serasi (contoh ml↔liter, g↔kg).',
          );
        }

        final convertedQty = UnitConversion.convert(
          quantity: quantity,
          fromUnit: unit,
          toUnit: stock.unit,
        );
        final costPerUnit = stock.costPerUnit; // cost per stock.unit
        final totalCost = convertedQty * costPerUnit;

        await _recipesRepo.updateRecipeItem(item.id, {
          'quantity_needed': quantity,
          'usage_unit': unit,
          'cost_per_unit': costPerUnit,
          'total_cost': totalCost,
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Bahan berjaya dikemaskini'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ralat: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteIngredient(RecipeItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam Bahan?'),
        content: Text('Adakah anda pasti mahu memadam "${item.stockItemName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Padam'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _recipesRepo.deleteRecipeItem(item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Bahan berjaya dipadam'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ralat: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _recalculateAllCosts() async {
    if (_activeRecipe == null) return;

    setState(() => _isLoading = true);
    int updated = 0;
    int skipped = 0;

    try {
      for (final item in _recipeItems) {
        final stock = _stockMap[item.stockItemId];
        if (stock == null) {
          skipped++;
          continue;
        }

        final usageUnit = item.usageUnit.trim();
        final stockUnit = stock.unit.trim();

        if (usageUnit.toLowerCase() != stockUnit.toLowerCase() &&
            !UnitConversion.canConvert(usageUnit, stockUnit)) {
          skipped++;
          continue;
        }

        final convertedQty = UnitConversion.convert(
          quantity: item.quantityNeeded,
          fromUnit: usageUnit,
          toUnit: stockUnit,
        );

        final costPerUnit = stock.costPerUnit;
        final totalCost = convertedQty * costPerUnit;

        final shouldUpdate = (totalCost - item.totalCost).abs() >= 0.01 ||
            (costPerUnit - item.costPerUnit).abs() >= 0.0001;

        if (shouldUpdate) {
          await _recipesRepo.updateRecipeItem(item.id, {
            'cost_per_unit': costPerUnit,
            'total_cost': totalCost,
            'updated_at': DateTime.now().toIso8601String(),
          });
          updated++;
        }
      }

      // Update recipe rollups (materials_cost/total_cost/cost_per_unit) in DB
      await _recipesRepo.recalculateRecipeCost(_activeRecipe!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Recalculate siap. Updated: $updated, Skipped: $skipped'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat recalculate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resipi'),
            Text(
              widget.productName,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Recalculate Kos',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _recalculateAllCosts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_activeRecipe != null) _buildSummaryCard(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                    _buildIngredientsList(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addIngredient,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Bahan'),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.1),
              AppColors.primary.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _activeRecipe!.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Hasil',
                    '${_activeRecipe!.yieldQuantity} ${_activeRecipe!.yieldUnit}',
                    Icons.inventory_2,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Jumlah Kos',
                    'RM${_activeRecipe!.totalCost.toStringAsFixed(2)}',
                    Icons.attach_money,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Kos Seunit',
                    'RM${_activeRecipe!.costPerUnit.toStringAsFixed(2)}',
                    Icons.calculate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Cari bahan...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _searchController.clear(),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildIngredientsList() {
    if (_filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_filteredItems.length} bahan',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredItems.length,
          itemBuilder: (context, index) {
            final item = _filteredItems[index];
            return _buildIngredientCard(item);
          },
        ),
      ],
    );
  }

  Widget _buildIngredientCard(RecipeItem item) {
    final stock = _stockMap[item.stockItemId];
    final isLowStock = stock?.isLowStock ?? false;
    final stockAvailable = stock?.currentQuantity ?? 0.0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isLowStock ? Colors.orange[200]! : Colors.grey[200]!,
          width: isLowStock ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Stock indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLowStock
                    ? Colors.orange[50]
                    : Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isLowStock ? Icons.warning : Icons.check_circle,
                color: isLowStock ? Colors.orange[700] : Colors.green[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Ingredient info
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.quantityNeeded} ${item.usageUnit}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.inventory_2, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Stok: ${stockAvailable.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isLowStock ? Colors.orange[700] : Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Cost
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'RM${item.totalCost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'RM${item.costPerUnit.toStringAsFixed(4)}/unit',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Actions
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Padam'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _editIngredient(item);
                } else if (value == 'delete') {
                  _deleteIngredient(item);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty
                ? 'Tiada bahan ditemui'
                : 'Tiada bahan lagi',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Cuba ubah carian anda'
                : 'Mula dengan menambah bahan pertama',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Dialog for adding/editing ingredients
class _AddIngredientDialog extends StatefulWidget {
  final List<StockItem> availableStock;
  final StockItem? initialStock;
  final double initialQuantity;
  final String initialUnit;
  final bool isEdit;

  const _AddIngredientDialog({
    required this.availableStock,
    this.initialStock,
    this.initialQuantity = 1.0,
    this.initialUnit = 'gram',
    this.isEdit = false,
  });

  @override
  State<_AddIngredientDialog> createState() => _AddIngredientDialogState();
}

class _AddIngredientDialogState extends State<_AddIngredientDialog> {
  StockItem? _selectedStock;
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  List<String> _compatibleUnits = const [];

  @override
  void initState() {
    super.initState();
    _selectedStock = widget.initialStock;
    _quantityController.text = widget.initialQuantity.toString();
    _unitController.text = widget.initialUnit;
    _updateCompatibleUnits();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _updateCompatibleUnits() {
    final stock = _selectedStock;
    if (stock == null) {
      setState(() => _compatibleUnits = const []);
      return;
    }

    final units = UnitConversion.getCompatibleUnits(stock.unit)..sort();
    final normalized = units.map((u) => u.toLowerCase()).toSet();

    if (!normalized.contains(stock.unit.toLowerCase())) {
      units.insert(0, stock.unit);
    }

    final current = _unitController.text.trim();
    final currentOk =
        current.isNotEmpty && units.map((u) => u.toLowerCase()).contains(current.toLowerCase());
    if (!currentOk) {
      _unitController.text = stock.unit;
    }

    setState(() => _compatibleUnits = units);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(widget.isEdit ? 'Edit Bahan' : 'Tambah Bahan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StockItemSearchField(
              items: widget.availableStock,
              value: _selectedStock,
              labelText: 'Cari & Pilih Bahan',
              helperText: 'Taip nama bahan untuk cari cepat (tak perlu scroll panjang).',
              onChanged: (value) {
                setState(() => _selectedStock = value);
                _updateCompatibleUnits();
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Kuantiti',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _compatibleUnits.isEmpty ? null : _unitController.text.trim(),
              decoration: const InputDecoration(
                labelText: 'Unit Resepi',
                border: OutlineInputBorder(),
                helperText: 'Unit mesti serasi dengan unit stok bahan (weight/volume/count).',
              ),
              items: _compatibleUnits
                  .map(
                    (u) => DropdownMenuItem<String>(
                      value: u,
                      child: Text(u),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _unitController.text = value);
              },
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Sila pilih unit' : null,
            ),
            if (_selectedStock != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stok tersedia: ${_selectedStock!.currentQuantity.toStringAsFixed(1)} ${_selectedStock!.unit}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _selectedStock == null
              ? null
              : () {
                  final quantity = double.tryParse(_quantityController.text) ?? 0.0;
                  if (quantity <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kuantiti mesti lebih daripada 0'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'stock': _selectedStock,
                    'quantity': quantity,
                    'unit': _unitController.text.trim(),
                  });
                },
          child: Text(widget.isEdit ? 'Kemaskini' : 'Tambah'),
        ),
      ],
    );
  }
}
