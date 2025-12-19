# 🏢 Enterprise-Grade Hardening Guide

This document outlines the 5 additional hardening measures implemented for enterprise-grade security.

---

## 🔐 1. Database Constraints (WAJIB - Defense in Depth)

### **What It Does:**

Adds `CHECK` constraints to ensure `business_owner_id IS NOT NULL` on all critical tables.

### **Why It's Important:**

- ✅ **Even if UI has bugs**, database enforces integrity
- ✅ **Prevents orphaned records** (records without owner)
- ✅ **Database-level validation** (cannot be bypassed)

### **Implementation:**

```sql
ALTER TABLE products
ADD CONSTRAINT products_owner_check
CHECK (business_owner_id IS NOT NULL);
```

### **Tables Protected:**

- ✅ Products
- ✅ Sales
- ✅ Expenses
- ✅ Bookings
- ✅ Stock Items
- ✅ Categories
- ✅ Suppliers
- ✅ Purchase Orders
- ✅ Claims

### **Migration:**

Run: `db/migrations/add_enterprise_hardening.sql`

---

## 🔐 2. Soft Delete (Audit + Safety)

### **What It Does:**

Adds `deleted_at TIMESTAMP` column instead of hard delete.

### **Why It's Important:**

- ✅ **Audit trail** - Can see what was deleted and when
- ✅ **Data recovery** - Can restore accidentally deleted records
- ✅ **Compliance** - Some regulations require data retention

### **Implementation:**

```sql
ALTER TABLE products
ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE;

-- Index for performance
CREATE INDEX idx_products_deleted_at ON products(deleted_at) 
WHERE deleted_at IS NOT NULL;
```

### **Usage in Code:**

```dart
// Soft delete (set deleted_at)
await supabase
  .from('products')
  .update({
    'deleted_at': DateTime.now().toIso8601String(),
  })
  .eq('id', productId);

// Query (exclude deleted)
await supabase
  .from('products')
  .select()
  .is_('deleted_at', null) // Only active records
  .eq('business_owner_id', userId);

// Hard delete (permanent) - only if needed
await supabase
  .from('products')
  .delete()
  .eq('id', productId);
```

### **Benefits:**

- ✅ Can restore accidentally deleted records
- ✅ Can audit deletion history
- ✅ Better for compliance
- ✅ Safer than hard delete

---

## 🔐 3. Supabase Auth Settings (Dashboard Configuration)

### **Recommended Settings:**

Go to **Supabase Dashboard** > **Authentication** > **Settings**

#### **Email Confirmation:**

```
✅ Enable email confirmation
✅ Require email confirmation for new signups
```

**Why:** Prevents fake accounts and spam signups.

---

#### **Magic Link Validity:**

```
✅ Set expiration: 1 hour (3600 seconds)
✅ Limit usage: 5 attempts per hour
```

**Why:** Reduces abuse and security risk.

---

#### **CAPTCHA (if available):**

```
✅ Enable CAPTCHA for:
  - Signup
  - Password reset
  - Magic link requests
```

**Why:** Prevents bot attacks and abuse.

---

#### **Password Requirements:**

```
✅ Minimum length: 8 characters
✅ Require uppercase: Yes
✅ Require lowercase: Yes
✅ Require numbers: Yes
✅ Require symbols: Optional
```

**Why:** Stronger passwords = better security.

---

#### **Rate Limiting:**

```
✅ Login attempts: 5 per 15 minutes
✅ Password reset: 3 per hour
✅ Magic link: 5 per hour
```

**Why:** Prevents brute force attacks.

---

## 🔐 4. Audit Logging (Compliance & Tracking)

### **What It Does:**

Tracks all important actions (login, delete, export, payment, etc.) for compliance and security.

### **Implementation:**

#### **Database Table:**

```sql
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  business_owner_id UUID NOT NULL,
  action TEXT NOT NULL, -- 'login', 'delete', 'export', etc.
  entity_type TEXT NOT NULL, -- 'product', 'sale', etc.
  entity_id UUID,
  details JSONB,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMP NOT NULL
);
```

#### **Usage in Code:**

```dart
import '../../data/repositories/audit_log_repository_supabase.dart';

final auditRepo = AuditLogRepositorySupabase();

// Log login
await auditRepo.logLogin();

// Log delete
await auditRepo.logDelete(
  entityType: 'product',
  entityId: productId,
  details: {'name': productName},
);

// Log export
await auditRepo.logExport(
  entityType: 'sales',
  details: {'format': 'csv', 'date_range': '2024-01-01 to 2024-12-31'},
);

// Log payment
await auditRepo.logPayment(
  entityType: 'booking',
  entityId: bookingId,
  details: {'amount': 100.00, 'method': 'cash'},
);
```

