import 'package:intl/intl.dart';

import '../../core/supabase/supabase_client.dart';
import '../../core/utils/rate_limit_mixin.dart';
import '../../core/utils/rate_limiter.dart';
import '../models/expense.dart';

/// Expenses repository using Supabase `expenses` table with rate limiting.
class ExpensesRepositorySupabase with RateLimitMixin {
  /// Fetch all expenses for current business owner, newest first with rate limiting.
  Future<List<Expense>> getExpenses() async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        final userId = supabase.auth.currentUser!.id;

        final response = await supabase
            .from('expenses')
            .select()
            .eq('business_owner_id', userId)
            .order('expense_date', ascending: false)
            .order('created_at', ascending: false);

        final data = (response as List).cast<Map<String, dynamic>>();
        return data.map(Expense.fromJson).toList();
      },
    );
  }

  /// Create a new expense with rate limiting.
  Future<Expense> createExpense({
    required String category,
    required double amount,
    required DateTime expenseDate,
    String? description,
    String? receiptImageUrl,
    ReceiptData? receiptData,
  }) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
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
      },
    );
  }

  /// Get a single expense by ID with rate limiting
  Future<Expense?> getExpenseById(String id) async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        final response = await supabase
            .from('expenses')
            .select()
            .eq('id', id)
            .maybeSingle();
        
        if (response == null) return null;
        return Expense.fromJson(response as Map<String, dynamic>);
      },
    );
  }
}



