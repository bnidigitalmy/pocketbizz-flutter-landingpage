# Feature: Add Price Range Commission Setup dalam "Tambah Vendor Baru" Dialog

## ✅ Implementation Complete

## 📋 Overview

Sekarang user boleh setup price range commission terus dalam dialog "Tambah Vendor Baru". User boleh:
1. Pilih "Price Range" sebagai commission type
2. Tambah multiple price ranges dalam dialog yang sama
3. Delete price ranges sebelum save
4. Save vendor dengan price ranges sekali gus

## ✅ Changes Made

### 1. Added Price Range Management

**File:** `lib/features/vendors/presentation/vendors_page.dart`

**Added:**
- `_priceRanges` - List untuk store temporary price ranges sebelum vendor created
- `_priceRangesRepo` - Repository untuk create price ranges
- Methods untuk manage price ranges:
  - `_buildPriceRangesSection()` - Display price ranges dalam dialog
  - `_buildPriceRangeCard()` - Display individual price range card
  - `_showAddPriceRangeDialog()` - Dialog untuk tambah price range
  - `_removePriceRange()` - Remove price range dari list

### 2. Updated Imports

**Added:**
```dart
import '../../../data/repositories/vendor_commission_price_ranges_repository_supabase.dart';
import '../../../data/models/vendor_commission_price_range.dart';
```

### 3. Updated Commission Type Dropdown

**Before:**
```dart
DropdownMenuItem(
  value: 'price_range',
  child: Text('Price Range (akan setup kemudian)'),
),
```

**After:**
```dart
DropdownMenuItem(
  value: 'price_range',
  child: Text('Price Range'),
),
```

### 4. Updated UI untuk Show Price Range Section

**When commission type = 'price_range':**
- Shows price ranges section dengan:
  - Add button untuk tambah price range
  - List price ranges yang telah ditambah
  - Delete button untuk setiap price range

### 5. Updated _handleCreate Method

**Added:**
- Validation untuk ensure at least 1 price range jika type = 'price_range'
- Create price ranges selepas vendor created
- Loop through `_priceRanges` dan create setiap range dengan position

**Code:**
```dart
// Validate price ranges
if (_commissionType == 'price_range' && _priceRanges.isEmpty) {
  // Show error
  return;
}

// Create vendor
final vendor = await _vendorsRepo.createVendor(...);

// Create price ranges
if (_commissionType == 'price_range' && _priceRanges.isNotEmpty) {
  for (int i = 0; i < _priceRanges.length; i++) {
    await _priceRangesRepo.createPriceRange(
      vendorId: vendor.id,
      minPrice: _priceRanges[i]['minPrice'] as double,
      maxPrice: _priceRanges[i]['maxPrice'] as double?,
      commissionAmount: _priceRanges[i]['commission'] as double,
      position: i,
    );
  }
}
```

### 6. Updated Form Reset

**Added:**
- Clear `_priceRanges` list dalam `_resetForm()`

## 🎯 User Flow

1. User click "Tambah Vendor"
2. Dialog "Tambah Vendor Baru" opens
3. User fill vendor information
4. User set commission settings:
   - **If Percentage:** Input commission rate (0-100%)
   - **If Price Range:**
     - Click "+" button untuk tambah price range
     - Fill price range dialog:
       - Harga Min (RM) *
       - Harga Max (RM) - optional (kosongkan untuk unlimited)
       - Jumlah Komisyen (RM) *
     - Click "Tambah" - price range added ke list
     - Repeat untuk tambah more price ranges
     - Click delete icon untuk remove price range
5. User click "Simpan Vendor"
6. Validation:
   - All required fields validated
   - If price range: at least 1 price range required
7. Vendor created
8. Price ranges created (if price range type)
9. Dialog closes
10. Vendor list refreshed

## ✅ Features

### Price Range Management
- ✅ Add price range dengan form validation
- ✅ Display list price ranges dalam dialog
- ✅ Delete price range sebelum save
- ✅ Validation: at least 1 price range required
- ✅ Price range validation:
  - Min price required, must be >= 0
  - Max price optional, must be > min price if provided
  - Commission amount required, must be >= 0

### UI/UX
- ✅ Clear visual separation dengan commission section
- ✅ Add button dengan icon
- ✅ Delete button dengan red icon untuk each range
- ✅ Empty state message jika no ranges
- ✅ Form validation dengan error messages

## 📝 Price Range Structure

Each price range contains:
- `minPrice`: Minimum price untuk range (required)
- `maxPrice`: Maximum price untuk range (optional, null = unlimited)
- `commission`: Fixed commission amount untuk range (required)
- `position`: Order/position (auto-assigned based on list index)

**Example:**
```dart
_priceRanges = [
  {
    'minPrice': 0.10,
    'maxPrice': 5.00,
    'commission': 1.00,
  },
  {
    'minPrice': 5.01,
    'maxPrice': null, // unlimited
    'commission': 1.50,
  },
]
```

## ✅ Testing Checklist

1. ✅ Select "Price Range" dari commission type dropdown
2. ✅ Price range section appears
3. ✅ Click "+" untuk tambah price range
4. ✅ Fill price range form dengan valid data
5. ✅ Price range added ke list
6. ✅ Add multiple price ranges
7. ✅ Delete price range dari list
8. ✅ Try save tanpa price range - validation error
9. ✅ Save vendor dengan price ranges
10. ✅ Check database - price ranges created dengan betul
11. ✅ Check "Setup Komisyen" dialog - price ranges displayed correctly

---

**Date:** 2025-01-16
**Status:** ✅ **COMPLETED**

