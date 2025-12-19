# 🛡️ Rate Limiting Implementation Guide

## Overview

Rate limiting has been implemented to prevent API abuse and DDoS attacks. The system uses a **Token Bucket Algorithm** to limit the number of requests per time window.

---

## 📊 Rate Limits Configuration

| Operation Type | Max Requests | Time Window | Use Case |
|----------------|--------------|-------------|----------|
| **Read** | 100 | 60 seconds | GET requests, fetching data |
| **Write** | 30 | 60 seconds | POST, PUT, PATCH, DELETE |
| **Expensive** | 10 | 60 seconds | Reports, exports, complex queries |
| **Auth** | 5 | 60 seconds | Login, signup, password reset |
| **Upload** | 20 | 60 seconds | File uploads, images |

---

## 🚀 Usage

### **Method 1: Using RateLimitMixin (Recommended)**

Add the mixin to your repository class:

```dart
import '../../core/utils/rate_limit_mixin.dart';
import '../../core/utils/rate_limiter.dart';

class CategoriesRepositorySupabase with RateLimitMixin {
  /// Get all categories with rate limiting
  Future<List<Category>> getAll() async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        final response = await supabase
            .from('categories')
            .select()
            .eq('is_active', true)
            .order('name', ascending: true);
        
        return (response as List)
            .map((json) => Category.fromJson(json))
            .toList();
      },
    );
  }
  
  /// Create category with rate limiting
  Future<Category> create(String name) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        final userId = supabase.auth.currentUser!.id;
        final data = await supabase
            .from('categories')
            .insert({
              'business_owner_id': userId,
              'name': name,
            })
            .select()
            .single();
        
        return Category.fromJson(data);
      },
    );
  }
}
```

---

### **Method 2: Using RateLimitedSupabaseClient Directly**

```dart
import '../../core/supabase/rate_limited_client.dart';
import '../../core/utils/rate_limiter.dart';

class MyRepository {
  /// Get data with rate limiting
  Future<List<Item>> getAll() async {
    return await rateLimitedSupabase.executeRead(
      operation: () async {
        return await supabase.from('items').select();
      },
    );
  }
  
  /// Create with rate limiting
  Future<Item> create(Map<String, dynamic> data) async {
    return await rateLimitedSupabase.executeWrite(
      operation: () async {
        return await supabase
            .from('items')
            .insert(data)
            .select()
            .single();
      },
    );
  }
}
```

---

## 🔧 Operation Types

### **RateLimitType.read**
Use for:
- Fetching lists (products, sales, expenses)
- Getting single items by ID
- Search operations
- Filtering and sorting

```dart
await executeWithRateLimit(
  type: RateLimitType.read,
  operation: () => supabase.from('products').select(),
);
```

---

### **RateLimitType.write**
Use for:
- Creating new records
- Updating existing records
- Deleting records
- Batch operations

```dart
await executeWithRateLimit(
  type: RateLimitType.write,
  operation: () => supabase
      .from('products')
      .insert({'name': 'Product'})
      .select()
      .single(),
);
```

---

### **RateLimitType.expensive**
Use for:
- Generating reports
- Exporting data
- Complex aggregations
- Analytics queries

```dart
await executeWithRateLimit(
  type: RateLimitType.expensive,
  operation: () => supabase.rpc('generate_sales_report', params: {...}),
);
```

---

### **RateLimitType.auth**
Use for:
- Login attempts
- Signup
- Password reset
- Email verification

```dart
await executeWithRateLimit(
  type: RateLimitType.auth,
  operation: () => supabase.auth.signInWithPassword(
    email: email,
    password: password,
  ),
);
```

---

### **RateLimitType.upload**
Use for:
- File uploads
- Image uploads
- Document uploads

```dart
await executeWithRateLimit(
  type: RateLimitType.upload,
  operation: () => supabase.storage
      .from('images')
      .upload('path/file.jpg', fileBytes),
);
```

---

## ⚠️ Error Handling (PocketBizz UX Style)

When rate limit is exceeded, a `RateLimitExceededException` is thrown with **user-friendly messages**:

### **✅ Recommended: Use SnackBar (Non-Panic UX)**

```dart
import 'package:flutter/material.dart';
import '../../core/utils/rate_limiter.dart';

try {
  await executeWithRateLimit(
    type: RateLimitType.write,
    operation: () => createSale(),
  );
} on RateLimitExceededException catch (e) {
  // Show friendly SnackBar (NOT popup/dialog - too panic!)
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.message), // Already user-friendly!
        duration: Duration(seconds: 3),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
```

### **Message Examples (Automatic):**

- **Write/Sales:** "Terlalu pantas 😅 Sila tunggu sekejap."
- **Login:** "Terlalu banyak cubaan. Sila cuba semula selepas beberapa minit."
- **Reports:** "Laporan sedang diproses. Sila tunggu sebentar."
- **Read:** "Terlalu pantas 😅 Sila tunggu sekejap."

### **❌ DON'T Use AlertDialog (Too Panic!)**

```dart
// ❌ BAD - Don't do this!
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Error'), // Too scary!
    content: Text(e.message),
  ),
);
```

---

## 💡 Practical Example (Complete)

Here's a complete example showing how to handle rate limiting in a real page:

