# Persistent Cache dengan Stale-While-Revalidate

## Overview

Sistem cache baru untuk PocketBizz yang menggunakan:
- **Hive** (persistent storage) - untuk data besar
- **SharedPreferences** - untuk metadata kecil (last_sync timestamps)
- **Stale-While-Revalidate pattern** - load cache instant, sync background

## Features

✅ **Instant Load** - Data dari cache render segera (10-20ms)
✅ **Background Sync** - Sync dengan Supabase tanpa block UI
✅ **Delta Fetch** - Hanya ambil data yang updated (jimat egress)
✅ **Offline-First** - App tetap usable walaupun offline
✅ **Auto-Invalidate** - Cache invalidate bila data berubah

## Architecture

```
┌─────────────────────────────────────┐
│   UI Layer (Flutter Widgets)       │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│   PersistentCacheService            │
│   - Stale-While-Revalidate          │
│   - Load from Hive (instant)        │
│   - Background sync                  │
└──────────────┬──────────────────────┘
       ┌───────┴───────┐
       │               │
┌──────▼──────┐ ┌─────▼──────────┐
│   Hive      │ │ SharedPrefs    │
│ (Large data)│ │ (Metadata)     │
└─────────────┘ └────────────────┘
       │               │
       └───────┬───────┘
               │
┌──────────────▼──────────────────────┐
│   Supabase (Background Sync)       │
│   - Delta fetch (updated_at)        │
└─────────────────────────────────────┘
```

## Usage

### 1. Basic Usage (Products Example)

```dart
import 'package:pocketbizz/core/services/persistent_cache_service.dart';
import 'package:pocketbizz/data/models/product.dart';

// Get products dengan cache
final products = await PersistentCacheService.getOrSync<List<Product>>(
  'products',
  fetcher: () async {
    // Fetch dari Supabase
    final data = await supabase
        .from('products')
        .select()
        .eq('business_owner_id', userId)
        .eq('is_active', true);
    return List<Map<String, dynamic>>.from(data);
  },
  fromJson: (json) => Product.fromJson(json),
  toJson: (product) => (product as Product).toJson(),
);

// Data akan:
// 1. Load dari cache instantly (jika ada)
// 2. Sync dengan Supabase di background
// 3. Update UI jika ada perubahan
```

### 2. Dengan Callback untuk UI Update

```dart
final products = await PersistentCacheService.getOrSync<List<Product>>(
  'products',
  fetcher: () async {
    // ... fetch logic
  },
  fromJson: (json) => Product.fromJson(json),
  toJson: (product) => (product as Product).toJson(),
  onDataUpdated: (freshProducts) {
    // Callback bila fresh data arrive
    setState(() {
      _products = freshProducts;
    });
  },
);
```

### 3. Force Refresh

```dart
// Skip cache dan fetch fresh data
final products = await PersistentCacheService.getOrSync<List<Product>>(
  'products',
  fetcher: () async { /* ... */ },
  fromJson: (json) => Product.fromJson(json),
  toJson: (product) => (product as Product).toJson(),
  forceRefresh: true, // Skip cache
);
```

### 4. Delta Fetch (Jimat Egress)

```dart
// Hanya ambil data yang updated selepas last sync
final lastSync = await PersistentCacheService.getLastSync('products');

var query = supabase.from('products').select();
if (lastSync != null) {
  // Delta fetch - hanya updated records
  query = query.gt('updated_at', lastSync.toIso8601String());
}

final data = await query;
```

### 5. Invalidate Cache

```dart
// Invalidate specific cache
await PersistentCacheService.invalidate('products');

// Invalidate multiple
await PersistentCacheService.invalidateMultiple([
  'products',
  'sales',
  'inventory',
]);

// Clear all cache
await PersistentCacheService.clearAll();
```

## Integration dengan Repository

### Example: ProductsRepositoryCached

Lihat `lib/data/repositories/products_repository_supabase_cached.dart` untuk contoh lengkap.

```dart
class ProductsRepositorySupabaseCached {
  Future<List<Product>> getAllCached({
    bool forceRefresh = false,
    void Function(List<Product>)? onDataUpdated,
  }) async {
    return await PersistentCacheService.getOrSync<List<Product>>(
      'products',
      fetcher: () async {
        // Delta fetch logic
        final lastSync = await PersistentCacheService.getLastSync('products');
        // ... build query with delta fetch
      },
      fromJson: (json) => Product.fromJson(json),
      toJson: (product) => (product as Product).toJson(),
      onDataUpdated: onDataUpdated,
      forceRefresh: forceRefresh,
    );
  }
}
```

