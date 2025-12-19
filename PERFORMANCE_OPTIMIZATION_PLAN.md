# ⚡ POCKETBIZZ PERFORMANCE OPTIMIZATION PLAN

## 🔍 IDENTIFIED PERFORMANCE ISSUES

### 1. **Sequential Stock Loading (CRITICAL)**
**Location:** `product_list_page.dart`, `create_sale_page_enhanced.dart`

**Problem:**
```dart
// SLOW - Sequential loading
for (final product in products) {
  final stock = await _productionRepo.getTotalRemainingForProduct(product.id);
  stockMap[product.id] = stock;
}
```

**Impact:** Jika ada 50 products, ini akan buat 50 sequential API calls = sangat slow!

**Solution:** Load stock in parallel atau batch

---

### 2. **Excessive Data Fetching**
**Location:** `dashboard_page_optimized.dart`, `claims_page.dart`

**Problem:**
```dart
limit: 10000  // Fetching too much data at once
```

**Impact:** Slow initial load, high memory usage

**Solution:** Use proper pagination, fetch only what's needed

---

### 3. **No Search Debouncing**
**Location:** `product_list_page.dart`

**Problem:**
```dart
void _onSearchChanged() {
  setState(() {
    _searchQuery = _searchController.text.toLowerCase();
    _applyFilters(); // Runs on every keystroke
  });
}
```

**Impact:** UI lag when typing, unnecessary re-renders

**Solution:** Add debouncing (300-500ms delay)

---

### 4. **No Loading States for Button Actions**
**Location:** Multiple pages

**Problem:** Buttons don't show loading state, user doesn't know if action is processing

**Impact:** Poor UX, users click multiple times

**Solution:** Add loading indicators to buttons

---

### 5. **No Caching for Frequently Accessed Data**
**Location:** All pages

**Problem:** Same data fetched repeatedly (products, vendors, etc.)

**Impact:** Unnecessary API calls, slow navigation

**Solution:** Implement caching layer

---

### 6. **Heavy Dashboard Loading**
**Location:** `dashboard_page_optimized.dart`

**Problem:** Loading too many things at once, blocking UI

**Impact:** Dashboard feels slow, poor first impression

**Solution:** Progressive loading, show skeleton screens

---

## 🚀 OPTIMIZATION SOLUTIONS

### Solution 1: Parallel Stock Loading

**Before:**
```dart
// Sequential - SLOW
for (final product in products) {
  final stock = await _productionRepo.getTotalRemainingForProduct(product.id);
  stockMap[product.id] = stock;
}
```

**After:**
```dart
// Parallel - FAST
final stockFutures = products.map((product) async {
  try {
    final stock = await _productionRepo.getTotalRemainingForProduct(product.id);
    return MapEntry(product.id, stock);
  } catch (e) {
    return MapEntry(product.id, 0.0);
  }
});

final stockResults = await Future.wait(stockFutures);
final stockMap = Map<String, double>.fromEntries(stockResults);
```

---

### Solution 2: Search Debouncing

**Before:**
```dart
void _onSearchChanged() {
  setState(() {
    _searchQuery = _searchController.text.toLowerCase();
    _applyFilters();
  });
}
```

**After:**
```dart
Timer? _searchDebounce;

void _onSearchChanged() {
  _searchDebounce?.cancel();
  _searchDebounce = Timer(const Duration(milliseconds: 400), () {
    if (mounted) {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _applyFilters();
      });
    }
  });
}
```

---

### Solution 3: Button Loading States

**Before:**
```dart
ElevatedButton(
  onPressed: _createSale,
  child: Text('Create Sale'),
)
```

**After:**
```dart
ElevatedButton(
  onPressed: _isCreating ? null : _createSale,
  child: _isCreating
    ? SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
    : Text('Create Sale'),
)
```

---

### Solution 4: Progressive Dashboard Loading

**Before:**
```dart
// Load everything, show nothing until done
await Future.wait([...allData]);
setState(() => _loading = false);
```

**After:**
```dart
// Load critical data first, show immediately
final criticalData = await Future.wait([...criticalOnly]);
setState(() {
  _criticalData = criticalData;
  _showCriticalData = true;
});

// Load secondary data in background
Future.wait([...secondaryData]).then((data) {
  if (mounted) {
    setState(() => _secondaryData = data);
  }
});
```

---

### Solution 5: Data Caching

**Create:** `lib/core/services/cache_service.dart`

```dart
class CacheService {
  static final _cache = <String, CachedData>{};
  
  static Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher,
    {Duration ttl = const Duration(minutes: 5)}
  ) async {
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return cached.data as T;
    }
    
    final data = await fetcher();
    _cache[key] = CachedData(data, DateTime.now().add(ttl));
    return data;
  }
  
  static void clear(String key) => _cache.remove(key);
  static void clearAll() => _cache.clear();
}
```

---

### Solution 6: Skeleton Screens

**Create:** Loading placeholders that match final UI

```dart
Widget _buildSkeletonCard() {
  return Card(
    child: Column(
      children: [
        Skeleton(height: 20, width: double.infinity),
        SizedBox(height: 8),
        Skeleton(height: 16, width: 150),
      ],
    ),
  );
}
```

---

## 📋 IMPLEMENTATION PRIORITY

### **Priority 1 (CRITICAL - Fix Now)**
1. ✅ Parallel stock loading (product_list_page, create_sale_page)
2. ✅ Button loading states (all action buttons)
3. ✅ Search debouncing (product_list_page, sales_page)

### **Priority 2 (HIGH - Fix Soon)**
4. ✅ Reduce excessive data fetching (dashboard, claims)
5. ✅ Progressive dashboard loading
6. ✅ Add skeleton screens

### **Priority 3 (MEDIUM - Nice to Have)**
7. ✅ Data caching layer
8. ✅ Image optimization
9. ✅ Lazy loading for lists

---

## 🎯 EXPECTED IMPROVEMENTS

- **Product List Load Time:** 5-10s → 1-2s (80% faster)
- **Create Sale Load Time:** 3-5s → 0.5-1s (85% faster)
- **Dashboard Load Time:** 3-4s → 1-1.5s (70% faster)
- **Button Response:** Instant feedback (no more double-clicks)
- **Search Performance:** Smooth typing (no lag)

---

## 📝 NEXT STEPS

1. Implement parallel stock loading
2. Add search debouncing
3. Add button loading states
4. Optimize dashboard loading
5. Add skeleton screens
6. Implement caching layer