```dart
import 'package:flutter/material.dart';
import '../../core/utils/rate_limit_mixin.dart';
import '../../core/utils/rate_limiter.dart';

class CreateSalePage extends StatefulWidget {
  @override
  _CreateSalePageState createState() => _CreateSalePageState();
}

class _CreateSalePageState extends State<CreateSalePage> 
    with RateLimitMixin {
  
  Future<void> _createSale() async {
    try {
      // Show loading
      setState(() => _isLoading = true);
      
      // Create sale with rate limiting
      await executeWithRateLimit(
        type: RateLimitType.write,
        operation: () async {
          return await _salesRepo.createSale(
            items: _items,
            customerName: _customerName,
          );
        },
      );
      
      // Success - navigate back
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Jualan berjaya direkod!')),
        );
      }
    } on RateLimitExceededException catch (e) {
      // Friendly error message (already in Bahasa Malaysia!)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message), // "Terlalu pantas 😅 Sila tunggu sekejap."
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      // Other errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
```

**Key Points:**
- ✅ Use `SnackBar` (not AlertDialog)
- ✅ Error message is **already user-friendly** (no need to customize)
- ✅ Simple try-catch pattern
- ✅ Handle `RateLimitExceededException` separately from other errors

---

## 📈 Checking Rate Limit Status

### **Get Remaining Requests**

```dart
final remaining = getRemainingRequests(RateLimitType.read);
print('Remaining read requests: $remaining');
```

### **Get Time Until Reset**

```dart
final timeUntilReset = getTimeUntilReset(RateLimitType.write);
print('Rate limit resets in: ${timeUntilReset.inSeconds} seconds');
```

---

## 🎯 Best Practices

### ✅ **DO:**
- ✅ Use appropriate rate limit type for each operation
- ✅ Handle `RateLimitExceededException` gracefully with **SnackBar** (not popup!)
- ✅ Error messages are **automatically user-friendly** (Bahasa Malaysia, PocketBizz style)
- ✅ Use `RateLimitType.expensive` for heavy operations
- ✅ Use `RateLimitType.auth` for authentication
- ✅ Keep it simple - let the system handle messages

### ❌ **DON'T:**
- ❌ Use `RateLimitType.read` for write operations
- ❌ Ignore rate limit exceptions
- ❌ Bypass rate limiting (defeats the purpose)
- ❌ Use same rate limit type for all operations
- ❌ Show AlertDialog for rate limit errors (too panic for users!)
- ❌ Override error messages (system already provides friendly messages)

---

## 🔄 Migration Guide

### **Step 1: Add Import**

```dart
import '../../core/utils/rate_limit_mixin.dart';
import '../../core/utils/rate_limiter.dart';
```

### **Step 2: Add Mixin**

```dart
class MyRepository with RateLimitMixin {
  // ...
}
```

### **Step 3: Wrap Operations**

**Before:**
```dart
Future<List<Item>> getAll() async {
  final response = await supabase.from('items').select();
  return (response as List).map((json) => Item.fromJson(json)).toList();
}
```

**After:**
```dart
Future<List<Item>> getAll() async {
  return await executeWithRateLimit(
    type: RateLimitType.read,
    operation: () async {
      final response = await supabase.from('items').select();
      return (response as List).map((json) => Item.fromJson(json)).toList();
    },
  );
}
```

---

## 🧪 Testing

### **Test Rate Limiting**

```dart
void testRateLimit() async {
  final repo = MyRepository();
  
  // Make requests up to limit
  for (int i = 0; i < 100; i++) {
    await repo.getAll(); // Should succeed
  }
  
  // Next request should fail
  try {
    await repo.getAll(); // Should throw RateLimitExceededException
  } on RateLimitExceededException catch (e) {
    print('Rate limit exceeded: ${e.message}');
  }
}
```

---

## 📊 Monitoring

### **Check Rate Limit Status in UI**

```dart
class RateLimitIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final remaining = getRemainingRequests(RateLimitType.read);
    
    return Chip(
      label: Text('API Calls: $remaining/100 remaining'),
      backgroundColor: remaining > 20 
          ? Colors.green 
          : remaining > 10 
              ? Colors.orange 
              : Colors.red,
    );
  }
}
```

---

## 🔐 Security Benefits

1. **Prevents Abuse:** Limits malicious users from overwhelming the API
2. **DDoS Protection:** Reduces impact of distributed attacks
3. **Resource Protection:** Prevents excessive database load
4. **Cost Control:** Reduces Supabase API usage costs
5. **Fair Usage:** Ensures all users get fair access

---

## ⚙️ Configuration

Rate limits can be adjusted in `lib/core/utils/rate_limiter.dart`:

```dart
class RateLimiters {
  static final read = RateLimiter(
    maxRequests: 100,  // Adjust this
    window: Duration(seconds: 60),  // Adjust this
  );
  
  // ... other limiters
}
```

---

## 🚨 Important Notes

1. **Client-Side Only:** This is client-side rate limiting. Supabase also has server-side rate limiting.
2. **Per-User:** Rate limits are per-user (based on user ID)
3. **Automatic Reset:** Limits reset automatically after the time window
4. **No Persistence:** Rate limit state is in-memory (resets on app restart)

---

## 📚 Additional Resources

- [Token Bucket Algorithm](https://en.wikipedia.org/wiki/Token_bucket)
- [Supabase Rate Limiting](https://supabase.com/docs/guides/platform/rate-limits)
- [OWASP Rate Limiting](https://owasp.org/www-community/controls/Blocking_Brute_Force_Attacks)

---

**Last Updated:** December 2025  
**Status:** ✅ Implemented and Ready to Use

