# 🧪 TEST: PRODUCT & RECIPE AUTO-COST CALCULATION

## ✅ MIGRATION APPLIED!

Now you have the complete Product + Recipe system with auto-cost calculation!

---

## 🎯 **HOW TO TEST (STEP BY STEP):**

### **STEP 1: Open Product Page**
1. Login to app
2. Bottom navigation → **📦 Products**

### **STEP 2: Click "+ Tambah Produk"**
- Big green button at bottom-right
- Opens "Tambah Produk & Resepi" page

---

## 🧪 **TEST SCENARIO: Cream Puff**

### **STEP 3: Fill Product Info**

**Nama Produk:** `Cream Puff`  
**Kategori:** `Kuih`  
**URL Gambar:** (skip for now, optional)

---

### **STEP 4: Add Recipe Items (Bahan-Bahan)**

**Make sure you have stock items first!** If not, add via Stock Management.

#### **Bahan 1: Tepung**
- **Pilih Bahan:** Tepung (example: 500g @ RM5.00)
- **Kuantiti:** `200`
- **Unit:** `gram`
- **Cost auto-calculates:** RM 2.00

#### **Bahan 2: Telur**
- Click **[+ Tambah Bahan]**
- **Pilih Bahan:** Telur (example: 10pcs @ RM12.00)
- **Kuantiti:** `3`
- **Unit:** `pcs`
- **Cost auto-calculates:** RM 3.60

#### **Bahan 3: Gula**
- Click **[+ Tambah Bahan]** again
- **Pilih Bahan:** Gula (example: 1kg @ RM3.50)
- **Kuantiti:** `100`
- **Unit:** `gram`
- **Cost auto-calculates:** RM 0.35

**Total Materials Cost:** RM 5.95 ✅

---

### **STEP 5: Fill Production Costs**

**Unit Per Batch:** `10` (10 puffs per batch)  
**Packaging/Unit:** `0.25` (RM0.25 per box)  
**Kos Buruh:** `10` (RM10 upah per batch)  
**Kos Lain:** `2` (RM2 for gas/electric)

---

### **STEP 6: Check Cost Summary (Auto-Calculated!)**

You should see:

```
┌──────────────────────────────┐
│ 🧮 Ringkasan Kos             │
│                              │
│ Bahan Mentah     RM 5.95     │
│ Packaging        RM 2.50     │ (0.25 × 10)
│ Buruh            RM 10.00    │
│ Lain-lain        RM 2.00     │
│ ─────────────────────────    │
│ JUMLAH KOS/BATCH RM 20.45    │
│                              │
│ ┌──────────────────────────┐ │
│ │ KOS PER UNIT  RM 2.05    │ │ (20.45 / 10)
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

✅ **All calculations happen LIVE as you type!**

---

### **STEP 7: Set Selling Price (Suggested Markup)**

Click one of the markup buttons:

**[2x RM4.10]** → Cost × 2 = 100% profit  
**[2.5x RM5.13]** → Cost × 2.5 = 150% profit  
**[3x RM6.15]** → Cost × 3 = 200% profit  
**[Cadangan (40%)]** → Auto-suggested based on cost

Or manually enter your own price!

**Example:** Click **[2.5x RM5.13]**
→ Harga Jualan auto-fills: `RM 5.13`

---

### **STEP 8: Save Product**

Click big **[💾 Simpan Produk]** button

✅ **Product saved with:**
- Recipe items linked to stock
- All costs calculated
- Auto-suggested pricing
- Ready for production tracking!

---

## 🎯 **EXPECTED RESULTS:**

### ✅ **Live Cost Calculation:**
- Add/remove recipe items → Cost updates
- Change quantity → Cost updates
- Change units → Cost updates (with conversion!)
- Change labour/other/packaging → Cost updates

### ✅ **Unit Conversions Working:**
```
Stock: 500gram @ RM5.00
Usage: 200gram
Conversion: 200g = 0.2kg
Cost: RM5.00 / 500g × 200g = RM2.00 ✅
```

### ✅ **Cost Breakdown:**
```
Materials:  RM 5.95 (from recipe items)
Packaging:  RM 2.50 (RM0.25 × 10 units)
Labour:     RM 10.00
Other:      RM 2.00
──────────────────
Total/Batch: RM 20.45
Cost/Unit:   RM 2.05 (RM20.45 / 10)
```

### ✅ **Smart Pricing:**
- Cheap items (<RM1): 50% margin suggested
- Medium items (RM1-3): 40% margin
- Normal items (RM3-5): 35% margin
- Expensive items (>RM5): 30% margin

---

## 🐛 **IF YOU SEE ERRORS:**

### **Error: Stock items empty**
→ Add stock items first via Stock Management

### **Error: Unit conversion failed**
→ Check `unit_conversion.dart` has correct conversions

### **Error: Cost not calculating**
→ Make sure quantity & unit are filled

---

## 🎨 **UI SHOULD LOOK LIKE:**

### **Mobile-First:**
- ✅ Big buttons (56px height)
- ✅ Large touch targets
- ✅ Clear labels in Malay
- ✅ Helper text under each field
- ✅ Live cost preview per ingredient
- ✅ Color-coded summary (Green/Gold)

### **Non-Techy Friendly:**
- ✅ No jargon
- ✅ Simple language
- ✅ One action at a time
- ✅ Auto-calculations (no manual math!)
- ✅ Suggested pricing (just click!)

---

## 🚀 **READY TO TEST BRO!**

**WAIT FOR APP TO LOAD, THEN:**
1. Go to Products
2. Click "+ Tambah Produk"
3. Follow test scenario above
4. See magic auto-cost calculation! ✨

**REPORT BACK:**
- ✅ All working?
- 🐛 Any errors?
- 💡 Need adjustments?

**LET'S TEST!** 💪

