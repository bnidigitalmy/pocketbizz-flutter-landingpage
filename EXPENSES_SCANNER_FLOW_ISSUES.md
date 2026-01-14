# 🔄 MASALAH FLOW - EXPENSES & SCANNER MODULE

**Date:** 2025-01-16  
**Focus:** Business Logic Flow Issues

---

## 🔴 CRITICAL FLOW ISSUES

### 1. ❌ **Confusing Supplier Matching Flow - Multiple Dialogs**

**Current Flow**:
```
OCR Complete
  ↓
Supplier Match Found? (from OCR)
  ├─ YES (High Confidence) → Show Dialog 1: "Supplier Dikesan"
  │   ├─ User clicks "✔️ Sahkan" → Supplier selected ✅
  │   ├─ User clicks "Tukar" → Show Dialog 2: "Pilih Supplier"
  │   │   ├─ User selects supplier → Supplier selected ✅
  │   │   └─ User clicks "Tambah Supplier Baru" → Show Dialog 3: "Tambah Supplier"
  │   └─ User clicks back button → Supplier NOT selected ❌
  │
  ├─ YES (Medium/Low Confidence) → Show Dialog 1: "Pilih Supplier"
  │   ├─ User selects suggested match → Supplier selected ✅
  │   ├─ User selects other supplier → Supplier selected ✅
  │   ├─ User clicks "Tambah Supplier Baru" → Show Dialog 3: "Tambah Supplier"
  │   └─ User clicks "Skip" → No supplier selected ❌
  │
  └─ NO → Call _matchSupplier() again
      ├─ Match found? → Show Dialog 1 again (duplicate!)
      └─ No match → Show Dialog 1: "Supplier Tidak Dikenalpasti"
          ├─ User selects supplier → Supplier selected ✅
          ├─ User clicks "Tambah Supplier Baru" → Show Dialog 3: "Tambah Supplier"
          └─ User clicks "Skip" → No supplier selected ❌
```

**Problems**:
1. **Too Many Dialogs**: User boleh see 3 different dialogs untuk same action
2. **Duplicate Matching**: OCR sudah call matching, tapi frontend call lagi
3. **Inconsistent Flow**: High confidence vs medium/low confidence flow berbeza
4. **No Clear Exit**: User tidak tahu bila flow selesai
5. **Dialog Stacking**: Multiple dialogs boleh stack (Dialog 1 → Dialog 2 → Dialog 3)

**User Confusion**:
- "Kenapa dialog muncul 2 kali?"
- "Saya dah pilih supplier, kenapa masih ada dialog?"
- "Mana button untuk skip semua ni?"

**Recommended Flow**:
```
OCR Complete
  ↓
Supplier Match Found? (from OCR)
  ├─ YES → Show Single Dialog: "Supplier Dikesan"
  │   ├─ Display: "Dikesan sebagai: [Supplier Name]"
  │   ├─ Options:
  │   │   ├─ "✔️ Sahkan" → Confirm & continue
  │   │   ├─ "Tukar" → Show supplier list (in same dialog)
  │   │   ├─ "Tambah Baru" → Show add form (in same dialog)
  │   │   └─ "Skip" → Continue without supplier
  │   └─ User action → Update form → Continue
  │
  └─ NO → Show Single Dialog: "Pilih Supplier (Opsional)"
      ├─ Display: "Merchant: [Merchant Name]"
      ├─ Options:
      │   ├─ Supplier list (scrollable)
      │   ├─ "Tambah Baru" button
      │   └─ "Skip" button
      └─ User action → Update form → Continue
```

**Priority**: 🔴 **HIGH** - UX confusion

---

### 2. ❌ **Alias Saving Flow - Wrong Data Saved**

**Current Flow**:
```
User scans receipt: "POC Bakery Supplies"
  ↓
OCR matches to: "ABC Trading" (confidence: 0.87)
  ↓
Dialog shows: "Pilih Supplier"
  ↓
User clicks "Tukar" (wants to change)
  ↓
User selects: "XYZ Supplies" (different supplier)
  ↓
❌ PROBLEM: Alias "POC Bakery Supplies" → "ABC Trading" MIGHT STILL BE SAVED
  ↓
✅ CORRECT: Alias "POC Bakery Supplies" → "XYZ Supplies" should be saved
```

**Problem**:
- Alias saving happens **before** user final confirmation
- Jika user change supplier, original match alias mungkin sudah save
- Learning system dapat wrong data
- Future matching akan salah

**Current Code Issue**:
```dart
// In _showSupplierConfirmationDialog()
if (confirmed == true && matchResult.supplierId != null) {
  // Save alias immediately
  SupplierMatchingService.saveSupplierAlias(...);
}

// But if user clicks "Tukar", alias might already be saved
// Then user selects different supplier, but original alias remains
```

**Recommended Flow**:
```
User confirms supplier selection
  ↓
Form shows selected supplier
  ↓
User can still change supplier (via "Tukar" button)
  ↓
User clicks "Simpan Perbelanjaan"
  ↓
✅ Save alias ONLY when expense is saved
  ↓
Alias = Final supplier selected (not initial match)
```

