# Restart Flutter App

## Quick Restart Steps

1. **Stop current app** (if running):
   - Press `Ctrl+C` in terminal where app is running
   - Or close the app on device/emulator

2. **Restart app**:
   ```bash
   flutter run
   ```

3. **For hot reload** (if app is already running):
   - Press `r` in terminal for hot reload
   - Press `R` for hot restart

## Testing Checklist After Restart

### Shopping List Page
- [ ] No layout overflow errors
- [ ] No null type errors
- [ ] Low stock items filter correctly
- [ ] Items disappear after adding to cart
- [ ] Items disappear after creating PO
- [ ] Items disappear after receiving PO
- [ ] Page refreshes when returning from PO page

### Production Planning Dialog
- [ ] Preview dialog buttons fit screen properly
- [ ] "Tambah ke Senarai" button works
- [ ] Items appear in shopping list after adding
- [ ] Navigation to shopping list works smoothly

### Purchase Orders Page
- [ ] Page loads correctly
- [ ] Can create PO from shopping cart
- [ ] Can receive PO
- [ ] Stock updates after receiving PO

## Known Issues Fixed
✅ Button layout overflow - Fixed with Flexible + Wrap
✅ Null type error in low stock - Fixed with null safety
✅ Low stock items not filtering - Fixed with proper filter logic
✅ Items not appearing after add - Fixed with individual addToCart calls
✅ No refresh after PO receive - Fixed with auto-refresh mechanism

