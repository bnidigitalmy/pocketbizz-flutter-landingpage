import '../../core/supabase/supabase_client.dart';
import '../models/recipe.dart';
import '../models/recipe_item.dart';

class RecipesRepositorySupabase {
  // ============================================================================
  // RECIPES (Master recipe info)
  // ============================================================================

  /// Get all recipes for a product
  Future<List<Recipe>> getRecipesByProduct(String productId) async {
    final response = await supabase
        .from('recipes')
        .select()
        .eq('product_id', productId)
        .order('version', ascending: false);

    return (response as List)
        .map((json) => Recipe.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get active recipe for a product
  Future<Recipe?> getActiveRecipe(String productId) async {
    final response = await supabase
        .from('recipes')
        .select()
        .eq('product_id', productId)
        .eq('is_active', true)
        .maybeSingle();

    if (response == null) return null;
    return Recipe.fromJson(response as Map<String, dynamic>);
  }

  /// Get recipe by ID
  Future<Recipe?> getRecipeById(String recipeId) async {
    final response = await supabase
        .from('recipes')
        .select()
        .eq('id', recipeId)
        .maybeSingle();

    if (response == null) return null;
    return Recipe.fromJson(response as Map<String, dynamic>);
  }

  /// Create new recipe
  Future<Recipe> createRecipe({
    required String productId,
    required String name,
    String? description,
    required double yieldQuantity,
    required String yieldUnit,
    int? version,
    bool isActive = true,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    final response = await supabase
        .from('recipes')
        .insert({
      'business_owner_id': userId,
      'product_id': productId,
      'name': name,
      'description': description,
      'yield_quantity': yieldQuantity,
      'yield_unit': yieldUnit,
      'version': version ?? 1,
      'is_active': isActive,
    })
        .select()
        .single();

    return Recipe.fromJson(response as Map<String, dynamic>);
  }

  /// Update recipe
  Future<void> updateRecipe(String recipeId, Map<String, dynamic> updates) async {
    await supabase
        .from('recipes')
        .update(updates)
        .eq('id', recipeId);
  }

  /// Set recipe as active (and deactivate others for same product)
  Future<void> setActiveRecipe(String recipeId) async {
    // Get recipe info
    final recipe = await getRecipeById(recipeId);
    if (recipe == null) throw Exception('Recipe not found');

    // Deactivate all other recipes for this product
    await supabase
        .from('recipes')
        .update({'is_active': false})
        .eq('product_id', recipe.productId);

    // Activate this recipe
    await supabase
        .from('recipes')
        .update({'is_active': true})
        .eq('id', recipeId);
  }

  /// Delete recipe
  Future<void> deleteRecipe(String recipeId) async {
    await supabase
        .from('recipes')
        .delete()
        .eq('id', recipeId);
  }

  /// Duplicate recipe (create new version)
  Future<Recipe> duplicateRecipe(String recipeId) async {
    final userId = supabase.auth.currentUser!.id;

    // Get original recipe
    final original = await getRecipeById(recipeId);
    if (original == null) throw Exception('Recipe not found');

    // Get all recipe items
    final items = await getRecipeItems(recipeId);

    // Get max version for this product
    final allRecipes = await getRecipesByProduct(original.productId);
    final maxVersion = allRecipes.isEmpty ? 1 : allRecipes.map((r) => r.version).reduce((a, b) => a > b ? a : b);

    // Create new recipe (inactive by default)
    final newRecipe = await createRecipe(
      productId: original.productId,
      name: '${original.name} (Copy)',
      description: original.description,
      yieldQuantity: original.yieldQuantity,
      yieldUnit: original.yieldUnit,
      version: maxVersion + 1,
      isActive: false,
    );

    // Copy all recipe items
    for (final item in items) {
      await addRecipeItem(
        recipeId: newRecipe.id,
        stockItemId: item.stockItemId,
        quantityNeeded: item.quantityNeeded,
        usageUnit: item.usageUnit,
        position: item.position,
        notes: item.notes,
      );
    }

    return newRecipe;
  }

  // ============================================================================
  // RECIPE ITEMS (Ingredients list)
  // ============================================================================

  /// Get all items for a recipe
  Future<List<RecipeItem>> getRecipeItems(String recipeId) async {
    final response = await supabase
        .from('recipe_items')
        .select('''
          *,
          stock_items!inner(name)
        ''')
        .eq('recipe_id', recipeId)
        .order('position');

    return (response as List).map((json) {
      final item = RecipeItem.fromJson(json as Map<String, dynamic>);
      // Add stock item name from join
      final stockData = json['stock_items'];
      if (stockData != null) {
        item.stockItemName = stockData['name'] as String?;
      }
      return item;
    }).toList();
  }

  /// Add item to recipe
  Future<RecipeItem> addRecipeItem({
    required String recipeId,
    required String stockItemId,
    required double quantityNeeded,
    required String usageUnit,
    int position = 0,
    String? notes,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    // Get stock item cost (calculate from purchase_price and package_size)
    final stockResponse = await supabase
        .from('stock_items')
        .select('purchase_price, package_size')
        .eq('id', stockItemId)
        .single();

    final purchasePrice = (stockResponse['purchase_price'] as num).toDouble();
    final packageSize = (stockResponse['package_size'] as num).toDouble();
    
    // Calculate cost per unit: purchase_price / package_size
    // Example: RM21.90 / 500g = RM0.0438 per gram
    final costPerUnit = packageSize > 0 ? purchasePrice / packageSize : 0.0;
    final totalCost = quantityNeeded * costPerUnit;

    final response = await supabase
        .from('recipe_items')
        .insert({
      'business_owner_id': userId,
      'recipe_id': recipeId,
      'stock_item_id': stockItemId,
      'quantity_needed': quantityNeeded,
      'usage_unit': usageUnit,
      'cost_per_unit': costPerUnit,
      'total_cost': totalCost,
      'position': position,
      'notes': notes,
    })
        .select()
        .single();

    // Trigger will auto-calculate recipe cost
    return RecipeItem.fromJson(response as Map<String, dynamic>);
  }

  /// Update recipe item
  Future<void> updateRecipeItem(String itemId, Map<String, dynamic> updates) async {
    await supabase
        .from('recipe_items')
        .update(updates)
        .eq('id', itemId);
  }

  /// Delete recipe item
  Future<void> deleteRecipeItem(String itemId) async {
    await supabase
        .from('recipe_items')
        .delete()
        .eq('id', itemId);
    // Trigger will auto-update recipe cost
  }

  /// Recalculate recipe cost (call DB function)
  Future<double> recalculateRecipeCost(String recipeId) async {
    final response = await supabase
        .rpc('calculate_recipe_cost', params: {'recipe_uuid': recipeId});

    return (response as num).toDouble();
  }
}