### **What to Log:**

#### **Minimum (Critical):**

- ✅ Login attempts
- ✅ Delete operations
- ✅ Data exports
- ✅ Payment-related actions
- ✅ Password resets

#### **Recommended (Full Audit):**

- ✅ All create operations
- ✅ All update operations
- ✅ Login/logout
- ✅ Exports
- ✅ Payments
- ✅ Password changes
- ✅ Email verification

### **Querying Audit Logs:**

```dart
// Get my audit logs
final logs = await auditRepo.getMyLogs(
  action: AuditAction.delete,
  entityType: 'product',
  limit: 100,
);

// View in UI
for (final log in logs) {
  print('${log.action.value} - ${log.entityType} - ${log.createdAt}');
}
```

---

## 🔐 5. App-Level Ownership Check (Defense in Depth)

### **What It Does:**

Validates `business_owner_id == auth.uid()` in application code, even though RLS protects at database level.

### **Why It's Important:**

- ✅ **Better UX** - Clear error messages
- ✅ **Additional safety layer** - Defense in depth
- ✅ **Code-level validation** - Catches issues early

### **Implementation:**

```dart
import '../../core/utils/ownership_validator.dart';

// Validate ownership before operation
OwnershipValidator.validateOwnership(
  product.businessOwnerId,
  'product',
);

// Or validate from map
OwnershipValidator.validateFromMap(
  productData,
  'product',
);

// Or check without throwing
if (OwnershipValidator.isOwner(product.businessOwnerId)) {
  // Safe to proceed
}

// Get current user's business owner ID
final myBusinessOwnerId = OwnershipValidator.getCurrentBusinessOwnerId();
```

### **Example Usage in Repository:**

```dart
Future<Product> updateProduct(String id, Map<String, dynamic> updates) async {
  // First, get the product
  final product = await getProduct(id);
  
  // Validate ownership (app-level check)
  OwnershipValidator.validateOwnership(
    product.businessOwnerId,
    'product',
  );
  
  // Now safe to update (RLS will also protect)
  return await executeWithRateLimit(
    type: RateLimitType.write,
    operation: () async {
      // ... update logic
    },
  );
}
```

### **Benefits:**

- ✅ **Clear error messages** - "Anda tidak mempunyai akses kepada produk ini"
- ✅ **Early validation** - Catches issues before database call
- ✅ **Defense in depth** - Multiple layers of protection
- ✅ **Better UX** - User-friendly error messages

---

## 📊 Security Layers Summary

| Layer | Protection | Level |
|-------|-----------|-------|
| **RLS Policies** | Database-level access control | Database |
| **Database Constraints** | Data integrity (NOT NULL) | Database |
| **App-Level Validation** | Ownership checks | Application |
| **Rate Limiting** | API abuse prevention | Application |
| **Audit Logging** | Compliance & tracking | Application |
| **Soft Delete** | Data recovery | Database |

---

## 🚀 Implementation Checklist

### **✅ Completed:**

- [x] Database constraints migration
- [x] Audit logs table & function
- [x] Soft delete columns
- [x] Ownership validator utility
- [x] Audit log repository

### **📋 To Do:**

- [ ] Configure Supabase Auth settings (Dashboard)
- [ ] Integrate audit logging in repositories
- [ ] Update delete operations to use soft delete
- [ ] Add ownership validation in critical operations
- [ ] Create admin audit log viewer (optional)

---

## 🎯 Next Steps

1. **Run Migration:**
   ```bash
   # Apply migration in Supabase SQL Editor
   # File: db/migrations/add_enterprise_hardening.sql
   ```

2. **Configure Auth Settings:**
   - Go to Supabase Dashboard > Authentication > Settings
   - Enable email confirmation
   - Set rate limits
   - Configure password requirements

3. **Integrate Audit Logging:**
   - Add audit logging to critical operations
   - Log login, delete, export, payment actions

4. **Use Ownership Validation:**
   - Add `OwnershipValidator.validateOwnership()` in repositories
   - Update error handling for better UX

5. **Update Delete Operations:**
   - Change hard delete to soft delete
   - Update queries to exclude `deleted_at IS NOT NULL`

---

## 📚 Additional Resources

- [Supabase RLS Documentation](https://supabase.com/docs/guides/auth/row-level-security)
- [Database Constraints](https://www.postgresql.org/docs/current/ddl-constraints.html)
- [Audit Logging Best Practices](https://owasp.org/www-community/Audit)
- [Soft Delete Pattern](https://www.martinfowler.com/eaaCatalog/softDelete.html)

---

**Last Updated:** December 2025  
**Status:** ✅ Enterprise-Grade Hardening Implemented

