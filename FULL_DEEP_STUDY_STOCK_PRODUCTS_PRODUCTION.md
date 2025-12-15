# 📚 FULL DEEP STUDY — Modul Stok, Produk & Pengeluaran (PocketBizz Flutter)

**Tarikh:** Disember 2025  
**Repo:** `pocketbizz-flutter`  
**Skop:** Flutter (UI + repository Supabase) + SQL migrations yang memacu data model  

---

## 🧭 Ringkasan Eksekutif

Tiga modul ini membentuk “core operations loop” app:

- **Stok (bahan mentah / ingredients)**: `stock_items` + `stock_movements` + (optional) `stock_item_batches` untuk expiry/FIFO.
- **Produk (finished goods)**: `products` + kategori + imej + costing field (units/labour/packaging).
- **Pengeluaran (production batches)**: `production_batches` dihasilkan melalui fungsi DB `record_production_batch()` yang akan **auto-deduct stok** berdasarkan recipe aktif.

**Aha penting (berdasarkan kod + SQL):**

- **Stok Produk (finished goods)** di UI dikira daripada **jumlah `remaining_qty` dalam `production_batches`** (bukan dari table `products`).
- **Deduction bahan mentah** dibuat secara **transactional di database** melalui `record_stock_movement()` ketika produksi direkod.
- Repo/kod expect schema “recipe-centric” (**`recipes` + `recipe_items.recipe_id`**), tetapi terdapat juga migration lama yang define `recipe_items.product_id`. Ini penting untuk elak “migration drift”.

---

## 🗂️ Peta Fail (File Map) — Di Mana Kod Utama Berada

### Entry & Route
- `lib/main.dart`
  - Route utama:
    - `/stock` → `StockPage`
    - `/products` → `ProductListPage`
    - `/production` → `ProductionPlanningPage`
    - `/production/record` → `RecordProductionPage`

### Modul Stok
- UI:
  - `lib/features/stock/presentation/stock_page.dart` — list stok + filter + export/import + selection → shopping list
  - `lib/features/stock/presentation/stock_detail_page.dart` — detail + tab History + tab Batches
  - `lib/features/stock/presentation/stock_history_page.dart` — timeline stock_movements (nota: direct Supabase call)
  - `lib/features/stock/presentation/adjust_stock_page.dart` — adjust/add/remove via `record_stock_movement`
  - `lib/features/stock/presentation/batch_management_page.dart` — UI batch raw material
  - `lib/features/stock/presentation/widgets/add_batch_dialog.dart` — create batch (RPC `record_stock_item_batch`)
- Repository:
  - `lib/data/repositories/stock_repository_supabase.dart`
- Models:
  - `lib/data/models/stock_item.dart`
  - `lib/data/models/stock_movement.dart`
  - `lib/data/models/stock_item_batch.dart`
- Utils:
  - `lib/core/utils/unit_conversion.dart` — conversion map (lebih lengkap dari SQL)
  - `lib/core/utils/stock_export_import.dart` — import/export

### Modul Produk
- UI:
  - `lib/features/products/presentation/product_list_page.dart`
  - `lib/features/products/presentation/add_product_with_recipe_page.dart` (workflow utama create product + recipe + auto-cost)
  - `lib/features/products/presentation/edit_product_page.dart`
  - `lib/features/products/presentation/add_product_page.dart` (legacy/simple)
- Repository:
  - `lib/data/repositories/products_repository_supabase.dart`
- Model:
  - `lib/data/models/product.dart`

### Modul Pengeluaran
- UI:
  - `lib/features/production/presentation/production_planning_page.dart`
  - `lib/features/production/presentation/widgets/production_planning_dialog.dart` — flow 3-step: select → preview → confirm
  - `lib/features/production/presentation/record_production_page.dart` — direct record
- Repository:
  - `lib/data/repositories/production_repository_supabase.dart`
- Models:
  - `lib/data/models/production_batch.dart`
  - `lib/data/models/production_preview.dart`

### Integrasi Shopping List (untuk bahan kurang)
- `lib/data/repositories/shopping_cart_repository_supabase.dart`

---

## 🧱 Database — “Source of Truth” & Migration Drift

