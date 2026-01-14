/**
 * 🔒 STABLE CORE MODULE – DO NOT MODIFY
 * This file is production-tested.
 * Any changes must be isolated via extension or wrapper.
 */
// ❌ AI WARNING:
// DO NOT refactor, rename, optimize or restructure this logic.
// Only READ-ONLY reference allowed.

import 'package:intl/intl.dart';

import '../../core/supabase/supabase_client.dart';
import '../models/expense.dart';

/// Expenses repository using Supabase `expenses` table.
class ExpensesRepositorySupabase {
  /// Fetch all expenses for current business owner, newest first.
  Future<List<Expense>> getExpenses() async {
    final userId = supabase.auth.currentUser!.id;

    final response = await supabase
        .from('expenses')
        .select()
        .eq('business_owner_id', userId)
        .order('expense_date', ascending: false)
        .order('created_at', ascending: false);

    final data = (response as List).cast<Map<String, dynamic>>();
    return data.map(Expense.fromJson).toList();
  }

  /// Create a new expense.
  Future<Expense> createExpense({
    required String category,
    required double amount,
    required DateTime expenseDate,
    String? description,
    String? receiptImageUrl,
    String? documentImageUrl,
    String? documentPdfUrl,
    ReceiptData? receiptData,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    final payload = {
      'business_owner_id': userId,
      'category': category,
      'amount': amount,
      'currency': 'MYR',
      'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
      'notes': description,
      if (receiptImageUrl != null) 'receipt_image_url': receiptImageUrl,
      if (documentImageUrl != null) 'document_image_url': documentImageUrl,
      if (documentPdfUrl != null) 'document_pdf_url': documentPdfUrl,
      if (receiptData != null) 'receipt_data': receiptData.toJson(),
    };

    // Debug: Log payload before insert
    print('📝 Creating expense with payload:');
    print('   - receiptImageUrl: $receiptImageUrl');
    print('   - receiptData: ${receiptData?.toJson()}');

    try {
      final response =
          await supabase.from('expenses').insert(payload).select().single();

      final savedExpense = Expense.fromJson(response as Map<String, dynamic>);
      
      // Debug: Verify receipt URL was saved
      print('✅ Expense created successfully:');
      print('   - ID: ${savedExpense.id}');
      print('   - Receipt URL in response: ${savedExpense.receiptImageUrl}');
      
      // Check if receipt URL was actually saved
      if (receiptImageUrl != null && savedExpense.receiptImageUrl == null) {
        print('⚠️ WARNING: receiptImageUrl was provided but not saved to database!');
        print('   This might indicate the column does not exist in the database.');
        print('   Please run migration: add_receipt_image_url_to_expenses.sql');
      }

      return savedExpense;
    } catch (e) {
      print('❌ Error creating expense: $e');
      print('   Payload was: $payload');
      rethrow;
    }
  }

  /// Get a single expense by ID
  Future<Expense?> getExpenseById(String id) async {
    final response = await supabase
        .from('expenses')
        .select()
        .eq('id', id)
        .maybeSingle();
    
    if (response == null) return null;
    return Expense.fromJson(response as Map<String, dynamic>);
  }

  /// Update an existing expense
  Future<Expense> updateExpense({
    required String id,
    required String category,
    required double amount,
    required DateTime expenseDate,
    String? description,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    final payload = {
      'category': category,
      'amount': amount,
      'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
      'notes': description,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final response = await supabase
          .from('expenses')
          .update(payload)
          .eq('id', id)
          .eq('business_owner_id', userId)
          .select()
          .single();

      return Expense.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error updating expense: $e');
      rethrow;
    }
  }

  /// Delete an expense
  Future<void> deleteExpense(String id) async {
    final userId = supabase.auth.currentUser!.id;

    try {
      await supabase
          .from('expenses')
          .delete()
          .eq('id', id)
          .eq('business_owner_id', userId);
    } catch (e) {
      print('❌ Error deleting expense: $e');
      rethrow;
    }
  }
}



