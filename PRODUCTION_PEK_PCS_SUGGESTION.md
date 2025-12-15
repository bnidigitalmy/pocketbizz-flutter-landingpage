# ✅ PRODUCTION - PEK/PCS PURCHASE SUGGESTION

**Date:** December 2025  
**Status:** ✅ **COMPLETED**

---

## 🎯 OVERVIEW

Updated production workflow untuk suggest purchase dalam unit **pek/pcs** (packages/pieces) instead of exact shortage quantity. Ini lebih praktikal kerana user tak boleh beli exact shortage dari supplier - mereka perlu beli ikut saiz pek yang dijual.

**Before:**
- Shortage: 200 gram
- Suggestion: "Beli 200 gram" ❌ (tidak praktikal - user tak boleh beli 200 gram dari supplier)

**After:**
- Shortage: 200 gram
- Package Size: 500 gram/pek
- Suggestion: "Cadangan Beli: 1 pek/pcs (500 gram)" ✅ (praktikal - user beli ikut pek)

---

## 📝 CHANGES IMPLEMENTED

### 1. **MaterialPreview Model** ✅

**Added Fields:**
- `packageSize` - Package size untuk stock item
- `packagesNeeded` - Number of pek/pcs needed (rounded up)

**Calculation:**
```dart
final packagesNeeded = packageSize > 0 
    ? (shortage / packageSize).ceil() 
    : 0;
```

**Example:**
- Shortage: 200 gram
- Package Size: 500 gram/pek
- Packages Needed: ceil(200 / 500) = 1 pek

---

### 2. **Production Repository** ✅

**File:** `lib/data/repositories/production_repository_supabase.dart`

**Changes:**
- ✅ Calculate `packagesNeeded` based on shortage dan package size
- ✅ Pass `packageSize` dan `packagesNeeded` to MaterialPreview

**Key Code:**
```dart
// Calculate packages needed (rounded up to nearest pek/pcs)
final packageSize = stockItem.packageSize > 0 ? stockItem.packageSize : 1.0;
final packagesNeeded = isSufficient ? 0 : (shortage / packageSize).ceil();

materialsNeeded.add(
  MaterialPreview(
    // ... other fields
    packageSize: packageSize,
    packagesNeeded: packagesNeeded,
  ),
);
```

---

### 3. **Production Planning Dialog UI** ✅

**File:** `lib/features/production/presentation/widgets/production_planning_dialog.dart`

**Changes:**
- ✅ Display purchase suggestion dalam format pek/pcs
- ✅ Show both pek/pcs count dan total quantity dalam base unit
- ✅ Visual highlight dengan orange box untuk purchase suggestion

**UI Display:**
```
Kurang: 200.00 gram
┌─────────────────────────────────────┐
│ 🛍️ Cadangan Beli: 1 pek/pcs        │
│    (500.00 gram)                    │
└─────────────────────────────────────┘
```

**Key Code:**
```dart
if (!material.isSufficient) ...[
  Text('Kurang: ${material.shortage.toStringAsFixed(2)} ${material.stockUnit}'),
  Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.orange[50],
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.orange[200]!),
    ),
    child: Row(
      children: [
        Icon(Icons.shopping_bag, size: 16, color: Colors.orange[700]),
        Expanded(
          child: Text(
            'Cadangan Beli: ${material.packagesNeeded} pek/pcs '
            '(${(material.packagesNeeded * material.packageSize).toStringAsFixed(2)} ${material.stockUnit})',
          ),
        ),
      ],
    ),
  ),
],
```

---

### 4. **Shopping Cart Integration** ✅

**File:** `lib/features/production/presentation/widgets/production_planning_dialog.dart`

**Changes:**
- ✅ When adding to shopping cart, use `packagesNeeded * packageSize` instead of exact shortage
- ✅ Notes include both shortage dan suggested purchase

**Key Code:**
```dart
// Use packages needed (pek/pcs) instead of exact shortage
final quantityToBuy = item.packagesNeeded * item.packageSize;

await widget.cartRepo.addToCart(
  stockItemId: item.stockItemId,
  shortageQty: quantityToBuy, // Use rounded up quantity in pek/pcs
  notes: 'Untuk produksi ${_productionPlan?.product.name ?? 'Unknown'} '
         '(Kurang: ${item.shortage.toStringAsFixed(2)} ${item.stockUnit}, '
         'Cadangan: ${item.packagesNeeded} pek/pcs)',
  priority: 'high',
);
```

---

## 🔄 WORKFLOW EXAMPLE