### 1) Stok

**Tables utama:**
- `stock_items` — current_quantity, unit, package_size, purchase_price, threshold, dll.
- `stock_movements` — audit trail; update dilakukan melalui **DB function** `record_stock_movement()`.

**Batch raw materials (optional tapi sudah ada):**
- `stock_item_batches`
- view `stock_item_batches_summary`
- function `record_stock_item_batch(...)`
- function `deduct_from_stock_item_batches(...)` (FIFO + expiry priority)

**Migration rujukan:**
- `db/migrations/add_stock_management.sql`
- `db/migrations/2025-12-15_add_stock_item_batches.sql`

### 2) Produk

**Table: `products`**
- Field costing: `units_per_batch`, `labour_cost`, `other_costs`, `packaging_cost`, `materials_cost`, `total_cost_per_batch`, `cost_per_unit`.
- Field visual: `image_url`.
- Kategori: `category` (string) dan/atau `category_id` (bergantung schema).

### 3) Recipes & Production — penting untuk pastikan schema yang betul

Dalam repo ni ada **lebih dari satu “generasi” migration**:

- **Generasi lama (product-centric recipe_items)**: `recipe_items.product_id` + field `cost_per_recipe`  
  - Contoh: `db/migrations/add_recipes_and_production*.sql`, `db/migrations/CLEAN_AND_INSTALL_RECIPES.sql`
- **Generasi baru (recipe-centric)**: ada table `recipes` dan `recipe_items.recipe_id`, serta `production_ingredient_usage`, dan cost per unit di `recipe_items`  
  - Contoh: `db/migrations/FIX_RECIPES_STRUCTURE_FINAL.sql`

**Kod Flutter terkini** (`RecipesRepositorySupabase`, `RecipeBuilderPage`, `record_production_batch` RPC) secara konsisten expect **generasi baru**:
- Table `recipes`
- Table `recipe_items` dengan `recipe_id`
- Function `calculate_recipe_cost(recipe_uuid UUID)`
- Function `record_production_batch(p_product_id, p_quantity, ...)` yang lookup recipe aktif dari table `recipes`.

**Action item penting bila deploy/upgrade DB:** pastikan migration yang applied memang menghasilkan schema yang sama dengan kod (elak “column does not exist” / “function signature mismatch”).

---

## 📦 Modul 1 — Stok (Stock Management) — Deep Study

### Data Model

- `StockItem` = ingredient/bahan mentah.
- `StockMovement` = audit trail transaksi (purchase/replenish/production_use/waste/etc).
- `StockItemBatch` = batch pembelian bahan mentah dengan expiry + remaining_qty.

### Repository (Data Access)

`StockRepository` (`lib/data/repositories/stock_repository_supabase.dart`) menyediakan:
- CRUD `stock_items`
- `recordStockMovement()` → Supabase RPC `record_stock_movement` (**thread-safe**)
- Movement list & stats
- Batch APIs:
  - `getStockItemBatches()`, `getBatchSummary()` → view `stock_item_batches_summary`
  - `createStockItemBatch()` → RPC `record_stock_item_batch`

### UI Flow utama (End-to-End)

1) **List stok**
- `StockPage` load list → kemudian loop setiap item untuk load `getBatchSummary(item.id)` (nota: berpotensi N+1).

2) **Detail stok**
- `StockDetailPage` reload:
  - stock item terkini
  - movements
  - batch list + summary

3) **Adjust stok**
- `AdjustStockPage` minta quantity dalam “pek/pcs” kemudian convert ke base unit:
  - `quantityChange = (pek * packageSize) * (+/-)`
  - save via RPC `record_stock_movement`.

4) **Batch tracking**
- `BatchManagementPage` list semua `stock_item_batches`.
- `AddBatchDialog` create batch:
  - input `pek/pcs` → convert to base unit (`pek * packageSize`)
  - RPC `record_stock_item_batch` dengan `recordMovement=true` → akan create batch + create movement `purchase`.

### Integrasi keluar modul

- **Ke Production**: bahan mentah akan ditolak ketika production direkod.
- **Ke Shopping List**:
  - selection mode di `StockPage` → `ShoppingListDialog` → add ke shopping cart.

