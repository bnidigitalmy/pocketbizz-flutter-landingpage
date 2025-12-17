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
      if (receiptData != null) 'receipt_data': receiptData.toJson(),
    };

    final response =
        await supabase.from('expenses').insert(payload).select().single();

    return Expense.fromJson(response as Map<String, dynamic>);
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
}



