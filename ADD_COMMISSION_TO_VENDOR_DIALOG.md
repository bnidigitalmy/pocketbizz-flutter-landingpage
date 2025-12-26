# Feature: Add Commission Settings to "Tambah Vendor Baru" Dialog

## ✅ Implementation Complete

## 📋 Overview

Sekarang user boleh set commission settings terus dalam dialog "Tambah Vendor Baru". Sekali jalan, user boleh:
1. Tambah vendor baru dengan semua maklumat
2. Set commission type (percentage atau price range)
3. Set commission rate (jika percentage)
4. Save sekali gus

## ✅ Changes Made

### 1. Added Commission Fields to Dialog

**File:** `lib/features/vendors/presentation/vendors_page.dart`

**Added:**
- `_commissionController` - TextEditingController untuk commission rate input
- `_commissionType` - String untuk track commission type ('percentage' or 'price_range')
- Commission settings section dalam dialog dengan:
  - Dropdown untuk pilih commission type
  - Input field untuk commission rate (jika percentage)
  - Validation untuk commission rate (0-100%)

**UI Section:**
```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.blue[50],
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.blue[200]!),
  ),
  child: Column(
    children: [
      // Commission type dropdown
      DropdownButtonFormField<String>(
        value: _commissionType,
        items: [
          DropdownMenuItem(value: 'percentage', child: Text('Peratus (%)')),
          DropdownMenuItem(value: 'price_range', child: Text('Price Range (akan setup kemudian)')),
        ],
      ),
      // Commission rate input (if percentage)
      if (_commissionType == 'percentage')
        TextFormField(
          controller: _commissionController,
          validator: (value) {
            // Validate 0-100%
          },
        ),
    ],
  ),
)
```

### 2. Updated Create Vendor Method

**File:** `lib/data/repositories/vendors_repository_supabase.dart`

**Added:**
- `commissionType` parameter (default: 'percentage')
- Save `commission_type` ke database

**Before:**
```dart
Future<Vendor> createVendor({
  required String name,
  // ... other fields
  double defaultCommissionRate = 0.0,
}) async {
  // ... insert without commission_type
}
```

**After:**
```dart
Future<Vendor> createVendor({
  required String name,
  // ... other fields
  String commissionType = 'percentage',
  double defaultCommissionRate = 0.0,
}) async {
  // ... insert with commission_type
  'commission_type': commissionType,
  'default_commission_rate': defaultCommissionRate,
}
```

### 3. Updated _handleCreate Method

**File:** `lib/features/vendors/presentation/vendors_page.dart`

**Added:**
- Parse commission rate dari input
- Pass commission settings ke `createVendor`

**Code:**
```dart
final commissionRate = double.tryParse(_commissionController.text.trim()) ?? 15.0;

final vendor = await _vendorsRepo.createVendor(
  name: _nameController.text.trim(),
  // ... other fields
  commissionType: _commissionType,
  defaultCommissionRate: commissionRate,
);
```

### 4. Form Reset

**Updated `_resetForm()`:**
- Reset commission controller to '15.0' (default)
- Reset commission type to 'percentage'

## 🎯 User Flow

1. User click "Tambah Vendor"
2. Dialog "Tambah Vendor Baru" opens
3. User fill vendor information:
   - Nama Vendor
   - Nombor Vendor (optional)
   - No. Telefon
   - Alamat
4. User set commission settings:
   - Pilih jenis komisyen (Percentage atau Price Range)
   - Jika Percentage: masukkan kadar komisyen (0-100%)
5. User click "Simpan Vendor"
6. Validation runs:
   - All required fields validated
   - Commission rate validated (0-100%)
7. Vendor created dengan commission settings
8. Dialog closes
9. Vendor list refreshed

## ✅ Features

### Commission Type Selection
- ✅ Dropdown untuk pilih jenis komisyen
- ✅ Options: "Peratus (%)" dan "Price Range (akan setup kemudian)"
- ✅ Default: "Peratus (%)"

### Commission Rate Input
- ✅ Shows jika commission type = 'percentage'
- ✅ Default value: 15.0%
- ✅ Validation: 0-100%
- ✅ Helper text untuk guide user

### Validation
- ✅ Commission rate required jika percentage
- ✅ Commission rate must be between 0-100%
- ✅ Error messages dalam Bahasa Malaysia

## 📝 Notes

**Price Range Commission:**
- Untuk sekarang, jika user pilih "Price Range", commission rate tidak diset
- User boleh setup price ranges kemudian via "Setup Komisyen" button
- Commission type akan saved sebagai 'price_range'
- Price ranges boleh ditambah kemudian

**Default Values:**
- Commission Type: 'percentage'
- Commission Rate: 15.0%

**Future Enhancements:**
- Boleh tambah price range setup langsung dalam dialog (jika diperlukan)
- Boleh tambah validation untuk ensure price ranges exist jika type = 'price_range'

## ✅ Testing Checklist

1. ✅ Open "Tambah Vendor Baru" dialog
2. ✅ Fill vendor information
3. ✅ Set commission type to "Peratus (%)"
4. ✅ Enter commission rate (cth: 15.0)
5. ✅ Click "Simpan Vendor"
6. ✅ Vendor created dengan commission settings
7. ✅ Check vendor list - commission settings correct
8. ✅ Open "Setup Komisyen" - shows correct commission
9. ✅ Test validation - try invalid commission rate
10. ✅ Test price range option (should save type only)

---

**Date:** 2025-01-16
**Status:** ✅ **COMPLETED**