### Scenario:
- **Recipe needs:** 200 gram
- **Current stock:** 0 gram
- **Package size:** 500 gram/pek
- **Shortage:** 200 gram

### Before:
```
Kurang: 200.00 gram
→ Shopping cart: 200 gram ❌ (tidak praktikal)
```

### After:
```
Kurang: 200.00 gram
┌─────────────────────────────────────┐
│ 🛍️ Cadangan Beli: 1 pek/pcs         │
│    (500.00 gram)                     │
└─────────────────────────────────────┘
→ Shopping cart: 500 gram ✅ (praktikal - beli 1 pek)
```

---

## 📊 CALCULATION LOGIC

### Formula:
```dart
packagesNeeded = ceil(shortage / packageSize)
quantityToBuy = packagesNeeded * packageSize
```

### Examples:

**Example 1:**
- Shortage: 200 gram
- Package Size: 500 gram/pek
- Packages Needed: ceil(200 / 500) = 1 pek
- Quantity to Buy: 1 × 500 = 500 gram

**Example 2:**
- Shortage: 600 gram
- Package Size: 500 gram/pek
- Packages Needed: ceil(600 / 500) = 2 pek
- Quantity to Buy: 2 × 500 = 1000 gram

**Example 3:**
- Shortage: 500 gram
- Package Size: 500 gram/pek
- Packages Needed: ceil(500 / 500) = 1 pek
- Quantity to Buy: 1 × 500 = 500 gram

---

## ✅ BENEFITS

1. **Practical:**
   - ✅ User boleh beli ikut pek yang dijual di supplier
   - ✅ Tak perlu beli exact shortage (yang mungkin tak dijual)

2. **Real-World:**
   - ✅ Reflects actual purchasing behavior
   - ✅ Suppliers sell in packages, not exact quantities

3. **User-Friendly:**
   - ✅ Clear suggestion dengan visual highlight
   - ✅ Shows both pek/pcs dan total quantity

4. **Accurate:**
   - ✅ Always rounds up (ceiling) untuk ensure sufficient stock
   - ✅ Notes include both shortage dan suggested purchase

---

## 📁 FILES MODIFIED

### 1. **MaterialPreview Model**
**File:** `lib/data/models/production_preview.dart`

**Changes:**
- ✅ Added `packageSize` field
- ✅ Added `packagesNeeded` field
- ✅ Updated `fromJson` untuk calculate packages needed
- ✅ Updated `toJson` untuk include new fields

---

### 2. **Production Repository**
**File:** `lib/data/repositories/production_repository_supabase.dart`

**Changes:**
- ✅ Calculate `packagesNeeded` based on shortage dan package size
- ✅ Pass package size dan packages needed to MaterialPreview

---

### 3. **Production Planning Dialog**
**File:** `lib/features/production/presentation/widgets/production_planning_dialog.dart`

**Changes:**
- ✅ Display purchase suggestion dalam pek/pcs format
- ✅ Visual highlight dengan orange box
- ✅ Update shopping cart integration untuk use pek/pcs quantity

---

## 🧪 TESTING SCENARIOS

### Scenario 1: Small Shortage
- Shortage: 100 gram
- Package Size: 500 gram/pek
- **Expected:** Suggest 1 pek (500 gram)

### Scenario 2: Exact Package Size
- Shortage: 500 gram
- Package Size: 500 gram/pek
- **Expected:** Suggest 1 pek (500 gram)

### Scenario 3: Large Shortage
- Shortage: 1200 gram
- Package Size: 500 gram/pek
- **Expected:** Suggest 3 pek (1500 gram)

### Scenario 4: Multiple Materials
- Material 1: Shortage 200 gram, Package 500 gram → 1 pek
- Material 2: Shortage 600 gram, Package 500 gram → 2 pek
- **Expected:** Both show correct pek/pcs suggestions

---

## 📝 SUMMARY

**Status:** ✅ **COMPLETE**

Production workflow sekarang suggest purchase dalam pek/pcs:

- ✅ MaterialPreview includes package size dan packages needed
- ✅ Production repository calculates pek/pcs needed
- ✅ UI displays purchase suggestion dalam pek/pcs format
- ✅ Shopping cart uses pek/pcs quantity (rounded up)
- ✅ Notes include both shortage dan suggested purchase

**Ready untuk:**
- ✅ Production use
- ✅ User testing
- ✅ Real-world purchasing scenarios

---

**Implementation Date:** December 2025  
**Files Modified:** 3  
**User Experience:** More practical dan real-world! 🎉
