# 🔧 Enterprise Hardening Integration Examples

Practical examples showing how to integrate the 5 hardening measures into existing code.

---

## 1️⃣ Database Constraints

**Status:** ✅ Already applied via migration

**No code changes needed** - Constraints are enforced automatically at database level.

**Example:**
```dart
// This will fail if business_owner_id is NULL (even if UI has bug)
await supabase.from('products').insert({
  'name': 'Product',
  'business_owner_id': null, // ❌ Database constraint will reject this
  'sale_price': 10.00,
});
```

---

## 2️⃣ Soft Delete

### **Before (Hard Delete):**

```dart
// ❌ Old way - permanent delete
Future<void> deleteProduct(String id) async {
  await supabase.from('products').delete().eq('id', id);
}
```

### **After (Soft Delete):**

```dart
// ✅ New way - soft delete
Future<void> deleteProduct(String id) async {
  await executeWithRateLimit(
    type: RateLimitType.write,
    operation: () async {
      // Set deleted_at instead of deleting
      await supabase
          .from('products')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
      
      // Log audit event
      await auditRepo.logDelete(
        entityType: 'product',
        entityId: id,
      );
    },
  );
}
```

### **Update Queries (Exclude Deleted):**

```dart
// ✅ Always exclude deleted records
Future<List<Product>> getAllProducts() async {
  return await executeWithRateLimit(
    type: RateLimitType.read,
    operation: () async {
      final response = await supabase
          .from('products')
          .select()
          .eq('business_owner_id', userId)
          .is_('deleted_at', null) // ✅ Exclude deleted
          .order('name', ascending: true);
      
      return (response as List).map((json) => Product.fromJson(json)).toList();
    },
  );
}
```

---

## 3️⃣ Audit Logging

### **Example: Products Repository**

```dart
import '../../data/repositories/audit_log_repository_supabase.dart';

class ProductsRepositorySupabase with RateLimitMixin {
  final _auditRepo = AuditLogRepositorySupabase();
  
  Future<Product> createProduct(Product product) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        // ... create product logic ...
        final created = await supabase.from('products').insert(...);
        
        // ✅ Log audit event
        await _auditRepo.logCreate(
          entityType: 'product',
          entityId: created['id'],
          details: {'name': product.name},
        );
        
        return Product.fromJson(created);
      },
    );
  }
  
  Future<void> deleteProduct(String id) async {
    await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        // Get product details before deleting (for audit)
        final product = await getProduct(id);
        
        // Soft delete
        await supabase
            .from('products')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .eq('id', id);
        
        // ✅ Log audit event
        await _auditRepo.logDelete(
          entityType: 'product',
          entityId: id,
          details: {'name': product.name},
        );
      },
    );
  }
}
```

### **Example: Login (Auth)**

```dart
// In login_page.dart or auth service
Future<void> _handleLogin(String email, String password) async {
  try {
    await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    // ✅ Log successful login
    await AuditLogRepositorySupabase().logLogin(
      details: {'email': email},
    );
  } catch (e) {
    // Failed login - don't log (to avoid logging wrong passwords)
    rethrow;
  }
}
```

### **Example: Export Data**

```dart
Future<void> exportSalesReport() async {
  return await executeWithRateLimit(
    type: RateLimitType.expensive,
    operation: () async {
      // ... export logic ...
      final data = await generateReport();
      
      // ✅ Log export event
      await _auditRepo.logExport(
        entityType: 'sales_report',
        details: {
          'format': 'csv',
          'record_count': data.length,
          'date_range': '2024-01-01 to 2024-12-31',
        },
      );
      
      return data;
    },
  );
}
```

---

## 4️⃣ Ownership Validation

### **Example: Update Product**

```dart
import '../../core/utils/ownership_validator.dart';

Future<Product> updateProduct(String id, Map<String, dynamic> updates) async {
  return await executeWithRateLimit(
    type: RateLimitType.write,
    operation: () async {
      // ✅ 1. Get existing product
      final existing = await getProduct(id);
      
      // ✅ 2. Validate ownership (app-level check)
      OwnershipValidator.validateOwnership(
        existing.businessOwnerId,
        'product',
      );
      
      // ✅ 3. Now safe to update (RLS also protects at DB level)
      final updated = await supabase
          .from('products')
          .update(updates)
          .eq('id', id)
          .select()
          .single();
      
      // ✅ 4. Log audit event
      await _auditRepo.logUpdate(
        entityType: 'product',
        entityId: id,
        details: {'changes': updates},
      );
      
      return Product.fromJson(updated);
    },
  );
}
```

