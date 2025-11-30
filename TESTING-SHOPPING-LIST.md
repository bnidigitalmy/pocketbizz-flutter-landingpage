# Testing Guide: Shopping List Page

## Features to Test

### 1. ✅ Supplier Dropdown
- [ ] Open Shopping List page
- [ ] Click "Buat PO" button
- [ ] Check supplier dropdown appears
- [ ] Select existing supplier from dropdown
- [ ] Verify fields auto-populate (name, phone, email, address)
- [ ] Select "Supplier Baru (Manual)"
- [ ] Verify fields become editable

### 2. ✅ View PO History Button
- [ ] Check app bar has "Sejarah PO" button (description icon)
- [ ] Click button
- [ ] Verify navigates to `/purchase-orders` page

### 3. ✅ Quantity Update
- [ ] Add items to cart
- [ ] Use +/- buttons to change quantity
- [ ] Verify quantity updates in real-time
- [ ] Verify estimated cost updates
- [ ] Check no full page reload happens

### 4. ✅ Print Functionality
- [ ] Click print button
- [ ] Verify message appears (web: Ctrl+P instruction, mobile: coming soon)
- [ ] For web: Try Ctrl+P to test browser print

### 5. ✅ WhatsApp Share
- [ ] Add items to cart
- [ ] Click WhatsApp share button
- [ ] Verify WhatsApp opens with formatted message
- [ ] Check message format is correct

### 6. ✅ Quick Add Low Stock
- [ ] Check low stock suggestions appear
- [ ] Click "Quick Add" on a low stock item
- [ ] Verify item added to cart with suggested quantity
- [ ] Click "Tambah Semua" button
- [ ] Verify all low stock items added

### 7. ✅ Manual Add Item
- [ ] Click "Tambah Item" button
- [ ] Select stock item from dropdown
- [ ] Enter quantity
- [ ] Add optional notes
- [ ] Click "Tambah ke Cart"
- [ ] Verify item appears in cart

### 8. ✅ Create PO Flow
- [ ] Add items to cart
- [ ] Click "Buat PO"
- [ ] Select or enter supplier info
- [ ] Enter delivery address (optional)
- [ ] Enter PO notes (optional)
- [ ] Click "Semak & Sahkan PO"
- [ ] Verify preview dialog shows all info
- [ ] Edit supplier info in preview (if needed)
- [ ] Click "Sahkan & Buat PO"
- [ ] Verify PO created successfully
- [ ] Verify navigates to Purchase Orders page
- [ ] Verify cart is cleared

### 9. ✅ Remove Item
- [ ] Add items to cart
- [ ] Click delete icon on an item
- [ ] Confirm deletion
- [ ] Verify item removed from cart

### 10. ✅ Summary Cards
- [ ] Check "Item dalam Cart" shows correct count
- [ ] Check "Stok Rendah" shows correct count
- [ ] Check "Anggaran" shows correct total

## Known Issues / Notes

- Auto-open PO dialog with URL parameter: Disabled for now (requires web platform channel)
- Print functionality: Web shows instruction message, mobile shows coming soon
- Business profile: Still hardcoded as "PocketBizz" in preview dialog

## Testing Checklist

Before pushing to GitHub:
- [ ] All features tested locally
- [ ] No console errors
- [ ] No compilation errors
- [ ] UI looks good on mobile and web
- [ ] All dialogs work correctly
- [ ] Navigation works properly