**Priority**: 🔴 **HIGH** - Data accuracy issue

---

### 3. ❌ **No Clear Error Recovery Flow**

**Current Flow**:
```
User scans receipt
  ↓
OCR Processing...
  ↓
❌ OCR Failed
  ↓
Error message shown
  ↓
❌ PROBLEM: User stuck - no way to retry
  ↓
User must:
  1. Click "Scan semula" button (resets everything)
  2. Take new photo
  3. Start from beginning
```

**Problems**:
1. **No Retry**: User cannot retry dengan same image
2. **Lost Data**: Jika user sudah edit form, semua hilang
3. **Poor UX**: User frustrated, mungkin give up
4. **No Feedback**: User tidak tahu kenapa fail

**Recommended Flow**:
```
OCR Processing...
  ↓
❌ OCR Failed
  ↓
Show Error Dialog:
  ├─ Error message: "OCR gagal: [reason]"
  ├─ Options:
  │   ├─ "Cuba Lagi" → Retry dengan same image
  │   ├─ "Ambil Gambar Baru" → Reset & take new photo
  │   └─ "Masuk Manual" → Skip OCR, manual entry
  └─ User action → Continue
```

**Priority**: 🟡 **MEDIUM** - UX improvement

---

## 🟡 MEDIUM FLOW ISSUES

### 4. ⚠️ **Form Editing Flow - Unclear State**

**Current Flow**:
```
OCR Complete
  ↓
Form pre-filled dengan OCR data
  ↓
User edits amount/date/category
  ↓
User clicks "Tukar" untuk supplier
  ↓
❌ PROBLEM: Supplier dialog shows, but form state unclear
  ↓
User selects supplier
  ↓
Form updated
  ↓
User continues editing
  ↓
❌ QUESTION: Apakah supplier change affect form validation?
```

**Problems**:
1. **State Confusion**: User tidak tahu jika supplier change affect other fields
2. **No Validation Feedback**: Form validation tidak check supplier consistency
3. **Lost Changes**: Jika user accidentally close form, changes hilang
4. **No Undo**: User cannot undo supplier selection

**Recommended Flow**:
```
Form displayed dengan OCR data
  ↓
User edits fields
  ↓
Form shows "Unsaved changes" indicator
  ↓
User changes supplier
  ↓
Show confirmation: "Tukar supplier? Changes akan kekal."
  ↓
User confirms → Supplier updated, form preserved
  ↓
User saves → All changes saved together
```

**Priority**: 🟡 **MEDIUM** - UX clarity

---

### 5. ⚠️ **Navigation Flow - Multiple Back Buttons**

**Current Flow**:
```
ExpensesPage
  ↓
User clicks "Scan Resit"
  ↓
ReceiptScanPage (Camera View)
  ↓
User captures image
  ↓
ReceiptScanPage (Form View)
  ↓
User clicks "Simpan"
  ↓
✅ Expense saved
  ↓
Navigator.pop() → Back to ExpensesPage
  ↓
❌ PROBLEM: User mungkin confused dengan navigation
```

**Problems**:
1. **Multiple Back Buttons**: AppBar back button vs "Scan semula" button
2. **Unclear Navigation**: User tidak tahu bila akan navigate away
3. **Lost Progress**: Jika user accidentally back, form data hilang
4. **No Confirmation**: Tidak ada "Are you sure?" untuk unsaved changes

**Recommended Flow**:
```
ReceiptScanPage (Form View)
  ↓
User edits form
  ↓
User clicks AppBar back button
  ↓
Show confirmation: "Ada perubahan yang belum disimpan. Batal?"
  ↓
User confirms → Navigate back, discard changes
User cancels → Stay on page
  ↓
User clicks "Simpan"
  ↓
Save expense → Navigate back automatically
```

**Priority**: 🟡 **MEDIUM** - UX improvement

---

### 6. ⚠️ **Supplier Selection Flow - Inconsistent Behavior**

**Current Flow**:
```
Scenario A: High Confidence Match
  ↓
Dialog: "Supplier Dikesan: ABC Trading"
  ↓
User clicks "Tukar"
  ↓
Dialog: "Pilih Supplier" (full list)
  ↓
User selects supplier
  ↓
✅ Supplier updated

Scenario B: No Match
  ↓
Dialog: "Supplier Tidak Dikenalpasti"
  ↓
User selects supplier
  ↓
✅ Supplier selected

❌ PROBLEM: Same action (select supplier) but different flows
```

**Problems**:
1. **Inconsistent UX**: User experience berbeza untuk same action
2. **Confusing**: User mungkin expect same behavior
3. **Learning Curve**: User perlu learn multiple flows

**Recommended Flow**:
```
Unified Supplier Selection Flow:
  ↓
Always show same dialog structure:
  ├─ Header: "Pilih Supplier untuk [Merchant Name]"
  ├─ Suggested match (if any) - highlighted
  ├─ Full supplier list (scrollable)
  ├─ "Tambah Supplier Baru" button
  └─ "Skip" button
  ↓
User action → Consistent behavior
```

**Priority**: 🟡 **MEDIUM** - UX consistency

---

## 🟢 LOW PRIORITY FLOW ISSUES

