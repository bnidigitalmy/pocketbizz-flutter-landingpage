# 🎯 Cache Implementation Priority Guide

## 📊 Analysis Criteria

Features dinilai berdasarkan:
1. **Frequency of Access** - Berapa kerap user buka page ini?
2. **Data Size** - Berapa besar data yang dimuat?
3. **Data Stability** - Berapa kerap data berubah?
4. **Cross-Feature Usage** - Digunakan di multiple places?
5. **User Impact** - Berapa besar impact kepada user experience?

---

## 🔥 PRIORITY 1: CRITICAL (Implement First)

### 1. ✅ Dashboard (ALREADY DONE)
**Status:** ✅ **IMPLEMENTED**
- **Frequency:** ⭐⭐⭐⭐⭐ (User buka setiap hari)
- **Data Size:** Large (multiple queries)
- **Data Stability:** Medium (changes frequently)
- **Impact:** Very High
- **Cache Keys:**
  - `dashboard_stats`
  - `dashboard_v2`
  - `dashboard_pending_tasks`
  - `dashboard_sales_by_channel`
  - `dashboard_urgent_issues`

### 2. 🎯 Products List Page
**Status:** ⚠️ **NEEDS CACHE**
- **Frequency:** ⭐⭐⭐⭐⭐ (Very frequently accessed)
- **Data Size:** Medium-Large (50-200 products)
- **Data Stability:** Medium (products don't change often)
- **Impact:** Very High (slow loading sekarang)
- **Cache Keys:**
  - `products_list` (TTL: 10 min)
  - `products_stock_map` (TTL: 5 min)
  - `products_categories` (TTL: 30 min)
- **Real-time Invalidation:** 
  - `products` table changes
  - `stock_items` changes (affects stock display)

**Why:** User scroll product list banyak kali, load stock untuk setiap product = slow!

### 3. 🎯 Stock Page
**Status:** ⚠️ **NEEDS CACHE**
- **Frequency:** ⭐⭐⭐⭐ (Frequently accessed)
- **Data Size:** Large (100+ stock items + batch summaries)
- **Data Stability:** Medium (changes when stock updated)
- **Impact:** High (slow loading sekarang)
- **Cache Keys:**
  - `stock_items_list` (TTL: 5 min)
  - `stock_batch_summaries` (TTL: 3 min)
  - `stock_statistics` (TTL: 5 min)
- **Real-time Invalidation:**
  - `stock_items` table changes
  - `stock_movements` changes
  - `production_batches` changes

**Why:** Stock page load banyak data (items + batch summaries), boleh cache untuk faster access.

### 4. 🎯 Vendors List
**Status:** ⚠️ **NEEDS CACHE**
- **Frequency:** ⭐⭐⭐⭐ (Frequently accessed for deliveries/claims)
- **Data Size:** Small-Medium (10-50 vendors)
- **Data Stability:** High (vendors rarely change)
- **Impact:** Medium-High
- **Cache Keys:**
  - `vendors_list` (TTL: 30 min - vendors rarely change)
  - `vendors_active_only` (TTL: 30 min)
- **Real-time Invalidation:**
  - `vendors` table changes

**Why:** Vendors list digunakan di multiple places (deliveries, claims, vendor detail), cache untuk faster access.

---

## 🟡 PRIORITY 2: HIGH (Implement Soon)

### 5. Sales Page
**Status:** ⚠️ **NEEDS CACHE**
- **Frequency:** ⭐⭐⭐⭐ (Frequently accessed)
- **Data Size:** Medium (50-200 sales records)
- **Data Stability:** Low (new sales added frequently)
- **Impact:** Medium
- **Cache Keys:**
  - `sales_list` (TTL: 2 min - changes frequently)
  - `sales_statistics` (TTL: 5 min)
- **Real-time Invalidation:**
  - `sales` table changes
  - `sale_items` changes

**Why:** Sales list boleh cache untuk faster initial load, tapi TTL pendek sebab data kerap berubah.

### 6. Bookings Page
**Status:** ⚠️ **NEEDS CACHE**
- **Frequency:** ⭐⭐⭐ (Moderately accessed)
- **Data Size:** Medium (50-100 bookings)
- **Data Stability:** Medium (bookings change when status updated)
- **Impact:** Medium
- **Cache Keys:**
  - `bookings_list` (TTL: 5 min)
  - `bookings_statistics` (TTL: 5 min)
- **Real-time Invalidation:**
  - `bookings` table changes
  - `booking_items` changes

**Why:** Bookings page load data setiap kali, boleh cache untuk faster access.

### 7. Categories List
**Status:** ⚠️ **NEEDS CACHE**
- **Frequency:** ⭐⭐⭐ (Used in product forms, filters)
- **Data Size:** Small (10-30 categories)
- **Data Stability:** Very High (categories rarely change)
- **Impact:** Medium
- **Cache Keys:**
  - `categories_list` (TTL: 1 hour - very stable)
- **Real-time Invalidation:**
  - `categories` table changes

**Why:** Categories digunakan di banyak places (product forms, filters), sangat stable, perfect untuk cache.

### 8. Suppliers List
**Status:** ⚠️ **NEEDS CACHE**
- **Frequency:** ⭐⭐⭐ (Used in purchase orders, stock)
- **Data Size:** Small (10-30 suppliers)
- **Data Stability:** High (suppliers rarely change)
- **Impact:** Medium
- **Cache Keys:**
  - `suppliers_list` (TTL: 30 min)
- **Real-time Invalidation:**
  - `suppliers` table changes

**Why:** Suppliers digunakan di purchase orders dan stock management, boleh cache.

---

## 🟢 PRIORITY 3: MEDIUM (Nice to Have)

### 9. Purchase Orders Page
**Status:** ⚠️ **CAN USE CACHE**
- **Frequency:** ⭐⭐ (Moderately accessed)
- **Data Size:** Medium (20-50 POs)
- **Data Stability:** Medium (status changes)
- **Impact:** Low-Medium
- **Cache Keys:**
  - `purchase_orders_list` (TTL: 5 min)
- **Real-time Invalidation:**
  - `purchase_orders` table changes

### 10. Deliveries Page
**Status:** ⚠️ **CAN USE CACHE**
- **Frequency:** ⭐⭐ (Moderately accessed)
- **Data Size:** Medium (30-100 deliveries)
- **Data Stability:** Medium
- **Impact:** Low-Medium
- **Cache Keys:**
  - `deliveries_list` (TTL: 5 min)
- **Real-time Invalidation:**
  - `vendor_deliveries` table changes

### 11. Claims Page
**Status:** ⚠️ **CAN USE CACHE**
- **Frequency:** ⭐⭐ (Moderately accessed)
- **Data Size:** Medium (20-50 claims)
- **Data Stability:** Medium
- **Impact:** Low-Medium
- **Cache Keys:**
  - `claims_list` (TTL: 5 min)
  - `claims_statistics` (TTL: 5 min)
- **Real-time Invalidation:**
  - `consignment_claims` table changes

### 12. Reports Page
**Status:** ⚠️ **CAN USE CACHE**
- **Frequency:** ⭐⭐ (Moderately accessed)
- **Data Size:** Large (aggregated data)
- **Data Stability:** Low (changes with new transactions)
- **Impact:** Medium
- **Cache Keys:**
  - `reports_sales_by_channel` (TTL: 5 min)
  - `reports_profit_loss` (TTL: 5 min)
- **Real-time Invalidation:**
  - Sales/expenses changes

---

## 📋 IMPLEMENTATION CHECKLIST

### Priority 1 (Do First)
- [x] Dashboard - ✅ DONE
- [ ] Products List Page
- [ ] Stock Page
- [ ] Vendors List

### Priority 2 (Do Soon)
- [ ] Sales Page
- [ ] Bookings Page
- [ ] Categories List
- [ ] Suppliers List

### Priority 3 (Nice to Have)
- [ ] Purchase Orders Page
- [ ] Deliveries Page
- [ ] Claims Page
- [ ] Reports Page

---

## 🎯 RECOMMENDED TTL VALUES

| Data Type | TTL | Reason |
|-----------|-----|--------|
| **Very Stable** (Categories, Suppliers) | 30 min - 1 hour | Rarely changes |
| **Moderately Stable** (Products, Vendors) | 10-30 min | Changes occasionally |
| **Frequently Changing** (Sales, Stock) | 2-5 min | Changes frequently |
| **Very Dynamic** (Notifications, Urgent Issues) | 1-2 min | Changes very frequently |

---

## 🔄 REAL-TIME INVALIDATION STRATEGY

### Pattern untuk setiap feature:
```dart
// 1. Setup real-time subscription
_subscription = supabase
  .from('table_name')
  .stream(primaryKey: ['id'])
  .listen((data) {
    // 2. Invalidate related caches
    CacheService.invalidateMultiple([
      'feature_list',
      'feature_statistics',
      'related_feature_cache',
    ]);
    // 3. Reload data
    _loadData();
  });
```

---

## 💡 BEST PRACTICES

1. **Cache Keys Naming:**
   - Use descriptive names: `products_list`, `stock_items_list`
   - Include filters if needed: `products_list_category_food`
   - Use consistent naming convention

2. **TTL Selection:**
   - Start with longer TTL (safer)
   - Reduce if users complain about stale data
   - Increase if performance is still slow

3. **Invalidation:**
   - Always invalidate on real-time changes
   - Invalidate related caches together
   - Clear cache on logout (security)

4. **Monitoring:**
   - Use `CacheService.getStats()` untuk debugging
   - Monitor cache hit/miss rates
   - Adjust TTL based on usage patterns

---

## 📈 EXPECTED IMPROVEMENTS

### Products List:
- **Before:** 2-5 saat untuk load products + stock
- **After:** < 0.1 saat dari cache (20-50x faster!)

### Stock Page:
- **Before:** 3-5 saat untuk load items + batch summaries
- **After:** < 0.1 saat dari cache (30-50x faster!)

### Vendors List:
- **Before:** 1-2 saat setiap kali
- **After:** < 0.1 saat dari cache (10-20x faster!)

---

## 🚀 NEXT STEPS

1. **Implement Priority 1 features** (Products, Stock, Vendors)
2. **Test performance improvements**
3. **Monitor cache hit rates**
4. **Adjust TTL values based on usage**
5. **Implement Priority 2 features**