### **Example: Get Product with Validation**

```dart
Future<Product> getProduct(String id) async {
  return await executeWithRateLimit(
    type: RateLimitType.read,
    operation: () async {
      final data = await supabase
          .from('products')
          .select()
          .eq('id', id)
          .single();
      
      final product = Product.fromJson(data);
      
      // ✅ Validate ownership (for better UX)
      OwnershipValidator.validateOwnership(
        product.businessOwnerId,
        'product',
      );
      
      return product;
    },
  );
}
```

---

## 5️⃣ Complete Example: Sales Repository

```dart
import '../../core/utils/rate_limit_mixin.dart';
import '../../core/utils/rate_limiter.dart';
import '../../core/utils/ownership_validator.dart';
import '../../data/repositories/audit_log_repository_supabase.dart';

class SalesRepositorySupabase with RateLimitMixin {
  final _auditRepo = AuditLogRepositorySupabase();
  
  /// Create sale with full hardening
  Future<Sale> createSale({
    required List<Map<String, dynamic>> items,
    String? customerName,
  }) async {
    // ✅ 1. Ownership validation (ensure user is authenticated)
    OwnershipValidator.assertAuthenticated();
    
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        // ✅ 2. Create sale
        final saleData = await supabase
            .from('sales')
            .insert({
              'business_owner_id': OwnershipValidator.getCurrentBusinessOwnerId(),
              'customer_name': customerName,
              'items': items,
              // ... other fields
            })
            .select()
            .single();
        
        final sale = Sale.fromJson(saleData);
        
        // ✅ 3. Log audit event
        await _auditRepo.logCreate(
          entityType: 'sale',
          entityId: sale.id,
          details: {
            'customer_name': customerName,
            'item_count': items.length,
          },
        );
        
        return sale;
      },
    );
  }
  
  /// Delete sale with soft delete + audit
  Future<void> deleteSale(String saleId) async {
    await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        // ✅ 1. Get sale (validates ownership via RLS)
        final sale = await getSale(saleId);
        
        // ✅ 2. App-level ownership validation
        OwnershipValidator.validateOwnership(
          sale.businessOwnerId,
          'sale',
        );
        
        // ✅ 3. Soft delete (not hard delete)
        await supabase
            .from('sales')
            .update({
              'deleted_at': DateTime.now().toIso8601String(),
            })
            .eq('id', saleId);
        
        // ✅ 4. Log audit event
        await _auditRepo.logDelete(
          entityType: 'sale',
          entityId: saleId,
          details: {
            'customer_name': sale.customerName,
            'total_amount': sale.finalAmount,
          },
        );
      },
    );
  }
  
  /// List sales (exclude deleted)
  Future<List<Sale>> listSales() async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        // ✅ Exclude soft-deleted records
        final response = await supabase
            .from('sales')
            .select()
            .eq('business_owner_id', OwnershipValidator.getCurrentBusinessOwnerId())
            .is_('deleted_at', null) // ✅ Exclude deleted
            .order('created_at', ascending: false);
        
        return (response as List).map((json) => Sale.fromJson(json)).toList();
      },
    );
  }
}
```

---

## 📋 Integration Checklist

### **For Each Repository:**

- [ ] Add `with RateLimitMixin`
- [ ] Wrap operations with `executeWithRateLimit()`
- [ ] Add ownership validation for update/delete
- [ ] Add audit logging for create/update/delete
- [ ] Use soft delete instead of hard delete
- [ ] Update queries to exclude `deleted_at IS NOT NULL`

### **For Auth Operations:**

- [ ] Log successful logins
- [ ] Log logout events
- [ ] Log password resets (if applicable)

### **For Export Operations:**

- [ ] Log export events with details (format, record count, etc.)

### **For Payment Operations:**

- [ ] Log payment events with amount and method

---

**Last Updated:** December 2025  
**Status:** ✅ Integration Examples Ready

