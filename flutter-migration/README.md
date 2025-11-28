# PocketBizz Flutter - Supabase Migration

## Quick Start

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Configure Supabase

1. Create Supabase project at https://supabase.com
2. Copy `.env.example` to `.env`
3. Fill in your Supabase credentials in `.env`
4. Update `lib/main.dart` with your Supabase URL and anon key

### 3. Run the App

```bash
flutter run
```

## Project Structure

```
lib/
├── core/
│   └── supabase_config.dart    # Supabase initialization
├── features/
│   ├── auth/
│   │   └── auth_service.dart   # Authentication service
│   ├── bookings/
│   │   └── bookings_service.dart
│   └── products/
│       └── products_service.dart
└── main.dart
```

## Key Features

- ✅ **Direct Supabase Integration** - No backend needed
- ✅ **Row Level Security** - Automatic data isolation
- ✅ **Type-safe** - Full Dart type safety
- ✅ **Real-time** - Optional WebSocket subscriptions
- ✅ **Offline-ready** - Can add offline support

## API Examples

### Authentication

```dart
final authService = AuthService();

// Sign up
await authService.signUp(
  email: 'user@example.com',
  password: 'password123',
);

// Sign in
await authService.signIn(
  email: 'user@example.com',
  password: 'password123',
);

// Sign out
await authService.signOut();
```

### Bookings

```dart
final bookingsService = BookingsService();

// Create booking
final booking = await bookingsService.createBooking(
  customerName: 'John Doe',
  customerPhone: '0123456789',
  eventType: 'Wedding',
  deliveryDate: '2025-12-01',
  items: [
    {
      'product_id': 'xxx',
      'product_name': 'Wedding Cake',
      'quantity': 1,
      'unit_price': 500.0,
    },
  ],
  totalAmount: 500.0,
);

// List bookings
final bookings = await bookingsService.listBookings();

// Update status
await bookingsService.updateBookingStatus(
  bookingId: 'xxx',
  status: 'confirmed',
);
```

### Products

```dart
final productsService = ProductsService();

// Create product
final product = await productsService.createProduct(
  name: 'Chocolate Cake',
  sku: 'CAKE-001',
  category: 'Cakes',
  price: 150.0,
);

// List products
final products = await productsService.listProducts();

// Search products
final results = await productsService.searchProducts('cake');
```

## Real-time Subscriptions

Listen to real-time changes:

```dart
// Listen to booking changes
supabase
  .from('bookings')
  .stream(primaryKey: ['id'])
  .listen((data) {
    print('Bookings updated: $data');
  });
```

## Error Handling

All services throw exceptions on error. Wrap calls in try-catch:

```dart
try {
  final booking = await bookingsService.createBooking(...);
} on PostgrestException catch (e) {
  print('Database error: ${e.message}');
} catch (e) {
  print('Error: $e');
}
```

## Performance Tips

1. **Use `.select()` wisely** - Only fetch columns you need
2. **Add indexes** - For frequently queried columns
3. **Batch operations** - Use transactions for multiple updates
4. **Cache data** - Store frequently accessed data locally
5. **Optimize RLS** - Keep policies simple for better performance

## Deployment

### Android

```bash
flutter build appbundle
# Upload to Play Console
```

### iOS

```bash
flutter build ipa
# Upload to App Store Connect
```

## Need Help?

- Supabase Docs: https://supabase.com/docs
- Flutter Supabase: https://supabase.com/docs/guides/getting-started/tutorials/with-flutter
- Discord: https://discord.supabase.com

## Migration from Encore

| Encore | Supabase |
|--------|----------|
| `POST /api/bookings` | `supabase.from('bookings').insert()` |
| `GET /api/bookings` | `supabase.from('bookings').select()` |
| `PUT /api/bookings/:id` | `supabase.from('bookings').update().eq('id', id)` |
| `DELETE /api/bookings/:id` | `supabase.from('bookings').delete().eq('id', id)` |

**Key differences:**
- ✅ No API endpoints - direct database access
- ✅ RLS handles authorization automatically
- ✅ Type-safe Dart code (no HTTP serialization)
- ✅ Real-time subscriptions included

