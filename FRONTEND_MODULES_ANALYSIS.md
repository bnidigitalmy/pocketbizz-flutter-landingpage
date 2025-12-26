# Frontend Modules Analysis: Vendor, Deliveries, Supplier & Claim

Analisis lengkap flow, logik dan features untuk 4 modul utama sistem konsinyemen.

---

## 📋 TABLE OF CONTENTS

1. [VENDOR MODULE](#1-vendor-module)
2. [DELIVERIES MODULE](#2-deliveries-module)
3. [SUPPLIER MODULE](#3-supplier-module)
4. [CLAIMS MODULE](#4-claims-module)

---

## 1. VENDOR MODULE

### 📁 Location
`lib/features/vendors/presentation/`

### 🎯 Purpose
Manage Consignees (kedai yang jual produk untuk user dengan sistem komisyen)

### 🔑 Key Concepts

**PocketBizz Consignment System:**
- **User** = Orang yang guna app PocketBizz untuk uruskan bisnes mereka (pengeluar/owner produk)
- **Vendor (Consignee)** = Kedai yang jual produk user dengan commission (bukan pembekal bahan)
- **Relationship**: User hantar produk → Vendor jual → Vendor dapat commission → User dapat payment

### 📄 Files Structure
```
vendors/
├── vendors_page.dart              # Main listing page
├── vendor_detail_page.dart        # Vendor details & summary
├── add_vendor_page.dart           # Add vendor form
├── assign_products_page.dart      # Assign products to vendor
└── commission_dialog.dart         # Commission setup dialog
```

### 🔄 FLOW & LOGIC

#### **1.1 Vendors Listing Page (`vendors_page.dart`)**

**Flow:**
1. **Initial Load**
   - Load all vendors (active & inactive)
   - Display in responsive grid (1 col mobile, 2 tablet, 3 desktop)
   - Show empty state if no vendors

2. **Add Vendor**
   - Tap FAB or Add button → Open dialog
   - Form fields:
     - Nama Vendor (required)
     - Nombor Vendor (optional, for invoices)
     - No. Telefon (optional)
     - Alamat (optional)
   - Validation → Create vendor → Refresh list

3. **Vendor Card Actions**
   - **Tap card** → Navigate to `vendor_detail_page`
   - **Setup Komisyen button** → Open `CommissionDialog`

4. **Subscription Guard**
   - Protected by `SubscriptionGuard`
   - Only active/trial users can access
   - Shows subscription prompt if needed

**Key Logic:**
```dart
// Load vendors
final vendors = await _vendorsRepo.getAllVendors(activeOnly: false);

// Create vendor
await _vendorsRepo.createVendor(
  name: name,
  vendorNumber: vendorNumber,  // Optional
  phone: phone,                 // Optional
  address: address,             // Optional
);
```

#### **1.2 Vendor Detail Page (`vendor_detail_page.dart`)**

**Flow:**
1. **Load Data**
   - Vendor info
   - Vendor summary (totals, payments, claims)
   - Commission price ranges (if commission type = price_range)

2. **Display Sections:**
   - **Summary Cards:**
     - Jumlah Jualan (Total Gross)
     - Komisyen (Total Commission)
     - Sudah Dibayar (Total Paid)
     - Baki Tertunggak (Outstanding Balance)
     - Pending Claims count
     - Settled Claims count

   - **Contact Info Card:**
     - Vendor number, phone, email, address
     - Commission type & rates
     - Bank details (if any)

   - **Quick Actions:**
     - Lihat Penghantaran → Navigate to deliveries (filtered by vendor)
     - Lihat Tuntutan → Navigate to claims (filtered by vendor)
     - Cipta Tuntutan Baru → Navigate to create claim (pre-select vendor)
     - Assign Produk → Navigate to assign products page

3. **Actions:**
   - Toggle vendor status (activate/deactivate)
   - Pull to refresh

**Key Logic:**
```dart
// Load vendor summary
final summary = await _vendorsRepo.getVendorSummary(vendorId);
// Returns: {
//   'total_gross_amount': double,
//   'total_commission': double,
//   'total_paid_amount': double,
//   'outstanding_balance': double,
//   'pending_claims': int,
//   'settled_claims': int,
// }
```

#### **1.3 Commission Setup (`commission_dialog.dart`)**

**Flow:**
1. **Load Current Commission**
   - Get vendor commission type (percentage or price_range)
   - Load current rate/price ranges

2. **Select Commission Type:**
   - **Percentage (%)**: Fixed percentage of sales
   - **Price Range**: Commission based on product price ranges

3. **Setup Percentage:**
   - Input percentage (0-100%)
   - Save → Update vendor `default_commission_rate`

4. **Setup Price Range:**
   - Add price ranges (min, max, commission amount)
   - Example: RM0.10-RM5.00 = RM1.00 commission
   - Multiple ranges supported
   - Delete/edit ranges

**Key Logic:**
```dart
// Update commission
await _vendorsRepo.updateVendor(vendorId, {
  'commission_type': 'percentage' | 'price_range',
  'default_commission_rate': 10.0,  // If percentage
});

// Create price range
await _priceRangesRepo.createPriceRange(
  vendorId: vendorId,
  minPrice: 0.10,
  maxPrice: 5.00,      // null = unlimited
  commissionAmount: 1.00,
  position: 0,
);
```

### ✨ Features

1. **CRUD Operations**
   - ✅ Create vendor
   - ✅ View vendor details
   - ✅ Edit vendor info
   - ✅ Delete vendor (soft delete via status)
   - ✅ Toggle active/inactive

2. **Commission Management**
   - ✅ Percentage-based commission
   - ✅ Price range-based commission
   - ✅ Multiple price ranges per vendor
   - ✅ Commission summary in vendor details

3. **Integration**
   - ✅ Links to deliveries
   - ✅ Links to claims
   - ✅ Product assignment
   - ✅ Subscription protection

4. **UI/UX**
   - ✅ Responsive grid layout
   - ✅ Empty states
   - ✅ Loading states
   - ✅ Pull to refresh
   - ✅ Subscription guard

---

## 2. DELIVERIES MODULE

### 📁 Location
`lib/features/deliveries/presentation/`

### 🎯 Purpose
Manage deliveries to Consignees (vendors) - User hantar produk ke Vendor untuk dijual dengan sistem consignment

### 📄 Files Structure
```
deliveries/
├── deliveries_page.dart           # Main listing page
├── delivery_form_dialog.dart      # Create/edit delivery
├── invoice_dialog.dart            # Invoice preview & PDF
├── edit_rejection_dialog.dart     # Edit rejection reasons
└── payment_status_dialog.dart     # Update payment status
```

### 🔄 FLOW & LOGIC

#### **2.1 Deliveries Listing Page (`deliveries_page.dart`)**

**Flow:**
1. **Initial Load**
   - Load deliveries (paginated, 20 per page)
   - Load vendors, products, business profile
   - Display in expandable cards

2. **Filters:**
   - Vendor filter (dropdown)
   - Status filter (delivered, pending, claimed, rejected)
   - Date range filter (from-to)
   - Show active filter badge

3. **Delivery Card Display:**
   - Vendor name, date, total amount
   - Status badge (color-coded)
   - Expandable → Show items list
   - Actions:
     - Status dropdown (update status)
     - Edit Tolakan (if rejected)
     - WhatsApp share
     - View Invoice

4. **Quick Actions:**
   - Export CSV (placeholder)
   - Salin Semalam (duplicate yesterday's delivery)

**Key Logic:**
```dart
// Load deliveries with pagination
final result = await _deliveriesRepo.getAllDeliveries(
  limit: 20,
  offset: _currentOffset,
);
// Returns: {
//   'data': List<Delivery>,
//   'hasMore': bool,
// }

// Update delivery status
await _deliveriesRepo.updateDeliveryStatus(deliveryId, status);
// Statuses: 'delivered', 'pending', 'claimed', 'rejected'
```

#### **2.2 Create Delivery (`delivery_form_dialog.dart`)**

**Flow:**
1. **Select Vendor**
   - Dropdown vendor selection
   - Load vendor commission (for price calculation)
   - Remember last vendor (SharedPreferences)

2. **Set Delivery Date**
   - Date picker
   - Default: today

3. **Add Products:**
   - Tap "Tambah Produk" → Modal bottom sheet
   - Search/select products
   - For each product:
     - Enter quantity
     - Unit price (auto-calculated with commission deduction)
     - Retail price (optional)
     - Stock availability check
   - Items displayed in list
   - Edit/remove items

4. **Price Calculation:**
   - Unit price = Base price - Commission
   - Commission calculated based on vendor commission type:
     - Percentage: `basePrice * (1 - commissionRate/100)`
     - Price Range: Lookup commission from price ranges
   - Total = Sum of (quantity × unit_price)

5. **Save Delivery:**
   - Validate (vendor, date, items)
   - Create delivery → Show invoice dialog

**Key Logic:**
```dart
// Get vendor commission
final commission = await _deliveriesRepo.getVendorCommission(vendorId);
// Returns: {
//   'type': 'percentage' | 'price_range',
//   'rate': 10.0,  // If percentage
//   'priceRanges': [...],  // If price_range
// }

// Calculate unit price (after commission)
final unitPrice = _calculatePriceWithCommission(
  basePrice: product.sellingPrice,
  commission: commission,
);

// Create delivery
final delivery = await _deliveriesRepo.createDelivery(
  vendorId: vendorId,
  deliveryDate: date,
  items: [
    {
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'retail_price': retailPrice,
    },
    ...
  ],
);
```

#### **2.3 Invoice Dialog (`invoice_dialog.dart`)**

**Flow:**
1. **Display Invoice:**
   - Vendor info
   - Delivery date
   - Items list with quantities & prices
   - Total amount
   - Business profile (if available)

2. **Actions:**
   - Generate PDF
   - Share via WhatsApp
   - Print (web)

**Key Logic:**
```dart
// Generate PDF invoice
final pdfBytes = await DeliveryInvoicePdfGenerator.generate(
  delivery: delivery,
  businessProfile: businessProfile,
);
```

#### **2.4 Delivery Status Updates**

**Status Flow:**
```
delivered → pending → claimed → settled
         ↘ rejected
```

- **delivered**: Initial status after creation
- **pending**: Awaiting vendor acknowledgment
- **claimed**: Vendor has claimed (updated quantities)
- **rejected**: Some items rejected (with reasons)
- **settled**: Fully paid

**Rejection Handling:**
- Edit rejection dialog allows updating:
  - Rejected quantity per item
  - Rejection reason

### ✨ Features

1. **Delivery Management**
   - ✅ Create delivery
   - ✅ View deliveries list
   - ✅ Update delivery status
   - ✅ Edit rejection details
   - ✅ Duplicate last delivery

2. **Product Management**
   - ✅ Add multiple products
   - ✅ Stock availability check
   - ✅ Auto price calculation (with commission)
   - ✅ Edit quantities & prices

3. **Commission Integration**
   - ✅ Auto-calculate prices after commission
   - ✅ Support percentage & price range commissions
   - ✅ Display commission in invoice

4. **Invoice & Sharing**
   - ✅ Generate PDF invoice
   - ✅ WhatsApp sharing
   - ✅ Print functionality

5. **Filters & Search**
   - ✅ Filter by vendor
   - ✅ Filter by status
   - ✅ Filter by date range
   - ✅ Pagination

6. **UI/UX**
   - ✅ Expandable delivery cards
   - ✅ Color-coded status badges
   - ✅ Empty states
   - ✅ Loading states
   - ✅ Pull to refresh

---

## 3. SUPPLIER MODULE

### 📁 Location
`lib/features/suppliers/presentation/`

### 🎯 Purpose
Manage suppliers (pembekal bahan mentah/ingredients) untuk Purchase Orders dan Production

### 🔑 Key Concepts - CRITICAL DIFFERENCES FROM VENDORS

**Vendor vs Supplier dalam PocketBizz:**

| Aspect | **VENDOR** (Consignee) | **SUPPLIER** (Pembekal) |
|--------|------------------------|-------------------------|
| **Role** | Kedai yang **jual produk user** | Kedai yang **bekalkan bahan mentah** untuk user |
| **Relationship** | Consignment (user hantar produk → vendor jual → dapat commission) | Purchase (user beli bahan → buat produk) |
| **Flow Direction** | User → Vendor (hantar produk) → Vendor → Customer (jual) → Vendor bayar user | Supplier → User (bekal bahan) → User beli bahan |
| **Fields** | Name, phone, email, address + **commission settings** + **bank details** + **vendor number** | Name, phone, email, address (simple) |
| **Usage** | Consignment system (deliveries, claims, payments) | Purchase Orders, Production (ingredients) |
| **Commission** | ✅ Ada (percentage atau price range) | ❌ Tiada (bukan consignment) |
| **Table** | `vendors` table | `suppliers` table (separate table) |

**Perbezaan Penting:**
- **Vendor** = Consignee yang jual produk user dengan sistem komisyen
- **Supplier** = Pembekal bahan mentah untuk user buat produk (purchase relationship)
- **User** = Orang yang guna app PocketBizz untuk uruskan bisnes mereka

### 📄 Files Structure
```
suppliers/
└── suppliers_page.dart            # Main page (with embedded form dialog)
```

### 🔄 FLOW & LOGIC

#### **3.1 Suppliers Listing Page (`suppliers_page.dart`)**

**Flow:**
1. **Initial Load**
   - Load all suppliers
   - Display in responsive grid (1 col mobile, 2 tablet, 3 desktop)

2. **Add Supplier:**
   - Tap FAB or Add button → Open dialog
   - Form fields:
     - Nama Supplier (required)
     - No. Telefon (optional)
     - Email (optional)
     - Alamat (optional)
   - Validation → Create → Refresh list

3. **Supplier Card:**
   - Display name, created date
   - Contact info (phone, email, address)
   - Actions menu:
     - Edit → Open edit dialog
     - Delete → Confirm → Delete

4. **Edit Supplier:**
   - Same form as add
   - Pre-filled with existing data
   - Update → Refresh list

**Key Logic:**
```dart
// Load suppliers
final suppliers = await _repo.getAllSuppliers();

// Create supplier
await _repo.createSupplier(
  name: name,
  phone: phone,      // Optional
  email: email,      // Optional
  address: address,  // Optional
);

// Update supplier
await _repo.updateSupplier(
  id: supplierId,
  name: name,
  phone: phone,
  email: email,
  address: address,
);

// Delete supplier
await _repo.deleteSupplier(supplierId);
```

### ✨ Features

1. **CRUD Operations**
   - ✅ Create supplier
   - ✅ View suppliers list
   - ✅ Edit supplier
   - ✅ Delete supplier

2. **UI/UX**
   - ✅ Responsive grid layout
   - ✅ Empty states
   - ✅ Loading states
   - ✅ Form validation
   - ✅ Delete confirmation

3. **Integration**
   - Used in Purchase Orders module
   - Selected when creating PO from shopping list

---

## 4. CLAIMS MODULE

### 📁 Location
`lib/features/claims/presentation/`

### 🎯 Purpose
User (Consignor) buat tuntutan bayaran dari Vendor (Consignee)

### 🔑 Key Concepts
**Payment Formula:** `(Sold Products Value) - (Commission Rate %)`

**Flow:**
1. Vendor jual produk kepada customer
2. Vendor update sales dan balance (unsold/expired/rosak) kepada user
3. User buat tuntutan bayaran based on product sold only
4. Vendor buat payment kepada user dengan jumlah selepas tolak komisyen

**Note:** Unsold/expired/rosak products tidak termasuk dalam payment

### 📄 Files Structure
```
claims/
├── claims_page.dart                    # Main listing page
├── create_claim_simplified_page.dart   # Create claim (5-step flow)
├── claim_detail_page.dart              # Claim details & PDF
├── record_payment_page.dart            # Record payment (simplified)
├── create_payment_simplified_page.dart # Alternative payment flow
└── phone_input_dialog.dart             # WhatsApp phone input
```

### 🔄 FLOW & LOGIC

#### **4.1 Claims Listing Page (`claims_page.dart`)**

**Flow:**
1. **Initial Load**
   - Load all claims (limit 100)
   - Load payments
   - Load vendors
   - Display in cards

2. **Summary Card:**
   - Jumlah Kasar (Total Gross)
   - Komisyen (Total Commission)
   - Jumlah Bersih (Total Net)
   - Telah Dibayar (Total Paid)
   - Baki Tertunggak (Outstanding Balance)

3. **Status Tabs:**
   - Semua (All)
   - Outstanding (balance > 0)
   - Selesai (balance = 0)

4. **Filters:**
   - Vendor filter
   - Payment status filter (pending, partial, settled)

5. **Claim Card:**
   - Claim number, vendor name
   - Status badge (color-coded)
   - Amount breakdown (paid, balance)
   - Days overdue (if outstanding)
   - Actions:
     - Rekod Bayaran (if outstanding)
     - Lihat Detail Produk → Navigate to claim detail page

**Key Logic:**
```dart
// Load claims
final claims = await _claimsRepo.getAll(limit: 100);

// Filter claims
final filtered = claims.where((claim) {
  // Vendor filter
  if (filterVendor != 'all' && claim.vendorId != filterVendor) return false;
  
  // Status tab filter
  if (statusTab == 'outstanding' && claim.balanceAmount <= 0) return false;
  if (statusTab == 'settled' && claim.balanceAmount > 0) return false;
  
  return true;
}).toList();
```

#### **4.2 Create Claim (`create_claim_simplified_page.dart`)**

**5-Step Flow:**

**Step 1: Pilih Vendor**
- Select vendor from dropdown
- Load available deliveries & carry-forward items

**Step 2: Pilih Penghantaran**
- Show available deliveries (unclaimed)
- Show claimed deliveries (for reference)
- Multi-select deliveries
- Can also select carry-forward items

**Step 3: Edit Kuantiti**
- For each delivery item:
  - Quantity Sold (editable)
  - Quantity Unsold (editable)
  - Quantity Expired (editable)
  - Quantity Damaged (editable)
  - Auto-balance validation
- For carry-forward items:
  - Select status: Carry Forward, Loss, or None

**Step 4: Semak Ringkasan**
- Calculate totals:
  - Jumlah Kasar (sold × unit_price)
  - Komisyen (already deducted in delivery)
  - Jumlah Bersih (net amount)
- Display claim summary card
- Validation check
- Notes input

**Step 5: Selesai (Preview)**
- Display created claim details
- Generate PDF button
- WhatsApp share button
- Done button → Return to claims page

**Key Logic:**
```dart
// Load available deliveries (unclaimed)
final claimedDeliveryIds = await _claimsRepo.getClaimedDeliveryIds(vendorId);
final availableDeliveries = allDeliveries
  .where((d) => d.vendorId == vendorId 
             && d.status == 'delivered'
             && !claimedDeliveryIds.contains(d.id))
  .toList();

// Calculate claim summary
final summary = ClaimSummary.fromDeliveryItems(
  deliveryItems: items.map((item) => {
    'quantity': item['quantity'],
    'unit_price': item['unitPrice'],  // Already has commission deducted
    'quantity_sold': item['quantitySold'],
    ...
  }).toList(),
  commissionRate: 0.0,  // Already deducted
);

// Create claim
final claim = await _claimsRepo.createClaim(
  vendorId: vendorId,
  deliveryIds: selectedDeliveryIds,
  claimDate: claimDate,
  notes: notes,
  itemMetadata: itemMetadata,  // Quantities per item
  carryForwardItems: carryForwardItems,
);
```

#### **4.3 Record Payment (`record_payment_page.dart`)**

**Simplified 2-Step Flow:**

**Step 1: Pilih Vendor & Tuntutan**
- Select vendor → Load outstanding claims
- Select claim → Auto-fill amount (balance amount)
- Show claim details:
  - Claim number
  - Total amount
  - Already paid
  - Balance

**Step 2: Maklumat Bayaran**
- Payment date (default: today)
- Amount (pre-filled, editable)
- Payment reference (optional)
- Notes (optional)
- Save → Record payment → Update claim balance

**Key Logic:**
```dart
// Load outstanding claims
final claims = await _claimsRepo.getAll(limit: 100);
final outstanding = claims
  .where((c) => c.vendorId == vendorId && c.balanceAmount > 0)
  .toList();

// Record payment
await _paymentsRepo.recordPaymentForClaim(
  claimId: claimId,
  vendorId: vendorId,
  amount: amount,
  paymentDate: paymentDate,
  paymentReference: reference,
  notes: notes,
);
// DB trigger automatically updates claim.paid_amount, balance_amount, status
```

#### **4.4 Claim Detail Page (`claim_detail_page.dart`)**

**Flow:**
1. **Load Claim Details:**
   - Full claim info
   - Items list
   - Payment history

2. **Display Sections:**
   - Header card (claim number, vendor, date, status)
   - Summary card (amounts)
   - Items list (products, quantities, prices)
   - Payments history
   - Actions (PDF, WhatsApp)

3. **Actions:**
   - Generate PDF
   - Share via WhatsApp
   - Record payment (if outstanding)

**Key Logic:**
```dart
// Load claim with items
final claim = await _claimsRepo.getClaimById(claimId);

// Load payments
final payments = await _paymentsRepo.getPaymentsByClaim(claimId);

// Generate PDF
final pdfBytes = await PdfGenerator.generateClaimPdf(
  claim: claim,
  businessProfile: businessProfile,
);
```

### ✨ Features

1. **Claim Management**
   - ✅ Create claim (5-step wizard)
   - ✅ View claims list
   - ✅ View claim details
   - ✅ Filter & search claims
   - ✅ Status tracking

2. **Delivery Integration**
   - ✅ Select deliveries for claim
   - ✅ Prevent duplicate claims (track claimed delivery IDs)
   - ✅ Show claimed vs available deliveries

3. **Quantity Management**
   - ✅ Edit sold/unsold/expired/damaged quantities
   - ✅ Auto-balance validation
   - ✅ Carry-forward item support

4. **Payment Recording**
   - ✅ Record payment per claim
   - ✅ Auto-update claim balance
   - ✅ Payment history tracking
   - ✅ Multiple payment methods support

5. **Calculations**
   - ✅ Gross amount calculation
   - ✅ Commission deduction (already in delivery)
   - ✅ Net amount calculation
   - ✅ Balance tracking

6. **Export & Sharing**
   - ✅ Generate PDF claim statement
   - ✅ WhatsApp sharing
   - ✅ Export CSV (placeholder)

7. **UI/UX**
   - ✅ Step-by-step wizard (non-techy friendly)
   - ✅ Summary cards
   - ✅ Color-coded status badges
   - ✅ Outstanding balance highlighting
   - ✅ Days overdue calculation
   - ✅ Empty states
   - ✅ Loading states
   - ✅ Subscription guard

---

## 🔗 MODULE INTEGRATIONS

### Vendor ↔ Deliveries
- Deliveries require vendor selection
- Vendor detail page links to deliveries (filtered)
- Delivery form loads vendor commission

### Vendor ↔ Claims
- Claims require vendor selection
- Vendor detail page shows claim summary
- Vendor detail page links to claims (filtered)

### Deliveries ↔ Claims
- Claims are created from deliveries
- Track claimed delivery IDs (prevent duplicates)
- Delivery status can be "claimed"

### Supplier ↔ Purchase Orders ↔ Production
- Suppliers are selected when creating PO
- Used in shopping list → PO flow
- Suppliers provide raw materials for production/manufacturing
- **Different purpose from Vendors** (Vendors = jual produk, Suppliers = bekalkan bahan)

---

## 📊 DATA FLOW SUMMARY

### Vendor Flow (Consignment System)
```
Create Vendor → Setup Commission → Assign Products → 
Create Deliveries (hantar produk ke vendor) → Vendor jual produk → 
Create Claims (tuntut bayaran) → Record Payments (vendor bayar user)
```

### Supplier Flow (Purchase System)
```
Create Supplier → Create Purchase Order → Receive Materials → 
Use in Production → Track Costs
```

### Delivery Flow
```
Create Delivery → Select Vendor → Add Products → 
Calculate Prices (with commission) → Save → 
Update Status → Create Claim (when claimed)
```

### Claim Flow
```
Select Vendor → Select Deliveries → Edit Quantities → 
Calculate Summary → Create Claim → 
Record Payments → Update Balance
```

### Payment Flow
```
Select Vendor → Select Claim → Enter Amount → 
Record Payment → Update Claim Balance
```

---

## 🎨 UI/UX PATTERNS

### Common Patterns
1. **Responsive Grids**: 1 col mobile, 2 tablet, 3 desktop
2. **Expandable Cards**: For details
3. **Color-coded Badges**: Status indicators
4. **Empty States**: With helpful messages
5. **Loading States**: Progress indicators
6. **Pull to Refresh**: Data refresh
7. **Subscription Guard**: Feature protection

### Form Patterns
1. **Step-by-step Wizards**: For complex flows
2. **Dialog Forms**: For quick inputs
3. **Validation**: Real-time & on submit
4. **Auto-fill**: Remember last selections
5. **Auto-calculation**: Prices, totals

---

## 🔒 SECURITY & PERMISSIONS

1. **Subscription Guard**
   - ✅ Vendors module: **PROTECTED** (with SubscriptionGuard)
   - ✅ Claims module: **PROTECTED** (with SubscriptionGuard)
   - ⚠️ Deliveries: **NOT PROTECTED** (confirmed - no SubscriptionGuard wrapper)
   - ⚠️ Suppliers: **NOT PROTECTED** (confirmed - no SubscriptionGuard wrapper)

   **Note:** Deliveries dan Suppliers adalah part of consignment system, mungkin perlu di-protect untuk consistency.

2. **Data Access**
   - All modules use RLS (Row Level Security)
   - Filtered by user_id/business_owner_id
   - Repository layer handles security

---

## 📝 NOTES & CONSIDERATIONS

### ⚠️ CRITICAL: Vendor vs Supplier Distinction

**VENDOR (Consignee):**
- Kedai yang **jual produk user** dengan sistem komisyen
- User hantar produk → Vendor jual → User dapat payment (tolak commission)
- Ada commission settings (percentage atau price range)
- Ada bank details untuk payment
- Part of consignment system (deliveries, claims, payments)
- Table: `vendors` dengan fields tambahan untuk commission

**SUPPLIER (Pembekal):**
- Kedai yang **bekalkan bahan mentah** untuk user buat produk
- User beli bahan → Buat produk → Jual produk
- Simple structure (name, contact info sahaja)
- Tiada commission (bukan consignment relationship)
- Part of purchase/production system (PO, ingredients)
- Table: `suppliers` (separate table, simpler structure)

**User (PocketBizz User):**
- Orang yang guna app untuk uruskan bisnes mereka
- Boleh ada kedua-dua Vendor (untuk jual produk) dan Supplier (untuk beli bahan)

1. **Commission Calculation** (Vendor only)
   - Commission is deducted at delivery creation
   - Unit price in delivery_items already has commission deducted
   - Claims just sum up (qty_sold × unit_price)
   - **Suppliers tidak ada commission** (direct purchase)

2. **Delivery Status Flow**
   - Can go: delivered → pending → claimed → settled
   - Or: delivered → rejected

3. **Claim Tracking**
   - System tracks claimed delivery IDs
   - Prevents creating duplicate claims for same delivery

4. **Payment Tracking**
   - Payments update claim balance automatically (via DB triggers)
   - Support partial payments
   - Support bill-to-bill payments

5. **Carry-Forward Items**
   - Support carry-forward from previous claims
   - Can mark as loss or carry-forward in new claim

---

## 🚀 FUTURE ENHANCEMENTS

1. **Deliveries**
   - CSV export implementation
   - Bulk status update
   - Delivery templates

2. **Claims**
   - CSV export implementation
   - Bulk payment recording
   - Auto-claim generation

3. **Vendors**
   - Vendor performance analytics
   - Commission history

4. **Suppliers**
   - Supplier performance tracking
   - Purchase history

---

## ⚠️ ISSUES & INCONSISTENCIES FOUND

### 1. Security Issues

**Deliveries Module - Missing Subscription Guard**
- `deliveries_page.dart` tidak ada `SubscriptionGuard` wrapper
- Ini adalah part of consignment system, sepatutnya protected seperti Vendors & Claims
- **Impact:** Free users boleh access deliveries tanpa subscription
- **Recommendation:** Add SubscriptionGuard untuk consistency

**Suppliers Module - Missing Subscription Guard**
- `suppliers_page.dart` tidak ada `SubscriptionGuard` wrapper
- **Impact:** Free users boleh access suppliers tanpa subscription
- **Note:** Suppliers mungkin boleh free (untuk basic PO functionality), tapi perlu confirm dengan business requirements
- **Difference from Vendors:** Suppliers adalah untuk purchase/production (basic feature), mungkin boleh free. Vendors adalah untuk consignment (premium feature).

### 2. Data Structure Clarification

**Vendor vs Supplier Table Structure:**
- **Vendors table**: Ada commission fields, bank details, vendor_number
- **Suppliers table**: Simple structure (name, phone, email, address sahaja)
- Kedua-dua berkongsi info asas yang sama (contact info), tapi Vendor ada fields tambahan untuk consignment system
- Ini adalah design decision: Vendor lebih complex kerana perlu track commission & payments

### 3. Document Accuracy

✅ All files listed exist and match documentation
✅ Flow descriptions match actual code implementation
✅ Feature lists are accurate

### 4. Potential Improvements

**Deliveries:**
- Export CSV masih placeholder (TODO)
- Date range filter menggunakan text input (boleh improve dengan date picker)

**Claims:**
- Export CSV masih placeholder (TODO)
- Load limit hardcoded to 100 (boleh improve dengan proper pagination)

**Vendors:**
- Assign Products page wujud dan betul
- No issues found

**Suppliers:**
- Simple CRUD, no issues found
- Works as documented

### 5. Missing Features (Documented but not implemented)

1. **Deliveries CSV Export** - Still placeholder
2. **Claims CSV Export** - Still placeholder
3. **PDF Thermal Generation** - Mentioned in code but not fully implemented

---

**Last Updated:** 2025-01-16
**Version:** 1.1