---

## 🛍️ Modul 2 — Produk (Products) — Deep Study

### Konsep utama

Produk adalah finished goods. App menyimpan:
- info jualan (sku/name/unit/sale_price)
- costing (cost_price + cost_per_unit + total_cost_per_batch dsb.)
- imej (Supabase Storage)
- kategori

### Repository

`ProductsRepositorySupabase`:
- `createProduct()`, `getAll()`, `listProducts()`, `updateProduct()`, `deleteProduct()`
- Filtering by `business_owner_id` + `is_active` untuk kebanyakan query.

### UI Flow

1) **List produk**
- `ProductListPage`:
  - load products via `listProducts()`
  - untuk setiap product, fetch stok available via `ProductionRepository.getTotalRemainingForProduct(product.id)`
  - kirakan summary (outOfStock, lowStock)
  - Nota: ini juga N+1 pattern.

2) **Tambah produk + resepi (workflow utama)**
- `AddProductWithRecipePage`:
  - load stock items + categories
  - user isi bahan resepi; app kira kos live menggunakan:
    - `purchasePrice / packageSize` (unit price)
    - `UnitConversion.convert(...)` untuk align unit resepi dengan unit stok
  - Save flow:
    - create `products` (dengan `costPerUnit`, `totalCostPerBatch`, dsb.)
    - upload image (optional) → update `products.image_url`
    - create `recipes`
    - create `recipe_items`

3) **Edit produk**
- `EditProductPage`:
  - boleh update price/sku/category/image
  - memaparkan stok available (via production repo)
  - boleh navigate ke `RecipeBuilderPage`

### Integrasi

- Produk → Recipe → Production:
  - Recipe menentukan deduction bahan mentah ketika produksi.
- Produk stock → diambil dari `production_batches.remaining_qty`.

---

## 🏭 Modul 3 — Pengeluaran (Production) — Deep Study

### Data model

`ProductionBatch`:
- `quantity` (jumlah unit produced)
- `remaining_qty` (stok tinggal untuk FIFO)
- `cost_per_unit` snapshot (untuk costing & audit)
- `expiry_date` (untuk finished goods)

`ProductionPlan` (preview):
- material needed per ingredient + sufficiency + shortage + packagesNeeded

### Repository

`ProductionRepository`:
- list batches (`getAllBatches`, `getBatchesByDateRange`, `getRecentBatches`)
- record production:
  - `recordProductionBatch()` → RPC `record_production_batch`
- FIFO finished goods:
  - `deductFIFO()`, `deductFromBatch()`, `_logStockMovement()` → table `production_batch_stock_movements`
- preview production plan:
  - `previewProductionPlan()` → kira shortage dengan unit conversion (Flutter side)

### UI Flow

#### A) Planning flow (recommended)
- `ProductionPlanningPage` → `ProductionPlanningDialog`
  1. Select produk + kuantiti (UI label “batches”, tapi implementation treat as “jumlah batch” hanya di preview layer)
  2. Preview:
     - panggil `previewProductionPlan(productId, quantity)`
     - jika ada shortage → boleh add to shopping list (bulk add via repository)
  3. Confirm:
     - enforce `allStockSufficient == true`
     - create `ProductionBatchInput(quantity: _quantity * unitsPerBatch)` (ini menghantar **total units**)

#### B) Direct record (perlu disemak definisi kuantiti)
- `RecordProductionPage`:
  - menghantar `ProductionBatchInput(quantity: int.parse(controller))` tanpa multiply `unitsPerBatch`
  - Ini berpotensi conflict dengan fungsi DB yang mentafsir `p_quantity` sebagai **total units** (lihat migration fix unit conversion).

### Fungsi DB kritikal

`record_production_batch(p_product_id, p_quantity, ...)`:
- lookup recipe aktif untuk product
- **FIRST PASS**: validate stok cukup (dengan unit conversion pada versi “fixed”)
- **SECOND PASS**: deduct stok via `record_stock_movement` (type `production_use`)
- create `production_batches` row
- insert `production_ingredient_usage` untuk audit