## Page Lifecycle Pattern

### Recommended Pattern untuk Pages

```dart
class ProductsPage extends StatefulWidget {
  @override
  _ProductsPageState createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<Product> _products = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadProducts();
  }
  
  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    
    // Load dari cache instantly
    final cached = await PersistentCacheService.getOrSync<List<Product>>(
      'products',
      fetcher: () async {
        // Fetch logic
      },
      fromJson: (json) => Product.fromJson(json),
      toJson: (product) => (product as Product).toJson(),
      onDataUpdated: (freshProducts) {
        // Update UI bila fresh data arrive
        if (mounted) {
          setState(() {
            _products = freshProducts;
          });
        }
      },
    );
    
    // Render cached data immediately
    setState(() {
      _products = cached;
      _isLoading = false;
    });
    
    // Background sync akan trigger onDataUpdated jika ada perubahan
  }
}
```

## Cache Statistics

```dart
// Get cache stats untuk debugging
final stats = await PersistentCacheService.getStats();
print(stats);
// {
//   'products': {'count': 50, 'last_sync': '2024-01-15T10:30:00Z'},
//   'sales': {'count': 200, 'last_sync': '2024-01-15T10:25:00Z'},
//   ...
// }
```

## Best Practices

### 1. Choose Appropriate Cache Keys
- Use table names: `'products'`, `'sales'`, `'expenses'`
- Consistent naming across app

### 2. Delta Fetch Strategy
- First load: Full fetch
- Subsequent: Delta fetch (updated_at > last_sync)
- Fallback: Full fetch if delta empty

### 3. Invalidation
- Invalidate on create/update/delete
- Use real-time subscriptions untuk auto-invalidate
- Clear cache on logout

### 4. Error Handling
- Cache errors should not block UI
- Fallback to direct Supabase fetch if cache fails
- Log errors for debugging

### 5. Performance
- Use cache untuk frequently accessed data
- Don't cache large binary data (use separate storage)
- Monitor cache size

## Migration dari CacheService

### Before (In-Memory Only)
```dart
final products = await CacheService.getOrFetch(
  'products',
  () => _repo.getAllProducts(),
  ttl: Duration(minutes: 5),
);
```

### After (Persistent + SWR)
```dart
final products = await PersistentCacheService.getOrSync<List<Product>>(
  'products',
  fetcher: () async {
    final data = await supabase.from('products').select();
    return List<Map<String, dynamic>>.from(data);
  },
  fromJson: (json) => Product.fromJson(json),
  toJson: (product) => (product as Product).toJson(),
);
```

## Troubleshooting

### Cache tidak update?
- Check `last_sync` timestamp
- Verify `updated_at` field exists in table
- Check network connectivity

### Cache terlalu besar?
- Use `clearAll()` untuk reset
- Consider pagination untuk large datasets
- Monitor dengan `getStats()`

### Performance issues?
- Check Hive box size
- Consider splitting large tables
- Use delta fetch untuk reduce data transfer

## Available Cached Repositories

1. ✅ **Products** - `ProductsRepositorySupabaseCached`
   - `getAllCached()` - Get all products with cache
   - `refreshAll()` - Force refresh
   - `syncInBackground()` - Background sync

2. ✅ **Sales** - `SalesRepositorySupabaseCached`
   - `listSalesCached()` - List sales with filters (channel, date range)
   - `refreshAll()` - Force refresh
   - `syncInBackground()` - Background sync

3. ✅ **Expenses** - `ExpensesRepositorySupabaseCached`
   - `getExpensesCached()` - Get expenses with pagination
   - `refreshAll()` - Force refresh
   - `syncInBackground()` - Background sync

4. ✅ **Vendors** - `VendorsRepositorySupabaseCached`
   - `getAllVendorsCached()` - Get all vendors (active/all)
   - `refreshAll()` - Force refresh
   - `syncInBackground()` - Background sync

5. ✅ **Stock Items** - `StockRepositorySupabaseCached`
   - `getAllStockItemsCached()` - Get all stock items
   - `getLowStockItemsCached()` - Get low stock items
   - `refreshAll()` - Force refresh
   - `syncInBackground()` - Background sync

## Next Steps

1. ⏳ Integrate cached repositories in UI pages
2. ⏳ Add real-time cache invalidation
3. ⏳ Monitor egress reduction
4. ⏳ Add more modules (Inventory, Deliveries, etc.)

## Notes

- Cache stored in device storage (persistent across app restarts)
- Cache cleared on logout (security)
- Delta fetch reduces Supabase egress significantly
- Stale-While-Revalidate provides instant UI rendering

