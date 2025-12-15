/// Unit Conversion System for Stock Management
/// Converts between different measurement units for recipe calculations
/// 
/// Factor represents: 1 [fromUnit] = factor × [toUnit]
/// Example: 1 kg = 1000 gram, so kg→gram factor is 1000
library;

/// Supported unit conversion mappings
/// Each unit maps to other units with conversion factors
class UnitConversion {
  // Weight conversions (expanded)
  static const Map<String, Map<String, double>> weightConversions = {
    // Metric
    'kg': {'kg': 1.0, 'kilogram': 1.0, 'gram': 1000.0, 'g': 1000.0, 'mg': 1000000.0, 'oz': 35.274, 'lb': 2.20462, 'pound': 2.20462},
    'kilogram': {'kg': 1.0, 'kilogram': 1.0, 'gram': 1000.0, 'g': 1000.0, 'mg': 1000000.0, 'oz': 35.274, 'lb': 2.20462, 'pound': 2.20462},
    'gram': {'kg': 0.001, 'kilogram': 0.001, 'gram': 1.0, 'g': 1.0, 'mg': 1000.0, 'oz': 0.035274, 'lb': 0.00220462, 'pound': 0.00220462},
    'g': {'kg': 0.001, 'kilogram': 0.001, 'gram': 1.0, 'g': 1.0, 'mg': 1000.0, 'oz': 0.035274, 'lb': 0.00220462, 'pound': 0.00220462},
    'mg': {'kg': 0.000001, 'kilogram': 0.000001, 'gram': 0.001, 'g': 0.001, 'mg': 1.0, 'oz': 0.000035274, 'lb': 0.00000220462, 'pound': 0.00000220462},
    // Imperial
    'oz': {'kg': 0.0283495, 'kilogram': 0.0283495, 'gram': 28.3495, 'g': 28.3495, 'mg': 28349.5, 'oz': 1.0, 'lb': 0.0625, 'pound': 0.0625},
    'lb': {'kg': 0.453592, 'kilogram': 0.453592, 'gram': 453.592, 'g': 453.592, 'mg': 453592.0, 'oz': 16.0, 'lb': 1.0, 'pound': 1.0},
    'pound': {'kg': 0.453592, 'kilogram': 0.453592, 'gram': 453.592, 'g': 453.592, 'mg': 453592.0, 'oz': 16.0, 'lb': 1.0, 'pound': 1.0},
  };

  // Volume conversions (expanded)
  static const Map<String, Map<String, double>> volumeConversions = {
    // Metric
    'liter': {'liter': 1.0, 'l': 1.0, 'ml': 1000.0, 'milliliter': 1000.0, 'cup': 4.22675, 'tbsp': 66.67, 'tsp': 200.0, 'floz': 33.814, 'pint': 2.11338, 'quart': 1.05669, 'gallon': 0.264172},
    'l': {'liter': 1.0, 'l': 1.0, 'ml': 1000.0, 'milliliter': 1000.0, 'cup': 4.22675, 'tbsp': 66.67, 'tsp': 200.0, 'floz': 33.814, 'pint': 2.11338, 'quart': 1.05669, 'gallon': 0.264172},
    'ml': {'liter': 0.001, 'l': 0.001, 'ml': 1.0, 'milliliter': 1.0, 'cup': 0.00422675, 'tbsp': 0.0667, 'tsp': 0.2, 'floz': 0.033814, 'pint': 0.00211338, 'quart': 0.00105669, 'gallon': 0.000264172},
    'milliliter': {'liter': 0.001, 'l': 0.001, 'ml': 1.0, 'milliliter': 1.0, 'cup': 0.00422675, 'tbsp': 0.0667, 'tsp': 0.2, 'floz': 0.033814, 'pint': 0.00211338, 'quart': 0.00105669, 'gallon': 0.000264172},
    // Cooking measurements
    'cup': {'liter': 0.236588, 'l': 0.236588, 'ml': 236.588, 'milliliter': 236.588, 'cup': 1.0, 'tbsp': 16.0, 'tsp': 48.0, 'floz': 8.0, 'pint': 0.5, 'quart': 0.25, 'gallon': 0.0625},
    'tbsp': {'liter': 0.0147868, 'l': 0.0147868, 'ml': 14.7868, 'milliliter': 14.7868, 'cup': 0.0625, 'tbsp': 1.0, 'tsp': 3.0, 'floz': 0.5, 'pint': 0.03125, 'quart': 0.015625, 'gallon': 0.00390625},
    'tsp': {'liter': 0.00492892, 'l': 0.00492892, 'ml': 4.92892, 'milliliter': 4.92892, 'cup': 0.0208333, 'tbsp': 0.333333, 'tsp': 1.0, 'floz': 0.166667, 'pint': 0.0104167, 'quart': 0.00520833, 'gallon': 0.00130208},
    // Imperial
    'floz': {'liter': 0.0295735, 'l': 0.0295735, 'ml': 29.5735, 'milliliter': 29.5735, 'cup': 0.125, 'tbsp': 2.0, 'tsp': 6.0, 'floz': 1.0, 'pint': 0.0625, 'quart': 0.03125, 'gallon': 0.0078125},
    'pint': {'liter': 0.473176, 'l': 0.473176, 'ml': 473.176, 'milliliter': 473.176, 'cup': 2.0, 'tbsp': 32.0, 'tsp': 96.0, 'floz': 16.0, 'pint': 1.0, 'quart': 0.5, 'gallon': 0.125},
    'quart': {'liter': 0.946353, 'l': 0.946353, 'ml': 946.353, 'milliliter': 946.353, 'cup': 4.0, 'tbsp': 64.0, 'tsp': 192.0, 'floz': 32.0, 'pint': 2.0, 'quart': 1.0, 'gallon': 0.25},
    'gallon': {'liter': 3.78541, 'l': 3.78541, 'ml': 3785.41, 'milliliter': 3785.41, 'cup': 16.0, 'tbsp': 256.0, 'tsp': 768.0, 'floz': 128.0, 'pint': 8.0, 'quart': 4.0, 'gallon': 1.0},
  };