**Rujukan migration:**
- `db/migrations/create_record_production_batch_function.sql`
- `db/migrations/2025-12-10_fix_production_batch_unit_conversion.sql`
- `db/migrations/2025-12-10_create_production_batch_stock_movements.sql`

---

## 🔗 Integration Points (Sambungan Antara Modul)

### 1) Stock → Recipe → Production (core loop)

```
StockItem (purchase_price/package_size/unit)
  └─ RecipeItem(quantity_needed + usage_unit)
       └─ record_production_batch()
            ├─ validate stock sufficiency
            ├─ record_stock_movement(production_use)
            └─ production_batches.remaining_qty += quantity produced
```

### 2) Production → Product stock display

```
ProductListPage
  └─ getTotalRemainingForProduct(productId)
       └─ SUM(production_batches.remaining_qty WHERE product_id=...)
```

### 3) Production planning → Shopping List

```
previewProductionPlan()
  └─ shortage → ShoppingCartRepository.addToCart(...)
```

---

## ⚠️ Known Issues / Risiko Teknikal (berdasarkan audit kod + SQL)

### 1) Migration drift (schema recipes lama vs baru)
- Kod expect schema `recipes` + `recipe_items.recipe_id`, tetapi ada migration lain yang define `recipe_items.product_id`.  
**Impact**: RPC/queries boleh fail bila schema tak selari.

### 2) Definisi `quantity` produksi tidak konsisten
- Planning dialog hantar `quantity = batches * unitsPerBatch` (total units).
- RecordProductionPage hantar `quantity` terus dari input (ambiguous).  
**Impact**: deduction bahan mentah & cost boleh tersasar.

### 3) Unit conversion tidak konsisten antara Flutter vs SQL
- Flutter `UnitConversion` sangat lengkap.
- SQL `convert_unit()` (migration) lebih limited.  
**Impact**: preview (Flutter) mungkin kata “cukup”, tapi server deduction mungkin interpret berbeza / gagal.

### 4) N+1 query patterns
- `ProductListPage`: load stok per product (loop) → lambat bila product banyak.
- `StockPage`: load batch summary per stock item (loop).  
**Impact**: latency tinggi & UI terasa “lag”.

### 5) Inconsistent data access pattern
- Contoh `StockHistoryPage` guna direct `supabase.from(...)` sedangkan modul lain guna repository.

---

## 🚀 Cadangan Improvement (Prioriti Praktikal)

### P0 — Betulkan “quantity semantics” untuk production
- Standardkan: `p_quantity` = **total units produced** (atau = batches).  
Kemudian selaraskan:
- `ProductionPlanningDialog` input,
- `RecordProductionPage` label/logic,
- fungsi DB `record_production_batch`.

### P0 — Lock schema recipes yang dipakai
- Pilih dan “freeze” migration path:
  - kalau guna schema `recipes` + `recipe_items.recipe_id`, pastikan semua env apply migration yang betul.
- Tambah `README`/checklist migration yang wajib sebelum run app.

### P1 — Konsistenkan unit conversion
- Option A: expand SQL `convert_unit()` supaya match Flutter (atau guna table-driven conversions).
- Option B: pindahkan semua conversion ke DB sahaja dan pastikan preview guna data DB (lebih consistent).

### P1 — Hapuskan N+1 untuk stok summary
- Buat view/RPC:
  - `product_stock_summary` (SUM remaining_qty group by product_id)
  - `stock_batch_summary` (already ada view, tapi fetch boleh dibuat sekali untuk semua id).

### P2 — Standardize repository usage
- Refactor page yang direct Supabase call supaya guna repository (lebih testable & konsisten error handling).

---

## ✅ Status “Deep Study”

Dokumen ini dibuat berdasarkan:
- audit fail Flutter UI & repositories,
- audit model,
- audit migrations SQL berkaitan recipe/production/batches,
- semakan integration points (shopping list, FIFO, expiry).

Jika anda nak saya teruskan ke fasa seterusnya, saya boleh:
- buat **audit performance** dan implement “summary RPC/view” untuk buang N+1,
- betulkan **inconsistency quantity** (UI + DB),
- buat **migration playbook** yang jelas untuk environment Supabase anda.


