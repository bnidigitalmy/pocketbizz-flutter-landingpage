import 'package:flutter/foundation.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/supplier.dart';

/// Suppliers Repository
/// Manages suppliers (pembekal bahan/ingredients untuk production)
/// 
/// Note: Different from Vendors (consignee)
/// - Suppliers = Pembekal bahan untuk user beli dan buat produk
/// - Vendors = Consignee (kedai yang jual produk user dengan commission)
/// 
/// Uses suppliers table (separate from vendors table)
class SuppliersRepository {
  /// Get all suppliers
  Future<List<Supplier>> getAllSuppliers({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('suppliers')
          .select()
          .eq('business_owner_id', userId)
          .order('name')
          .range(offset, offset + limit - 1); // Add pagination

      return (response as List)
          .map((json) => Supplier.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch suppliers: $e');
    }
  }

  /// Get supplier by ID
  Future<Supplier?> getSupplierById(String supplierId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('suppliers')
          .select()
          .eq('id', supplierId)
          .eq('business_owner_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return Supplier.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch supplier: $e');
    }
  }

  /// Create new supplier
  Future<Supplier> createSupplier({
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final data = {
        'business_owner_id': userId,
        'name': name.trim(),
        'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
        'email': email?.trim().isEmpty == true ? null : email?.trim(),
        'address': address?.trim().isEmpty == true ? null : address?.trim(),
      };

      debugPrint('📝 Creating supplier with data: $data');

      final response = await supabase
          .from('suppliers')
          .insert(data)
          .select()
          .single();

      debugPrint('✅ Supplier created successfully: $response');

      return Supplier.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('❌ Error creating supplier: $e');
      debugPrint('   Error type: ${e.runtimeType}');
      
      // Check for common database errors
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('column') && errorStr.contains('email')) {
        throw Exception(
          'Kolumn email tidak wujud dalam database. '
          'Sila jalankan migration: db/migrations/2025-01-16_add_email_to_suppliers.sql'
        );
      }
      
      if (errorStr.contains('permission denied') || errorStr.contains('rls')) {
        throw Exception(
          'Tiada kebenaran untuk mencipta supplier. '
          'Sila pastikan Row Level Security (RLS) policies sudah disetup dengan betul.'
        );
      }
      
      throw Exception('Gagal mencipta supplier: ${e.toString()}');
    }
  }

  /// Update supplier
  Future<Supplier> updateSupplier({
    required String id,
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final data = {
        'name': name.trim(),
        'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
        'email': email?.trim().isEmpty == true ? null : email?.trim(),
        'address': address?.trim().isEmpty == true ? null : address?.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await supabase
          .from('suppliers')
          .update(data)
          .eq('id', id)
          .eq('business_owner_id', userId)
          .select()
          .single();

      return Supplier.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to update supplier: $e');
    }
  }

  /// Delete supplier
  Future<void> deleteSupplier(String id) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase
          .from('suppliers')
          .delete()
          .eq('id', id)
          .eq('business_owner_id', userId);
    } catch (e) {
      throw Exception('Failed to delete supplier: $e');
    }
  }
}