### 7. ℹ️ **Image Upload Flow - Unclear Status**

**Current Flow**:
```
User captures image
  ↓
OCR processing (shows loading)
  ↓
OCR complete
  ↓
Form shown
  ↓
User clicks "Simpan"
  ↓
Image upload (no indicator)
  ↓
✅ Expense saved
```

**Problems**:
1. **No Upload Status**: User tidak tahu jika image sedang upload
2. **Silent Failure**: Jika upload fail, user mungkin tidak notice
3. **No Progress**: Large images might take time, no feedback

**Recommended Flow**:
```
User clicks "Simpan"
  ↓
Show progress: "Menyimpan... (1/2) Uploading image..."
  ↓
Image upload complete
  ↓
Show progress: "Menyimpan... (2/2) Saving expense..."
  ↓
✅ Expense saved
```

**Priority**: 🟢 **LOW** - UX polish

---

### 8. ℹ️ **Category Selection Flow - No Quick Add**

**Current Flow**:
```
Form shows category dropdown
  ↓
User clicks dropdown
  ↓
Shows: bahan, minyak, upah, plastik, lain
  ↓
User selects category
  ↓
✅ Category selected
```

**Problems**:
1. **Limited Options**: Only 5 categories
2. **No Custom Category**: User cannot add new category quickly
3. **Manual Entry**: User must go to expenses page untuk add category

**Recommended Flow**:
```
Form shows category dropdown
  ↓
User clicks dropdown
  ↓
Shows: bahan, minyak, upah, plastik, lain, + Tambah Kategori
  ↓
User clicks "+ Tambah Kategori"
  ↓
Quick dialog: "Nama kategori baru"
  ↓
User enters name → Category added & selected
```

**Priority**: 🟢 **LOW** - Feature enhancement

---

### 9. ℹ️ **Expense List Flow - No Batch Operations**

**Current Flow**:
```
ExpensesPage shows list
  ↓
User wants to delete multiple expenses
  ↓
User must:
  1. Click expense 1 → Delete → Confirm
  2. Click expense 2 → Delete → Confirm
  3. Click expense 3 → Delete → Confirm
  ...
```

**Problems**:
1. **Tedious**: Multiple clicks untuk batch operations
2. **No Selection Mode**: Cannot select multiple items
3. **No Bulk Actions**: Cannot delete/export multiple at once

**Recommended Flow**:
```
ExpensesPage shows list
  ↓
User clicks "Select" button (top right)
  ↓
Selection mode activated
  ↓
User selects multiple expenses (checkboxes)
  ↓
Bottom bar shows: "3 selected | Delete | Export"
  ↓
User clicks "Delete" → Confirm → All deleted
```

**Priority**: 🟢 **LOW** - Feature enhancement

---

## 📊 FLOW ISSUES SUMMARY

### Issues by Category

| Category | Count | Issues |
|----------|-------|--------|
| 🔴 **Critical Flow** | 3 | Multiple Dialogs, Wrong Alias Saving, No Error Recovery |
| 🟡 **Medium Flow** | 3 | Form Editing, Navigation, Supplier Selection |
| 🟢 **Low Flow** | 3 | Image Upload Status, Category Quick Add, Batch Operations |

### Total Flow Issues: **9**

---

## 🎯 RECOMMENDED FLOW IMPROVEMENTS

### Priority 1: Fix Critical Flows (This Week)

1. **Unify Supplier Dialog Flow**
   - Single dialog untuk semua scenarios
   - Consistent behavior
   - Clear exit points

2. **Fix Alias Saving Flow**
   - Save alias ONLY when expense saved
   - Use final supplier selection (not initial match)
   - Prevent wrong data in learning system

3. **Add Error Recovery Flow**
   - Retry button untuk failed OCR
   - Manual entry fallback
   - Preserve form data on error

### Priority 2: Improve Medium Flows (Next Sprint)

4. **Clarify Form Editing Flow**
   - Show "Unsaved changes" indicator
   - Confirmation untuk supplier changes
   - Preserve form state

5. **Improve Navigation Flow**
   - Confirmation untuk unsaved changes
   - Clear back button behavior
   - Auto-navigate after save

6. **Standardize Supplier Selection**
   - Unified dialog structure
   - Consistent behavior
   - Better UX

### Priority 3: Enhance Low Priority Flows (Backlog)

7. **Add Upload Progress**
   - Show upload status
   - Progress indicator
   - Error feedback

8. **Quick Category Add**
   - In-form category creation
   - Faster workflow
   - Better UX

9. **Batch Operations**
   - Selection mode
   - Bulk actions
   - Better efficiency

---

## ✅ POSITIVE FLOW FINDINGS

**Good Flow Practices**:
- ✅ Clear step-by-step process (Scan → OCR → Form → Save)
- ✅ Real-time updates untuk expenses list
- ✅ Supplier matching dengan confidence-based UI
- ✅ Form pre-filling dari OCR (saves time)
- ✅ Optional supplier selection (not blocking)

**Overall Flow Quality**: **GOOD** dengan beberapa improvements needed untuk better UX

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-16  
**Next Review**: After flow improvements applied