  // Count conversions (expanded)
  static const Map<String, Map<String, double>> countConversions = {
    // Eggs / local aliases
    // "biji" is treated as 1 piece
    // "papan/sarang/tray" is treated as 30 pieces (common egg tray)
    'biji': {'biji': 1.0, 'pcs': 1.0, 'pieces': 1.0, 'unit': 1.0, 'units': 1.0, 'dozen': 0.0833, 'papan': 0.0333333, 'sarang': 0.0333333, 'tray': 0.0333333},
    'papan': {'papan': 1.0, 'sarang': 1.0, 'tray': 1.0, 'biji': 30.0, 'pcs': 30.0, 'pieces': 30.0, 'unit': 30.0, 'units': 30.0, 'dozen': 2.5},
    'sarang': {'papan': 1.0, 'sarang': 1.0, 'tray': 1.0, 'biji': 30.0, 'pcs': 30.0, 'pieces': 30.0, 'unit': 30.0, 'units': 30.0, 'dozen': 2.5},
    'tray': {'papan': 1.0, 'sarang': 1.0, 'tray': 1.0, 'biji': 30.0, 'pcs': 30.0, 'pieces': 30.0, 'unit': 30.0, 'units': 30.0, 'dozen': 2.5},

    'dozen': {'dozen': 1.0, 'pcs': 12.0, 'pieces': 12.0, 'unit': 12.0, 'units': 12.0},
    'pcs': {'dozen': 0.0833, 'pcs': 1.0, 'pieces': 1.0, 'unit': 1.0, 'units': 1.0},
    'pieces': {'dozen': 0.0833, 'pcs': 1.0, 'pieces': 1.0, 'unit': 1.0, 'units': 1.0},
    'unit': {'dozen': 0.0833, 'pcs': 1.0, 'pieces': 1.0, 'unit': 1.0, 'units': 1.0},
    'units': {'dozen': 0.0833, 'pcs': 1.0, 'pieces': 1.0, 'unit': 1.0, 'units': 1.0},
  };

  // All conversions combined
  static const Map<String, Map<String, double>> allConversions = {
    ...weightConversions,
    ...volumeConversions,
    ...countConversions,
  };

  /// Convert quantity from one unit to another
  /// 
  /// Returns converted quantity, or original quantity if conversion not possible
  /// Logs warnings in debug mode for missing conversions
  static double convert({
    required double quantity,
    required String fromUnit,
    required String toUnit,
  }) {
    final from = fromUnit.toLowerCase().trim();
    final to = toUnit.toLowerCase().trim();

    // If units are the same, no conversion needed
    if (from == to) return quantity;

    // Check if conversion exists
    if (!allConversions.containsKey(from)) {
      _logWarning(
        '⚠️ Unit conversion warning: Unknown source unit "$fromUnit". '
        'Returning original quantity. This may cause incorrect cost calculations!'
      );
      return quantity;
    }

    if (!allConversions[from]!.containsKey(to)) {
      _logWarning(
        '⚠️ Unit conversion warning: Cannot convert from "$fromUnit" to "$toUnit". '
        'Incompatible units! Returning original quantity. '
        'This WILL cause incorrect cost calculations!'
      );
      return quantity;
    }

    // Convert: multiply by conversion factor
    final factor = allConversions[from]![to]!;
    final converted = quantity * factor;

    // Log conversion for debugging (only in debug mode)
    _logDebug(
      '🔄 Unit conversion: $quantity $fromUnit → ${converted.toStringAsFixed(4)} $toUnit'
    );

    return converted;
  }

