# Cache Implementation Priority

## ✅ Completed (5 modules)
1. ✅ **Products** - Core module, frequently accessed
2. ✅ **Sales** - High volume, frequently accessed
3. ✅ **Expenses** - Frequently accessed, pagination needed
4. ✅ **Vendors** - Core module for consignment
5. ✅ **Stock Items** - Critical for inventory management

---

## 🔥 High Priority (Should implement next)

### 1. **Categories** ⭐⭐⭐⭐⭐
**Why:**
- **35+ usages** across codebase (highest frequency!)
- Used in dropdowns, product forms, filters
- Small dataset (usually < 50 items) - perfect for cache
- Rarely changes - ideal for long TTL

**Impact:**
- High egress reduction (called on every product page load)
- Instant dropdown rendering
- Better UX for product creation

**Files:**
- `lib/data/repositories/categories_repository_supabase.dart`
- Model: `lib/data/models/category.dart`

---

### 2. **Suppliers** ⭐⭐⭐⭐
**Why:**
- Used in stock management, purchase orders
- Frequently accessed when adding stock items
- Small to medium dataset
- Changes infrequently

**Impact:**
- Faster stock item creation
- Reduced egress for supplier dropdowns

**Files:**
- `lib/data/repositories/suppliers_repository_supabase.dart`
- Model: `lib/data/models/supplier.dart`

---

### 3. **Deliveries** ⭐⭐⭐⭐
**Why:**
- Used in vendor management
- Complex queries with joins (high egress)
- Pagination needed
- Frequently accessed in vendor detail pages

**Impact:**
- Significant egress reduction (complex queries)
- Faster vendor detail page loads

**Files:**
- `lib/data/repositories/deliveries_repository_supabase.dart`
- Model: `lib/data/models/delivery.dart`

---

### 4. **Bookings** ⭐⭐⭐⭐
**Why:**
- Used in dashboard (frequently accessed)
- Booking alerts widget
- Medium dataset with pagination
- Real-time updates needed

**Impact:**
- Faster dashboard loading
- Better booking management UX

**Files:**
- `lib/data/repositories/bookings_repository_supabase.dart`
- Model: `Booking` (defined in repository file)

---

### 5. **Purchase Orders** ⭐⭐⭐
**Why:**
- Used in procurement workflow
- Dashboard purchase recommendations
- Medium dataset
- Less frequently accessed than others

**Impact:**
- Moderate egress reduction
- Faster purchase order management

**Files:**
- `lib/data/repositories/purchase_order_repository_supabase.dart`
- Model: Check repository for model definition

---

## 📊 Medium Priority (Consider later)

### 6. **Claims (Consignment Claims)** ⭐⭐⭐
**Why:**
- Used in consignment system
- Dashboard claim alerts
- Complex queries with calculations
- Medium frequency

**Impact:**
- Moderate egress reduction
- Faster claim processing

**Files:**
- `lib/data/repositories/consignment_claims_repository_supabase.dart`
- Model: `lib/data/models/consignment_claim.dart`

---

### 7. **Finished Products** ⭐⭐⭐
**Why:**
- Used in production workflow
- Dashboard alerts
- Medium dataset
- Less frequently accessed

**Impact:**
- Moderate egress reduction
- Better production management

**Files:**
- `lib/data/repositories/finished_products_repository_supabase.dart`

---

### 8. **Recipes** ⭐⭐
**Why:**
- Used in production planning
- Less frequently accessed
- Medium dataset
- Changes infrequently

**Impact:**
- Low to moderate egress reduction
- Faster recipe loading

**Files:**
- `lib/data/repositories/recipes_repository_supabase.dart`

---

## 🔵 Low Priority (Optional)

### 9. **Dashboard Stats** ⭐⭐
**Why:**
- Already using CacheService (in-memory)
- Complex aggregations
- Real-time updates needed
- Can enhance with persistent cache

**Impact:**
- Better offline experience
- Faster dashboard loads

**Note:** Currently using in-memory cache, can enhance to persistent

---

### 10. **Business Profile** ⭐
**Why:**
- Single record per user
- Rarely changes
- Small dataset
- Already fast

**Impact:**
- Minimal impact (already fast)
- Better offline experience

**Files:**
- `lib/data/repositories/business_profile_repository_supabase.dart`

---

## 📈 Implementation Strategy

### Phase 1: High Priority (Next Sprint)
1. **Categories** - Highest impact, easiest to implement
2. **Suppliers** - High usage, straightforward
3. **Deliveries** - Complex queries, high egress

### Phase 2: Medium Priority
4. **Bookings** - Dashboard integration
5. **Purchase Orders** - Procurement workflow

### Phase 3: Low Priority
6. **Claims** - Consignment system
7. **Finished Products** - Production workflow
8. **Recipes** - Production planning

---

## 💡 Recommendations

### Immediate Next Steps:
1. **Categories** - Implement ASAP (highest frequency, easiest)
2. **Suppliers** - Quick win, high usage
3. **Deliveries** - Complex queries = high egress savings

### Why Categories First?
- **35+ usages** = called very frequently
- Small dataset = easy to cache
- Rarely changes = long TTL possible
- Used in dropdowns = instant UX improvement
- Simple implementation = quick to add

### Expected Egress Reduction:
- **Categories**: ~20-30% reduction (frequently called)
- **Suppliers**: ~10-15% reduction
- **Deliveries**: ~15-20% reduction (complex queries)
- **Total Phase 1**: ~45-65% additional egress reduction

---

## 📝 Notes

- All cached repositories follow same pattern
- Use `*_repository_supabase_cached.dart` naming
- Support delta fetch with `updated_at`
- Include force refresh option
- Add UI update callbacks

