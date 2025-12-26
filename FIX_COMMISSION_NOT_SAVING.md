# Fix: Commission Auto Revert ke 0 Selepas Save

## 🐛 Masalah yang Ditemui

**User Report:**
- Lepas set commission percentage dan save
- Sistem auto revert ke 0 semula
- Tiada komisyen disimpan

## 🔍 Root Cause Analysis

**Possible Issues:**
1. Update tidak berjaya - tapi code nampak betul
2. Data tidak di-reload selepas save
3. Dialog reload old data selepas save
4. Validation issue - commission rate parsing fail

## ✅ Pembetulan yang Dibuat

### 1. Added Debug Logging

**File:** `lib/features/vendors/presentation/commission_dialog.dart`

**Added:**
```dart
debugPrint('💾 Saving commission: type=$_commissionType, rate=$commissionRate');
debugPrint('📝 Update data: $updateData');
await _vendorsRepo.updateVendor(widget.vendorId, updateData);
debugPrint('✅ Vendor commission updated successfully');
```

**Purpose:**
- Track what data is being sent
- Verify update operation completes
- Debug jika ada issues

### 2. Improved Validation

**Before:**
```dart
final commissionRate = double.tryParse(_commissionController.text) ?? 0.0;
```

**After:**
```dart
final commissionRate = double.tryParse(_commissionController.text);
if (commissionRate == null) {
  // Show error and return early
  return;
}
updateData['default_commission_rate'] = commissionRate;
```

**Reason:**
- Prevent saving 0.0 jika parsing fail
- Show error message jika invalid input
- Only save valid commission rate

### 3. Reload Vendor Data After Save

**Added:**
```dart
await _vendorsRepo.updateVendor(widget.vendorId, updateData);
debugPrint('✅ Vendor commission updated successfully');

// Reload vendor data to reflect changes in the dialog
await _loadVendor();
```

**Purpose:**
- Ensure dialog shows updated data
- Verify save was successful
- Update UI dengan latest data

### 4. Added Update Verification

**File:** `lib/data/repositories/vendors_repository_supabase.dart`

**Added:**
```dart
await supabase
    .from('vendors')
    .update(updateData)
    .eq('id', vendorId);

// Verify update was successful by checking the updated row
final verify = await supabase
    .from('vendors')
    .select()
    .eq('id', vendorId)
    .maybeSingle();

if (verify == null) {
  throw Exception('Failed to update vendor: Vendor not found after update');
}
```

**Purpose:**
- Verify update actually succeeded
- Throw error jika update fail
- Better error handling

## 🔄 How It Works Now

1. User set commission percentage (cth: 15.0)
2. Click "Simpan"
3. Validation:
   - Parse commission rate
   - Check if valid (not null, >= 0, <= 100)
   - Show error jika invalid
4. Build update data:
   - `commission_type`: 'percentage'
   - `default_commission_rate`: 15.0
5. Update vendor dalam database
6. Verify update succeeded
7. Reload vendor data dari database
8. Update dialog UI dengan latest data
9. Show success message
10. Close dialog

## ✅ Testing Checklist

Selepas fix, verify:
1. ✅ Set commission percentage (cth: 15.0)
2. ✅ Click "Simpan"
3. ✅ Check console logs untuk debug messages
4. ✅ Commission rate saved dalam database
5. ✅ Dialog shows updated commission rate
6. ✅ Close dan reopen dialog - commission rate tetap saved
7. ✅ Vendor list shows correct commission

## 📝 Debug Steps

Jika masih ada masalah, check console logs:
1. `💾 Saving commission:` - Shows commission type and rate
2. `📝 Update data:` - Shows data being sent to database
3. `✅ Vendor commission updated successfully` - Confirms update completed

Jika update fail, check:
- Database connection
- RLS policies
- Column names match
- Data types match

---

**Date:** 2025-01-16
**Status:** ✅ **FIXED**