  /// Check if conversion is possible between two units
  static bool canConvert(String fromUnit, String toUnit) {
    final from = fromUnit.toLowerCase().trim();
    final to = toUnit.toLowerCase().trim();

    if (from == to) return true;

    return allConversions.containsKey(from) &&
           allConversions[from]!.containsKey(to);
  }

  /// Get all units that can be converted from the given unit
  static List<String> getCompatibleUnits(String unit) {
    final unitKey = unit.toLowerCase().trim();
    
    if (!allConversions.containsKey(unitKey)) {
      return [unit]; // Return original if not found
    }

    return allConversions[unitKey]!.keys.toList();
  }

  /// Get unit category (weight, volume, count)
  static String? getUnitCategory(String unit) {
    final unitKey = unit.toLowerCase().trim();

    if (weightConversions.containsKey(unitKey)) return 'weight';
    if (volumeConversions.containsKey(unitKey)) return 'volume';
    if (countConversions.containsKey(unitKey)) return 'count';

    return null;
  }

  /// Calculate cost per base unit
  /// 
  /// Example: Package of 500gram costs RM21.90
  /// Cost per gram = 21.90 / 500 = RM0.0438 per gram
  static double calculateCostPerUnit({
    required double packageSize,
    required String packageUnit,
    required double packagePrice,
    required String targetUnit,
  }) {
    // Convert package size to target unit
    final convertedSize = convert(
      quantity: packageSize,
      fromUnit: packageUnit,
      toUnit: targetUnit,
    );

    // Calculate cost per target unit
    return packagePrice / convertedSize;
  }

  /// Calculate total cost for a given quantity
  /// 
  /// Example: Need 250 grams, cost per gram is RM0.0438
  /// Total cost = 250 * 0.0438 = RM10.95
  static double calculateTotalCost({
    required double quantity,
    required String quantityUnit,
    required double costPerUnit,
    required String costUnit,
  }) {
    // Convert quantity to cost unit
    final convertedQuantity = convert(
      quantity: quantity,
      fromUnit: quantityUnit,
      toUnit: costUnit,
    );

    return convertedQuantity * costPerUnit;
  }

  /// Format quantity with unit for display
  static String formatQuantity(double quantity, String unit) {
    // Remove trailing zeros and unnecessary decimal point
    final formatted = quantity.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    return '$formatted $unit';
  }

  // Debug logging helpers
  static void _logWarning(String message) {
    assert(() {
      print(message);
      return true;
    }());
  }

  static void _logDebug(String message) {
    assert(() {
      // Only log in debug mode
      print(message);
      return true;
    }());
  }
}

/// Common units for quick access
class Units {
  // Weight - Metric
  static const String kilogram = 'kg';
  static const String gram = 'gram';
  static const String g = 'g';
  static const String milligram = 'mg';
  
  // Weight - Imperial
  static const String ounce = 'oz';
  static const String pound = 'lb';
  
  // Volume - Metric
  static const String liter = 'liter';
  static const String l = 'l';
  static const String milliliter = 'ml';
  
  // Volume - Cooking
  static const String cup = 'cup';
  static const String tablespoon = 'tbsp';
  static const String teaspoon = 'tsp';
  
  // Volume - Imperial
  static const String fluidOunce = 'floz';
  static const String pint = 'pint';
  static const String quart = 'quart';
  static const String gallon = 'gallon';
  
  // Count
  static const String dozen = 'dozen';
  static const String pieces = 'pcs';
  static const String piece = 'pieces';
  static const String unit = 'unit';
  static const String units = 'units';
  static const String biji = 'biji';
  static const String papan = 'papan';
  static const String sarang = 'sarang';
  static const String tray = 'tray';

  /// Get all available units grouped by category
  static Map<String, List<String>> get allUnits => {
    'Weight (Metric)': [kilogram, gram, g, milligram],
    'Weight (Imperial)': [ounce, pound],
    'Volume (Metric)': [liter, l, milliliter],
    'Volume (Cooking)': [cup, tablespoon, teaspoon],
    'Volume (Imperial)': [fluidOunce, pint, quart, gallon],
    'Count': [dozen, pieces, piece, unit, units, biji, papan, sarang, tray],
  };

  /// Get flat list of all units
  static List<String> get flatList => [
    // Weight
    kilogram, gram, g, milligram, ounce, pound,
    // Volume
    liter, l, milliliter, cup, tablespoon, teaspoon,
    fluidOunce, pint, quart, gallon,
    // Count
    dozen, pieces, piece, unit, units, biji, papan, sarang, tray,
  ];
}

