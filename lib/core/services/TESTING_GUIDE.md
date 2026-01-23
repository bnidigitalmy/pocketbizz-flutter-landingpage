# Testing Guide - Persistent Cache Implementation

## Quick Test Checklist

### 1. ✅ Compilation Test
```bash
cd pocketbizz-app
flutter pub get
flutter analyze
```

### 2. ✅ Basic Functionality Test

#### Test Categories (Highest Priority)
```dart
import 'package:pocketbizz/data/repositories/categories_repository_supabase_cached.dart';

// In your test page or widget
final categoriesRepo = CategoriesRepositorySupabaseCached();

// Test 1: First load (should fetch from Supabase)
final categories1 = await categoriesRepo.getAllCached();
print('✅ First load: ${categories1.length} categories');

// Test 2: Second load (should load from cache instantly)
final startTime = DateTime.now();
final categories2 = await categoriesRepo.getAllCached();
final duration = DateTime.now().difference(startTime);
print('✅ Cached load: ${categories2.length} categories in ${duration.inMilliseconds}ms');
// Should be < 50ms for cached load

// Test 3: Force refresh
final categories3 = await categoriesRepo.getAllCached(forceRefresh: true);
print('✅ Force refresh: ${categories3.length} categories');

// Test 4: Background sync
categoriesRepo.syncInBackground(
  onDataUpdated: (freshCategories) {
    print('✅ Background sync completed: ${freshCategories.length} categories');
  },
);
```

#### Test Products
```dart
import 'package:pocketbizz/data/repositories/products_repository_supabase_cached.dart';

final productsRepo = ProductsRepositorySupabaseCached();

// Test cache
final products = await productsRepo.getAllCached();
print('✅ Products loaded: ${products.length}');
```

#### Test Sales
```dart
import 'package:pocketbizz/data/repositories/sales_repository_supabase_cached.dart';

final salesRepo = SalesRepositorySupabaseCached();

// Test with filters
final sales = await salesRepo.listSalesCached(
  channel: 'walk-in',
  limit: 50,
);
print('✅ Sales loaded: ${sales.length}');
```

### 3. ✅ Cache Statistics Test
```dart
import 'package:pocketbizz/core/services/persistent_cache_service.dart';

// Get cache stats
final stats = await PersistentCacheService.getStats();
print('Cache Stats:');
stats.forEach((key, value) {
  print('  $key: ${value['count']} items, last sync: ${value['last_sync']}');
});
```

### 4. ✅ Offline Test
```dart
// 1. Load data with internet (cache it)
final categories = await categoriesRepo.getAllCached();

// 2. Turn off internet / airplane mode

// 3. Try to load again (should work from cache)
final cachedCategories = await categoriesRepo.getAllCached();
print('✅ Offline load: ${cachedCategories.length} categories');
// Should still work!
```

### 5. ✅ Delta Fetch Test
```dart
// 1. Load initial data
await categoriesRepo.getAllCached();

// 2. Wait a bit
await Future.delayed(Duration(seconds: 2));

// 3. Create/update a category in Supabase dashboard

// 4. Load again (should trigger delta fetch)
final updated = await categoriesRepo.getAllCached();
// Check logs for "Delta fetch" message
```

### 6. ✅ Cache Invalidation Test
```dart
// Load data
await categoriesRepo.getAllCached();

// Invalidate cache
await categoriesRepo.invalidateCache();

// Load again (should fetch fresh)
final fresh = await categoriesRepo.getAllCached(forceRefresh: false);
// Should fetch from Supabase, not cache
```

## Integration Test in UI

### Example: Update Categories Page
```dart
// In categories_page.dart
import 'package:pocketbizz/data/repositories/categories_repository_supabase_cached.dart';

class CategoriesPage extends StatefulWidget {
  @override
  _CategoriesPageState createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _cachedRepo = CategoriesRepositorySupabaseCached();
  List<Category> _categories = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadCategories();
  }
  
  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    
    // Load from cache instantly
    final cached = await _cachedRepo.getAllCached(
      onDataUpdated: (freshCategories) {
        // Update UI when fresh data arrives
        if (mounted) {
          setState(() {
            _categories = freshCategories;
          });
        }
      },
    );
    
    // Render cached data immediately
    setState(() {
      _categories = cached;
      _isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return CircularProgressIndicator();
    }
    
    return ListView.builder(
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(_categories[index].name),
        );
      },
    );
  }
}
```

## Performance Metrics to Check

### Expected Performance:
- **First load**: 1-2 seconds (fetch from Supabase)
- **Cached load**: < 50ms (from Hive)
- **Background sync**: Non-blocking, updates UI silently
- **Offline load**: < 50ms (from cache)

### Monitor:
1. **Supabase Egress**: Should decrease significantly
2. **Page Load Time**: Should be instant for cached data
3. **Network Requests**: Should reduce by 80-90%
4. **User Experience**: No loading spinners for cached data

## Debugging

### Check Cache Status
```dart
final stats = await PersistentCacheService.getStats();
print('Cache Status: $stats');
```

### Clear All Cache
```dart
await PersistentCacheService.clearAll();
```

### Check Last Sync
```dart
final lastSync = await PersistentCacheService.getLastSync('categories');
print('Last sync: $lastSync');
```

### Enable Debug Logs
Check console for:
- `✅ Cache hit: categories` - Cache working
- `🔄 Cache miss: categories` - Fetching fresh
- `🔄 Delta fetch: categories` - Delta sync working
- `✅ Background sync completed` - Background sync working

## Common Issues

### Issue: Cache not working
**Solution**: Check if `PersistentCacheService.initialize()` is called in `main.dart`

### Issue: Data not updating
**Solution**: Use `forceRefresh: true` or invalidate cache

### Issue: Hive errors
**Solution**: Clear app data or reinstall app (Hive data stored locally)

### Issue: Delta fetch not working
**Solution**: Check if table has `updated_at` column

## Test Scenarios

### Scenario 1: First Time User
1. Fresh install
2. Load categories page
3. Should fetch from Supabase (1-2s)
4. Data cached automatically

### Scenario 2: Returning User
1. Open app
2. Load categories page
3. Should load from cache instantly (< 50ms)
4. Background sync updates silently

### Scenario 3: Offline User
1. Turn off internet
2. Load categories page
3. Should load from cache (< 50ms)
4. No errors, app still usable

### Scenario 4: Data Update
1. Update category in Supabase
2. Load categories page
3. Should show cached data first
4. Background sync updates UI when fresh data arrives

## Success Criteria

✅ All modules compile without errors
✅ Cache loads in < 50ms
✅ Offline mode works
✅ Background sync updates UI
✅ Supabase egress reduced by 60-80%
✅ No breaking changes to existing code
✅ User experience improved (instant loads)

