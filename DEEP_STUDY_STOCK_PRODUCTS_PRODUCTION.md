# 📚 DEEP STUDY - MODUL PENGURUSAN STOK, PRODUK & PENGELUARAN

**Date:** December 2025  
**Project:** PocketBizz Flutter App  
**Study Level:** Comprehensive Deep Analysis untuk Improvement

---

## 📋 TABLE OF CONTENTS

1. [Executive Summary](#executive-summary)
2. [Modul 1: Pengurusan Stok (Stock Management)](#modul-1-pengurusan-stok-stock-management)
3. [Modul 2: Produk (Products)](#modul-2-produk-products)
4. [Modul 3: Pengeluaran (Production)](#modul-3-pengeluaran-production)
5. [Integration Points](#integration-points)
6. [Known Issues & Limitations](#known-issues--limitations)
7. [Improvement Opportunities](#improvement-opportunities)
8. [Technical Architecture](#technical-architecture)

---

## 🎯 EXECUTIVE SUMMARY

Tiga modul ni adalah **core modules** untuk business operations:

1. **Stock Management** - Urus bahan mentah/ingredients dalam gudang
2. **Products** - Urus produk siap jual (finished goods)
3. **Production** - Record pengeluaran dengan auto-deduct stock

**Current Status:**
- ✅ Semua modul dah implemented dan functional
- ✅ Database schema complete dengan RLS
- ✅ UI/UX dah ada tapi boleh improve
- ✅ Integration antara modul dah working
- ⚠️ Ada beberapa areas untuk improvement

**Key Findings:**
- Stock management menggunakan FIFO system
- Production auto-deduct stock dari recipe
- Products link dengan recipes untuk costing
- Unit conversion support untuk different units
- Complete audit trail untuk semua movements

---

## 📦 MODUL 1: PENGURUSAN STOK (STOCK MANAGEMENT)

### 1.1 Overview

**Purpose:** Manage raw materials/ingredients dalam warehouse dengan complete tracking dan audit trail.

**Key Features:**
- ✅ Stock items CRUD
- ✅ Stock movements tracking (8 types)
- ✅ Low stock alerts
- ✅ Stock history/audit trail
- ✅ Export/Import (Excel, CSV)
- ✅ Replenish stock dialog
- ✅ Smart filters
- ✅ Unit conversion support

### 1.2 Database Schema

#### **Table: `stock_items`**
```sql
CREATE TABLE stock_items (
    id UUID PRIMARY KEY,
    business_owner_id UUID → users(id),
    
    -- Product Information
    name TEXT NOT NULL,
    unit TEXT NOT NULL, -- kg, gram, liter, ml, pcs, dozen
    
    -- Purchase Information
    package_size NUMERIC(10,2) DEFAULT 1, -- Size of package (e.g., 500 for 500gram)
    purchase_price NUMERIC(10,2) NOT NULL, -- Total price for PACKAGE
    
    -- Current Stock Level
    current_quantity NUMERIC(10,2) DEFAULT 0,
    low_stock_threshold NUMERIC(10,2) DEFAULT 5,
    
    -- Metadata
    notes TEXT,
    version INTEGER DEFAULT 0, -- Optimistic locking
    is_archived BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);
```

**Key Fields:**
- `package_size` - Saiz package yang dibeli (e.g., 500 untuk 500gram)
- `purchase_price` - Harga untuk satu package
- `current_quantity` - Current stock dalam warehouse
- `low_stock_threshold` - Alert bila bawah ni
- `costPerUnit` - Calculated: `purchase_price / package_size`

#### **Table: `stock_movements`**
```sql
CREATE TABLE stock_movements (
    id UUID PRIMARY KEY,
    business_owner_id UUID → users(id),
    stock_item_id UUID → stock_items(id),
    
    -- Movement Details
    movement_type stock_movement_type NOT NULL,
    quantity_before NUMERIC(10,2) NOT NULL,
    quantity_change NUMERIC(10,2) NOT NULL, -- Positive = increase, Negative = decrease
    quantity_after NUMERIC(10,2) NOT NULL,
    
    -- Context & Traceability
    reason TEXT,
    reference_id UUID, -- Link to related entity
    reference_type TEXT, -- e.g., "production_batch", "purchase_order"
    created_by UUID → users(id),
    
    created_at TIMESTAMPTZ
);
```

**Movement Types (Enum):**
1. `purchase` - Initial stock purchase (Blue)
2. `replenish` - Stock replenishment (Green)
3. `adjust` - Manual adjustment (Orange)
4. `production_use` - Used in production (Deep Orange)
5. `waste` - Damaged/expired/wasted (Red)
6. `return` - Returned to supplier (Purple)
7. `transfer` - Transfer between locations (Indigo)
8. `correction` - Inventory correction (Grey)

### 1.3 Data Models

#### **StockItem Model**
**Location:** `lib/data/models/stock_item.dart`

```dart
class StockItem {
  final String id;
  final String businessOwnerId;
  final String name;
  final String unit;
  final double packageSize;
  final double purchasePrice;
  final double currentQuantity;
  final double lowStockThreshold;
  final String? notes;
  final int version;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Calculated properties
  double get costPerUnit => purchasePrice / packageSize;
  bool get isLowStock => currentQuantity <= lowStockThreshold;
  double get stockLevelPercentage => (currentQuantity / lowStockThreshold) * 100;
}
```

**Key Calculations:**
- `costPerUnit` = `purchasePrice / packageSize`
  - Example: RM 21.90 / 500g = RM 0.0438 per gram
- `isLowStock` = `currentQuantity <= lowStockThreshold`
- `stockLevelPercentage` = `(currentQuantity / lowStockThreshold) * 100`

#### **StockMovement Model**
**Location:** `lib/data/models/stock_movement.dart`

```dart
enum StockMovementType {
  purchase('purchase'),
  replenish('replenish'),
  adjust('adjust'),
  productionUse('production_use'),
  waste('waste'),
  returnToSupplier('return'),
  transfer('transfer'),
  correction('correction');
}

class StockMovement {
  final String id;
  final String businessOwnerId;
  final String stockItemId;
  final StockMovementType movementType;
  final double quantityBefore;
  final double quantityChange; // Positive = increase, Negative = decrease
  final double quantityAfter;
  final String? reason;
  final String? referenceId;
  final String? referenceType;
  final String? createdBy;
  final DateTime createdAt;
  
  bool get isIncrease => quantityChange > 0;
}
```

### 1.4 Repository Layer

#### **StockRepositorySupabase**
**Location:** `lib/data/repositories/stock_repository_supabase.dart`

**Key Methods:**

```dart
// CRUD Operations
Future<List<StockItem>> getAllStockItems({bool includeArchived = false});
Future<StockItem?> getStockItemById(String id);
Future<List<StockItem>> getLowStockItems();
Future<StockItem> createStockItem(StockItemInput input);
Future<StockItem> updateStockItem(String id, StockItemInput input);
Future<void> archiveStockItem(String id);
Future<void> deleteStockItem(String id);

// Stock Movements
Future<String> recordStockMovement(StockMovementInput input); // Thread-safe via DB function
Future<List<StockMovement>> getStockMovements(String stockItemId, {int limit = 50});
Future<List<StockMovement>> getAllStockMovements({StockMovementType? type, int limit = 100});

// Convenience Methods
Future<void> addStock({required String stockItemId, required double quantity, required String reason, bool isPurchase = false});
Future<void> removeStock({required String stockItemId, required double quantity, required StockMovementType type, required String reason});
Future<void> adjustStock({required String stockItemId, required double quantityChange, required String reason});

// Statistics
Future<Map<String, dynamic>> getStockStatistics();
```

**Important:** `recordStockMovement()` uses database function `record_stock_movement()` untuk thread-safety dan consistency.

### 1.5 Database Functions

#### **Function: `record_stock_movement()`**
**Location:** `db/migrations/add_stock_management.sql`

**Purpose:** Thread-safe way untuk update stock quantities dengan automatic audit trail.

**How it works:**
1. Validates stock item exists
2. Gets current quantity (with optimistic locking via `version`)
3. Calculates new quantity
4. Updates stock item
5. Creates movement record
6. Returns movement ID

**Key Features:**
- ✅ Prevents negative stock (if enabled)
- ✅ Optimistic locking untuk prevent race conditions
- ✅ Automatic audit trail
- ✅ Reference tracking (link to production_batch, purchase_order, etc.)

### 1.6 UI Components

#### **StockPage** (Main List)
**Location:** `lib/features/stock/presentation/stock_page.dart`

**Features:**
- List semua stock items
- Search & filter (name, status)
- Smart filters (Low Stock, Out of Stock, In Stock)
- Selection mode untuk bulk operations
- Export/Import buttons
- Quick actions (Replenish, History, Edit)
- Stock statistics cards

**UI Elements:**
- Summary cards (Total Items, Low Stock, Out of Stock)
- Smart filters widget
- Stock item cards dengan status indicators
- FAB untuk add new item
- Selection mode FAB untuk shopping list

#### **StockHistoryPage**
**Location:** `lib/features/stock/presentation/stock_history_page.dart`

**Features:**
- Timeline semua movements untuk satu stock item
- Movement type badges dengan colors
- Summary stats (Total In, Total Out, Movement Count)
- Before/After quantity display
- Reason/notes untuk setiap movement
- Color-coded changes (Green increase, Red decrease)

#### **ReplenishStockDialog**
**Location:** `lib/features/stock/presentation/widgets/replenish_stock_dialog.dart`

**Features:**
- Add quantity to existing stock
- Update package price (optional)
- Update package size (optional)
- Live preview of new quantities
- Auto-calculate new unit price
- Records stock movement dengan reason

#### **SmartFiltersWidget**
**Location:** `lib/features/stock/presentation/widgets/smart_filters_widget.dart`

**Features:**
- Search bar dengan clear button
- Quick filter chips (Low Stock, Out of Stock, In Stock)
- Clear all filters button
- Active state indication

### 1.7 Export/Import Utilities

#### **StockExportImport**
**Location:** `lib/core/utils/stock_export_import.dart`

**Features:**
- ✅ Export to Excel (.xlsx)
- ✅ Export to CSV
- ✅ Import from Excel (.xlsx, .xls)
- ✅ Import from CSV
- ✅ Download sample template
- ✅ Data validation
- ✅ Error reporting dengan row numbers

**Export Format:**
```
Item Name | Unit | Package Size | Purchase Price (RM) | Current Quantity | Low Stock Threshold | Notes
```

### 1.8 Workflow Examples

#### **Workflow 1: Add New Stock Item**
```
1. User clicks "Tambah Item" FAB
2. Fill form:
   - Name: Tepung Gandum
   - Unit: kg
   - Package Size: 1
   - Purchase Price: RM 8.00
   - Low Stock Threshold: 5
3. Submit → Creates stock item dengan current_quantity = 0
4. User can then add initial stock via "Replenish" button
```

#### **Workflow 2: Replenish Stock**
```
1. User clicks "Tambah Stok" button on stock item
2. Replenish dialog opens
3. Enter quantity to add (e.g., 10 kg)
4. Optionally update price/size
5. Preview shows new quantities
6. Submit → Records movement dengan type "replenish"
7. Stock item current_quantity updated automatically
```

#### **Workflow 3: View Stock History**
```
1. User clicks "Sejarah" button on stock item
2. StockHistoryPage opens
3. Shows timeline semua movements
4. Each movement shows:
   - Type dengan color badge
   - Before/After quantities
   - Reason/notes
   - Date & time
   - Reference (if linked to production_batch, etc.)
```

### 1.9 Current Limitations & Improvements

#### ✅ **IMPROVEMENTS COMPLETED:**

1. **Bulk Import API** ✅ **IMPLEMENTED**
   - ✅ Export works
   - ✅ Import parsing works
   - ✅ **Bulk import to database IMPLEMENTED**
   - ✅ `bulkImportStockItems()` method added dalam StockRepository
   - ✅ Supports duplicate checking
   - ✅ Returns summary dengan success/failure counts
   - ✅ Auto-records initial stock movements

2. **Batch Expiry Tracking** ✅ **IMPLEMENTED**
   - ✅ **Stock item batches table created** (`stock_item_batches`)
   - ✅ **FIFO based on expiry dates SUPPORTED**
   - ✅ Batch tracking dengan expiry dates
   - ✅ Functions: `record_stock_item_batch()`, `deduct_from_stock_item_batches()`
   - ✅ View: `stock_item_batches_summary` untuk batch overview
   - ✅ Model: `StockItemBatch` created

3. **Unit Conversion Enhanced** ✅ **EXPANDED**
   - ✅ Basic conversion exists
   - ✅ **Expanded dengan more units:**
     - Weight: kg, gram, g, mg, oz, lb, pound
     - Volume: liter, l, ml, cup, tbsp, tsp, floz, pint, quart, gallon
     - Count: dozen, pcs, pieces, unit, units
   - ✅ Better unit conversion support untuk recipes

#### ⚠️ **REMAINING LIMITATIONS:**

1. **No Multi-Location Support**
   - All stock in one location
   - Transfer type exists tapi belum fully implemented
   - Future enhancement: Multi-warehouse support

2. **Batch Tracking UI Not Yet Implemented**
   - Database schema ready ✅
   - Functions ready ✅
   - But UI untuk manage batches belum ada
   - TODO: Create UI untuk add/view batches dengan expiry dates

---

## 🛍️ MODUL 2: PRODUK (PRODUCTS)

### 2.1 Overview

**Purpose:** Manage finished goods/products untuk jual dengan recipe integration dan auto-costing.

**Key Features:**
- ✅ Product CRUD dengan images
- ✅ Category management
- ✅ Recipe integration
- ✅ Auto-costing dari recipe
- ✅ Stock tracking (from production batches)
- ✅ Profit margin calculation
- ✅ SKU management

### 2.2 Database Schema

#### **Table: `products`**
```sql
CREATE TABLE products (
    id UUID PRIMARY KEY,
    business_owner_id UUID → users(id),
    
    -- Product Info
    sku TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    category_id UUID → categories(id),
    category TEXT, -- Denormalized for display
    unit TEXT NOT NULL, -- pcs, kg, box, etc.
    description TEXT,
    image_url TEXT, -- Supabase Storage URL
    
    -- Pricing
    sale_price NUMERIC(12,2) NOT NULL,
    cost_price NUMERIC(12,2) NOT NULL,
    
    -- Production Costing
    units_per_batch INTEGER DEFAULT 1, -- How many units per recipe batch
    labour_cost NUMERIC(12,2) DEFAULT 0, -- Labour cost per batch
    other_costs NUMERIC(12,2) DEFAULT 0, -- Gas, electric, etc per batch
    packaging_cost NUMERIC(12,2) DEFAULT 0, -- Packaging cost PER UNIT
    
    -- Calculated costs (from recipe)
    materials_cost NUMERIC(12,2), -- Sum of recipe items
    total_cost_per_batch NUMERIC(12,2), -- materials + labour + other + (packaging * units)
    cost_per_unit NUMERIC(12,2), -- total_cost_per_batch / units_per_batch
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);
```

**Key Fields:**
- `cost_price` - Manual cost price (boleh override auto-calculated)
- `materials_cost` - Auto-calculated dari recipe items
- `total_cost_per_batch` - Total cost untuk satu batch production
- `cost_per_unit` - Cost per unit (untuk pricing)
- `units_per_batch` - Berapa unit yang dihasilkan dari satu recipe batch

### 2.3 Data Models

#### **Product Model**
**Location:** `lib/data/models/product.dart`

```dart
class Product {
  final String id;
  final String businessOwnerId;
  
  // Product Info
  final String sku;
  final String name;
  final String? categoryId;
  final String? category; // For display
  final String unit;
  final double salePrice;
  final double costPrice;
  final String? description;
  final String? imageUrl;
  
  // Production Costing
  final int unitsPerBatch; // How many units produced per recipe
  final double labourCost; // Labour cost per batch
  final double otherCosts; // Gas, electric, etc per batch
  final double packagingCost; // Packaging cost PER UNIT
  
  // Calculated costs
  final double? materialsCost; // From recipe items
  final double? totalCostPerBatch; // materials + labour + other + (packaging * units)
  final double? costPerUnit; // totalCostPerBatch / unitsPerBatch
  
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

**Cost Calculation Flow:**
1. Recipe items calculate `materials_cost` (sum of all ingredients)
2. `total_cost_per_batch` = `materials_cost + labour_cost + other_costs + (packaging_cost * units_per_batch)`
3. `cost_per_unit` = `total_cost_per_batch / units_per_batch`
4. `cost_price` boleh manual override atau use `cost_per_unit`

### 2.4 Repository Layer

#### **ProductsRepositorySupabase**
**Location:** `lib/data/repositories/products_repository_supabase.dart`

**Key Methods:**

```dart
// CRUD Operations
Future<Product> createProduct(Product product);
Future<List<Product>> getAll();
Future<Product> getProduct(String id);
Future<List<Product>> listProducts({String? category, String? searchQuery, int limit = 100});
Future<Product> updateProduct(String id, Map<String, dynamic> updates);
Future<void> deleteProduct(String id);
Future<List<Product>> searchProducts(String query);
```

**Note:** Cost calculation dilakukan oleh database triggers/functions, bukan di repository.

### 2.5 UI Components

#### **ProductListPage**
**Location:** `lib/features/products/presentation/product_list_page.dart`

**Features:**
- List semua products dengan images
- Search & filter (name, SKU, category)
- Category filter chips
- Sort options (name, price high/low, stock low)
- Summary cards (Total Products, Low Stock, Out of Stock)
- Product cards dengan:
  - Product image
  - Name & category
  - Sale price & cost price
  - Stock level badge
  - Profit margin % + RM
  - Quick actions (Recipe, Edit, Delete)

**UI Elements:**
- Search bar
- Category filter chips
- Sort dropdown
- Product cards dengan status indicators
- FAB untuk add new product

#### **AddProductPage**
**Location:** `lib/features/products/presentation/add_product_page.dart`

**Features:**
- Form untuk create new product
- Category dropdown
- Image upload (Supabase Storage)
- Cost & pricing fields
- Production costing fields (optional)
- Validation

#### **EditProductPage**
**Location:** `lib/features/products/presentation/edit_product_page.dart`

**Features:**
- Edit existing product
- Update all fields
- Profit margin calculator
- Image update

#### **AddProductWithRecipePage**
**Location:** `lib/features/products/presentation/add_product_with_recipe_page.dart`

**Features:**
- Create product dengan recipe builder
- Integrated workflow
- Step-by-step process

### 2.6 Recipe Integration

Products link dengan recipes untuk:
1. **Auto-costing** - Recipe items calculate materials cost
2. **Production planning** - Recipe defines what ingredients needed
3. **Stock deduction** - When recording production, recipe items auto-deduct stock

**Flow:**
```
Product → Recipe → Recipe Items → Stock Items
```

### 2.7 Stock Tracking

Products track stock via **production batches**:
- Stock = Sum of `remaining_qty` from all production batches
- FIFO system untuk sales
- Expiry tracking via batch expiry dates

**How it works:**
1. Record production → Creates production batch
2. Production batch has `remaining_qty`
3. When selling → Deduct from batches (FIFO)
4. Product stock = Sum of all batch `remaining_qty`

### 2.8 Current Limitations

1. **Cost Calculation Not Always Auto-Updated**
   - Recipe changes don't always trigger cost recalculation
   - Manual refresh sometimes needed
   - TODO: Add trigger untuk auto-update cost when recipe changes

2. **No Product Variants**
   - Can't have different sizes/flavors of same product
   - Each variant needs separate product record
   - Future enhancement: Product variants support

3. **Image Upload Limited**
   - Only one image per product
   - No image gallery
   - Future enhancement: Multiple images support

4. **No Barcode Support**
   - SKU exists tapi no barcode scanning
   - Future enhancement: Barcode scanning untuk POS

---

## 🏭 MODUL 3: PENGELUARAN (PRODUCTION)

### 3.1 Overview

**Purpose:** Record production batches dengan automatic stock deduction dari recipes dan FIFO tracking untuk finished goods.

**Key Features:**
- ✅ Record production batches
- ✅ Auto-deduct stock dari recipe
- ✅ FIFO system untuk finished goods
- ✅ Batch tracking dengan expiry dates
- ✅ Cost calculation
- ✅ Production planning preview
- ✅ Ingredient usage audit trail

### 3.2 Database Schema

#### **Table: `production_batches`**
```sql
CREATE TABLE production_batches (
    id UUID PRIMARY KEY,
    business_owner_id UUID → users(id),
    product_id UUID → products(id),
    
    -- Batch Info
    batch_number TEXT,
    product_name TEXT, -- Denormalized
    quantity INTEGER NOT NULL, -- Units produced
    remaining_qty NUMERIC(12,3) NOT NULL, -- Units still available (FIFO)
    batch_date DATE NOT NULL,
    expiry_date DATE,
    
    -- Costing
    total_cost NUMERIC(12,2) NOT NULL,
    cost_per_unit NUMERIC(12,2) NOT NULL,
    
    -- Metadata
    notes TEXT,
    is_completed BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);
```

**Key Fields:**
- `quantity` - Total units produced dalam batch ni
- `remaining_qty` - Units yang masih ada (untuk FIFO sales)
- `batch_date` - Tarikh production
- `expiry_date` - Tarikh luput (optional)
- `cost_per_unit` - Cost per unit (untuk FIFO costing)

#### **Table: `production_ingredient_usage`**
```sql
CREATE TABLE production_ingredient_usage (
    id UUID PRIMARY KEY,
    business_owner_id UUID → users(id),
    production_batch_id UUID → production_batches(id),
    stock_item_id UUID → stock_items(id),
    recipe_item_id UUID → recipe_items(id),
    
    -- Usage Details
    quantity_used NUMERIC(12,3) NOT NULL,
    unit TEXT NOT NULL,
    cost_per_unit NUMERIC(12,4) NOT NULL, -- Snapshot at time of production
    total_cost NUMERIC(12,2) NOT NULL,
    
    created_at TIMESTAMPTZ
);
```

**Purpose:** Complete audit trail untuk ingredient usage dalam setiap production batch.

#### **Table: `production_batch_stock_movements`**
```sql
CREATE TABLE production_batch_stock_movements (
    id UUID PRIMARY KEY,
    business_owner_id UUID → users(id),
    batch_id UUID → production_batches(id),
    product_id UUID → products(id),
    
    -- Movement Details
    movement_type TEXT NOT NULL, -- 'sale', 'delivery', 'waste', etc.
    quantity NUMERIC(12,3) NOT NULL,
    remaining_after_movement NUMERIC(12,3) NOT NULL,
    
    -- Reference
    reference_id UUID,
    reference_type TEXT,
    notes TEXT,
    
    created_at TIMESTAMPTZ
);
```

**Purpose:** Track movements untuk finished goods (sales, deliveries, waste, etc.)

### 3.3 Data Models

#### **ProductionBatch Model**
**Location:** `lib/data/models/production_batch.dart`

```dart
class ProductionBatch {
  final String id;
  final String businessOwnerId;
  final String productId;
  final String? batchNumber;
  final String productName;
  final int quantity; // Units produced
  final double remainingQty; // Units still available (FIFO)
  final DateTime batchDate;
  final DateTime? expiryDate;
  final double totalCost;
  final double costPerUnit;
  final String? notes;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Calculated properties
  bool get isFullyUsed => remainingQty <= 0;
  bool get isPartiallyUsed => remainingQty > 0 && remainingQty < quantity;
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());
  double get usagePercentage => quantity > 0 ? ((quantity - remainingQty) / quantity) * 100 : 0;
}
```

#### **ProductionIngredientUsage Model**
**Location:** `lib/data/models/production_ingredient_usage.dart`

```dart
class ProductionIngredientUsage {
  final String id;
  final String businessOwnerId;
  final String productionBatchId;
  final String stockItemId;
  final String recipeItemId;
  final double quantityUsed;
  final String unit;
  final double costPerUnit; // Snapshot at time of production
  final double totalCost;
  final DateTime createdAt;
}
```

### 3.4 Repository Layer

#### **ProductionRepository**
**Location:** `lib/data/repositories/production_repository_supabase.dart`

**Key Methods:**

```dart
// Production Batches CRUD
Future<List<ProductionBatch>> getAllBatches({String? productId, bool onlyWithRemaining = false});
Future<ProductionBatch?> getBatchById(String id);
Future<List<ProductionBatch>> getRecentBatches({int limit = 10});
Future<List<ProductionBatch>> getBatchesByDateRange({required DateTime startDate, required DateTime endDate});
Future<String> recordProductionBatch(ProductionBatchInput input); // Uses DB function - auto-deducts stock!
Future<ProductionBatch> updateBatch(String id, Map<String, dynamic> updates);
Future<void> updateRemainingQty(String id, double newRemainingQty);
Future<void> deleteBatch(String id);

// FIFO Operations
Future<List<ProductionBatch>> getOldestBatchesForProduct(String productId, {int limit = 5});
Future<double> deductFromBatch(String batchId, double quantity, {String? referenceId, String? referenceType, String? notes});
Future<List<Map<String, dynamic>>> deductFIFO(String productId, double quantityToDeduct, {String? referenceId, String? referenceType, String? notes});
Future<List<Map<String, dynamic>>> consumeStock({required String productId, required double quantity, String? deliveryId, String? note});

// Statistics
Future<Map<String, dynamic>> getProductionStatistics({DateTime? startDate, DateTime? endDate});
Future<double> getTotalRemainingForProduct(String productId);
Future<List<ProductionBatch>> getExpiredBatches();

// Production Planning
Future<ProductionPlan> previewProductionPlan({required String productId, required int quantity});

// Stock Movement Tracking
Future<List<Map<String, dynamic>>> getBatchMovementHistory(String batchId);
Future<List<Map<String, dynamic>>> getProductMovementHistory(String productId);
```

### 3.5 Database Functions

#### **Function: `record_production_batch()`**
**Location:** `db/migrations/create_record_production_batch_function.sql`

**Purpose:** Creates production batch dan auto-deducts stock dari recipe items dalam satu transaction.

**How it works:**
1. Validates product exists
2. Gets active recipe untuk product
3. Calculates total cost
4. Creates production batch
5. **FIRST PASS:** Checks if all ingredients have sufficient stock
6. **SECOND PASS:** Deducts stock dari semua recipe items
7. Records ingredient usage untuk audit trail
8. Returns batch ID

**Key Features:**
- ✅ Thread-safe (single transaction)
- ✅ Validates stock sufficiency before deducting
- ✅ Unit conversion support
- ✅ Complete audit trail
- ✅ Error handling dengan clear messages

**Stock Deduction Logic:**
```sql
-- For each recipe item:
v_quantity_to_deduct := v_recipe_item.quantity_needed * p_quantity;

-- Convert units if needed
v_quantity_to_deduct_converted := convert_unit(
    v_quantity_to_deduct,
    v_recipe_item.usage_unit,
    v_recipe_item.stock_unit
);

-- Record stock movement (auto-deduct)
PERFORM record_stock_movement(
    p_stock_item_id := v_recipe_item.stock_item_id,
    p_movement_type := 'production_use',
    p_quantity_change := -v_quantity_to_deduct_converted,
    p_reason := format('Production: %s (Batch: %s)', v_product_name, v_batch_id),
    p_reference_id := v_batch_id,
    p_reference_type := 'production_batch',
    p_created_by := auth.uid()
);
```

### 3.6 UI Components

#### **RecordProductionPage**
**Location:** `lib/features/production/presentation/record_production_page.dart`

**Features:**
- Product selection dropdown
- Quantity input
- Batch date picker
- Expiry date picker (optional)
- Batch number input (optional)
- Notes field
- Warning card tentang auto stock deduction
- Submit button

**Workflow:**
1. Select product
2. Enter quantity to produce
3. Set batch date & expiry (optional)
4. Add notes (optional)
5. Submit → Auto-deducts stock dari recipe!

#### **ProductionPlanningPage**
**Location:** `lib/features/production/presentation/production_planning_page.dart`

**Features:**
- Production planning calendar
- Batch listing
- Statistics
- Planning tools

### 3.7 Production Planning Preview

#### **ProductionPlan Preview**
**Purpose:** Preview production plan sebelum actually recording untuk check stock sufficiency.

**How it works:**
1. User selects product & quantity
2. System gets active recipe
3. Calculates materials needed untuk all batches
4. Checks stock sufficiency untuk each ingredient
5. Shows preview dengan:
   - Materials needed
   - Current stock
   - Shortage (if any)
   - Total production cost

**Location:** `lib/data/models/production_preview.dart`

### 3.8 FIFO System

**First-In-First-Out (FIFO)** untuk finished goods:

1. **Production:** Creates batch dengan `remaining_qty = quantity`
2. **Sales:** Deducts dari oldest batches first
3. **Tracking:** `remaining_qty` updated untuk each batch
4. **Costing:** Uses `cost_per_unit` dari batch untuk accurate costing

**Example:**
```
Batch 1 (Jan 1): 100 units @ RM 5.00 = RM 500
Batch 2 (Jan 5): 50 units @ RM 5.50 = RM 275

Sale of 120 units:
- Deduct 100 from Batch 1 (cost: RM 500)
- Deduct 20 from Batch 2 (cost: RM 110)
- Total cost: RM 610
```

### 3.9 Current Limitations

1. **No Production Scheduling**
   - Can't schedule future production
   - Only record past/completed production
   - Future enhancement: Production calendar dengan scheduling

2. **No Batch Quality Control**
   - Can't mark batches as passed/failed QC
   - Future enhancement: QC workflow

3. **No Production Templates**
   - Can't save common production plans
   - Future enhancement: Production templates

4. **Limited Reporting**
   - Basic statistics only
   - No detailed production reports
   - Future enhancement: Production analytics & reports

---

## 🔗 INTEGRATION POINTS

### Integration 1: Stock → Production

**Flow:**
```
Record Production → Get Recipe → Get Recipe Items → Deduct Stock Items
```

**Implementation:**
- `record_production_batch()` function auto-deducts stock
- Uses `record_stock_movement()` dengan type `production_use`
- Links via `reference_id` (batch_id) dan `reference_type` ('production_batch')

### Integration 2: Products → Recipes → Stock

**Flow:**
```
Product → Recipe → Recipe Items → Stock Items
```

**Implementation:**
- Recipe items reference stock items
- Recipe cost calculated dari stock item costs
- Product cost can use recipe cost atau manual override

### Integration 3: Production → Sales

**Flow:**
```
Production Batch → Sales → Deduct from Batch (FIFO)
```

**Implementation:**
- Sales deduct from production batches using FIFO
- `deductFIFO()` method handles batch deduction
- Updates `remaining_qty` untuk each batch
- Records movement dalam `production_batch_stock_movements`

### Integration 4: Stock → Shopping List

**Flow:**
```
Low Stock Items → Select Multiple → Add to Shopping List
```

**Implementation:**
- Stock page has selection mode
- Selected items can be added to shopping list
- Shopping list integrates dengan purchase orders

---

## ⚠️ KNOWN ISSUES & LIMITATIONS

### Issue 1: Cost Calculation Not Always Auto-Updated
**Problem:** When recipe changes, product cost doesn't always update automatically.

**Impact:** Product cost might be outdated.

**Solution:** Add database trigger untuk auto-update cost when recipe items change.

### Issue 2: Import API Not Implemented
**Problem:** Stock import parsing works tapi bulk import to database belum ada.

**Impact:** Can't bulk import stock items.

**Solution:** Implement bulk import API dalam repository.

### Issue 3: Unit Conversion Limited
**Problem:** Not all unit conversions supported.

**Impact:** Some recipes might fail jika units don't match.

**Solution:** Expand unit conversion table dengan more units.

### Issue 4: No Batch Expiry Tracking for Stock Items
**Problem:** Stock items don't track expiry dates, only production batches do.

**Impact:** Can't do FIFO based on expiry untuk raw materials.

**Solution:** Add batch tracking untuk stock items (future enhancement).

### Issue 5: Production Cost Calculation Complexity
**Problem:** Cost calculation involves multiple steps dan sometimes inconsistent.

**Impact:** Cost might not reflect actual production cost.

**Solution:** Simplify cost calculation flow dan add validation.

---

## 🚀 IMPROVEMENT OPPORTUNITIES

### Priority 1: Cost Calculation Auto-Update
**What:** Add trigger untuk auto-update product cost when recipe changes.

**Why:** Ensure cost always accurate.

**How:**
1. Create trigger on `recipe_items` table
2. When recipe item changes, recalculate recipe cost
3. Update product `materials_cost` dan `cost_per_unit`

### Priority 2: Bulk Import API
**What:** Implement bulk import untuk stock items.

**Why:** Save time untuk initial setup atau bulk updates.

**How:**
1. Add `bulkImportStockItems()` method dalam repository
2. Validate all items before inserting
3. Use batch insert untuk performance
4. Return summary dengan success/failure counts

### Priority 3: Enhanced Unit Conversion
**What:** Expand unit conversion support.

**Why:** Support more unit types untuk flexibility.

**How:**
1. Create unit conversion table dalam database
2. Add conversion rules (e.g., 1 kg = 1000 gram)
3. Update conversion function untuk use table
4. Add UI untuk manage conversion rules

### Priority 4: Production Planning Calendar
**What:** Add calendar view untuk production planning.

**Why:** Better planning dan scheduling.

**How:**
1. Create production calendar page
2. Show scheduled production dengan dates
3. Allow drag-and-drop untuk reschedule
4. Integration dengan stock availability

### Priority 5: Batch Tracking for Stock Items
**What:** Add batch/expiry tracking untuk stock items.

**Why:** Better inventory management dengan FIFO based on expiry.

**How:**
1. Add `stock_item_batches` table
2. Track expiry dates untuk each batch
3. Update stock deduction untuk use FIFO based on expiry
4. Add expiry alerts

### Priority 6: Production Analytics
**What:** Add detailed production reports dan analytics.

**Why:** Better insights untuk production efficiency.

**How:**
1. Create production analytics page
2. Show production trends
3. Cost analysis
4. Efficiency metrics
5. Ingredient usage reports

### Priority 7: Product Variants
**What:** Support product variants (sizes, flavors, etc.).

**Why:** Better product management untuk businesses dengan variants.

**How:**
1. Add `product_variants` table
2. Each variant can have own recipe
3. Update UI untuk support variants
4. Update sales untuk support variant selection

### Priority 8: Barcode Support
**What:** Add barcode scanning untuk products dan stock items.

**Why:** Faster data entry untuk POS dan stock management.

**How:**
1. Add barcode field untuk products dan stock items
2. Integrate barcode scanner package
3. Add scan button dalam relevant pages
4. Auto-fill form dari barcode scan

---

## 🏗️ TECHNICAL ARCHITECTURE

### Database Layer

**Tables:**
- `stock_items` - Raw materials inventory
- `stock_movements` - Complete audit trail
- `products` - Finished goods catalog
- `recipes` - Recipe definitions
- `recipe_items` - Recipe ingredients
- `production_batches` - Production records
- `production_ingredient_usage` - Ingredient usage audit
- `production_batch_stock_movements` - Finished goods movements

**Functions:**
- `record_stock_movement()` - Thread-safe stock updates
- `record_production_batch()` - Production dengan auto stock deduction
- `calculate_recipe_cost()` - Auto-calculate recipe cost
- `convert_unit()` - Unit conversion

**Triggers:**
- Auto-update timestamps
- Auto-calculate recipe cost when items change
- Prevent negative stock (if enabled)

### Repository Layer

**Pattern:** Direct Supabase client usage dengan error handling.

**Key Repositories:**
- `StockRepositorySupabase` - Stock operations
- `ProductsRepositorySupabase` - Product operations
- `ProductionRepository` - Production operations
- `RecipesRepositorySupabase` - Recipe operations

### UI Layer

**Pattern:** Feature-based organization dengan presentation layer.

**Key Pages:**
- `StockPage` - Stock list
- `StockHistoryPage` - Movement history
- `ProductListPage` - Product list
- `RecordProductionPage` - Record production
- `ProductionPlanningPage` - Production planning

**Widgets:**
- Reusable components untuk common UI patterns
- Smart filters
- Dialogs untuk quick actions

### State Management

**Pattern:** Direct Supabase calls dengan local state management.

**Note:** Some features use Riverpod, some use direct calls. Could be standardized.

---

## 📊 SUMMARY

### Current Status

✅ **Fully Implemented:**
- Stock management dengan complete audit trail
- Product management dengan recipe integration
- Production recording dengan auto stock deduction
- FIFO system untuk finished goods
- Unit conversion support
- Export/Import utilities

⚠️ **Needs Improvement:**
- Cost calculation auto-update
- Bulk import API
- Enhanced unit conversion
- Production planning calendar
- Batch tracking untuk stock items
- Production analytics

### Key Strengths

1. **Complete Audit Trail** - Semua movements tracked
2. **Thread-Safe Operations** - Database functions prevent race conditions
3. **Auto-Calculations** - Cost dan stock deductions automatic
4. **FIFO Support** - Proper inventory costing
5. **Integration** - Modul-modul well integrated

### Key Weaknesses

1. **Cost Updates** - Not always automatic
2. **Limited Features** - Some advanced features missing
3. **UI/UX** - Could be more intuitive
4. **Performance** - Some queries could be optimized
5. **Documentation** - Code comments could be better

---

**Document Version:** 1.0  
**Last Updated:** December 2025  
**Prepared For:** Improvement Planning
