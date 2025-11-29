# 📦 STOCK MANAGEMENT ENHANCEMENT PLAN

## 🎯 **OBJECTIVE:**
Port complete Stock Management features from old React repo to Flutter, with mobile-first design.

---

## ✅ **EXISTING FEATURES (Already Have):**

1. **Basic Stock CRUD**
   - ✅ Add/Edit/Delete stock items
   - ✅ View stock list
   - ✅ Low stock alerts

2. **Stock Movements**
   - ✅ Track stock changes
   - ✅ Record movement history
   - ✅ Movement types

3. **Database Schema**
   - ✅ `stock_items` table
   - ✅ `stock_movements` table
   - ✅ RLS policies

---

## 🆕 **NEW FEATURES TO ADD:**

### **1. Stock History Page** 📊
- Timeline of all stock movements
- Movement type badges with icons
- Summary stats (Total In, Total Out)
- Filter by date range
- Color-coded changes (green/red)

### **2. Export Functionality** 📤
- Export to Excel (.xlsx)
- Export to CSV
- Include all stock item fields
- Date-stamped filenames

### **3. Import Functionality** 📥
- Import from Excel (.xlsx, .xls)
- Import from CSV
- Template download
- Data validation
- Append or Replace mode
- Error reporting

### **4. Shopping List Selection** 🛒
- Multi-select mode
- Quick select (All, Low Stock)
- Suggested quantities
- Bulk add to shopping cart
- Item notes per selection

### **5. Smart Filters** 🔍
- Quick filters (Low Stock, Out of Stock, In Stock)
- Advanced filters (Price range, Search)
- Active filter badges
- Clear all filters

### **6. Replenish Stock Dialog** ➕
- Add quantity to existing stock
- Update package price (optional)
- Update package size (optional)
- Show before/after quantities
- Calculate new total

### **7. Enhanced UI** 🎨
- Mobile-first layout
- Green/Gold theme
- Big touch targets
- Malay language
- Helper text
- Movement type icons

---

## 📂 **FILES TO CREATE/UPDATE:**

### **New Files:**
```
lib/features/stock/presentation/stock_history_page.dart
lib/core/utils/excel_export.dart
lib/core/utils/csv_export.dart
lib/core/utils/file_import.dart
lib/features/stock/presentation/widgets/smart_filters_widget.dart
lib/features/stock/presentation/widgets/replenish_stock_dialog.dart
lib/features/stock/presentation/widgets/shopping_list_dialog.dart
```

### **Update Files:**
```
lib/features/stock/presentation/stock_page.dart (enhance UI)
lib/data/models/stock_movement.dart (add movement types)
lib/data/repositories/stock_repository_supabase.dart (add new methods)
```

---

## 🔧 **DEPENDENCIES NEEDED:**

### **Flutter Packages:**
```yaml
dependencies:
  # Excel
  excel: ^4.0.3
  
  # CSV
  csv: ^6.0.0
  
  # File Picker
  file_picker: ^8.0.0+1
  
  # Date formatting
  intl: ^0.20.2 (already have)
```

---

## 🎨 **UI/UX DESIGN PRINCIPLES:**

### **Mobile-First:**
- ✅ Big buttons (56px height)
- ✅ Large touch targets (48px+)
- ✅ Single column layout on mobile
- ✅ Bottom sheets for actions
- ✅ Floating Action Button

### **Non-Techy Friendly:**
- ✅ Malay language labels
- ✅ Helper text everywhere
- ✅ Icons for visual cues
- ✅ Color-coded status
- ✅ Clear error messages

### **Color Scheme:**
- Green (#10B981): Success, Stock OK
- Gold (#F59E0B): Warnings, Low Stock
- Red (#EF4444): Errors, Out of Stock
- Blue (#3B82F6): Actions, Info

---

## 📊 **MOVEMENT TYPES:**

```dart
enum StockMovementType {
  purchase,        // 🛒 Pembelian (Blue)
  replenish,       // ➕ Tambah Stok (Green)
  adjust,          // 🔄 Pelarasan (Yellow)
  productionUse,   // 📉 Guna Produksi (Orange)
  waste,           // 🗑️ Rosak/Buang (Red)
  return,          // ◀️ Pulangan (Purple)
  transfer,        // ➡️ Pindah (Indigo)
  correction,      // ⚙️ Pembetulan (Gray)
}
```

---

## 🧪 **TESTING CHECKLIST:**

### **Stock Management:**
- [ ] Add stock item
- [ ] Edit stock item
- [ ] Delete stock item
- [ ] View low stock alerts
- [ ] Filter by status
- [ ] Search by name
- [ ] Export to Excel
- [ ] Export to CSV
- [ ] Import from Excel
- [ ] Import from CSV

### **Stock History:**
- [ ] View movement timeline
- [ ] See correct before/after quantities
- [ ] Movement type badges display correctly
- [ ] Summary stats accurate

### **Shopping List:**
- [ ] Enable selection mode
- [ ] Select individual items
- [ ] Select all low stock
- [ ] Adjust quantities
- [ ] Add notes
- [ ] Bulk add to cart

### **Replenish Stock:**
- [ ] Add quantity
- [ ] Update price
- [ ] Update package size
- [ ] Calculate new total
- [ ] Record movement

---

## 🚀 **IMPLEMENTATION ORDER:**

### **Phase 1: Core Enhancements** (30 mins)
1. Update Stock Item model
2. Add Stock History page
3. Add Replenish Stock dialog

### **Phase 2: Import/Export** (45 mins)
4. Add CSV export
5. Add Excel export (using package)
6. Add file import with validation
7. Add template download

### **Phase 3: Shopping List** (30 mins)
8. Add selection mode
9. Add shopping list dialog
10. Integrate with shopping cart API

### **Phase 4: UI Polish** (30 mins)
11. Add Smart Filters widget
12. Update colors & theme
13. Add icons for movement types
14. Mobile-first optimizations

**Total Estimated Time: 2-2.5 hours**

---

## 🎯 **SUCCESS CRITERIA:**

✅ All old React features ported to Flutter
✅ Mobile-first, thumb-friendly UI
✅ Export/Import working with Excel & CSV
✅ Stock history timeline functional
✅ Shopping list selection working
✅ Green/Gold theme applied
✅ Malay language labels
✅ No compilation errors
✅ Deployed to Vercel

---

**READY TO START BRO?** 💪

**I'll go step-by-step, EXACTLY like the old repo but mobile-optimized!** 🔥

