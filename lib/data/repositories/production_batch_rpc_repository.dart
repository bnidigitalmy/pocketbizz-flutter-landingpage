import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client.dart' show supabase;
import '../models/production_batch.dart';

/// Lightweight RPC wrapper for recording production batches.
///
/// Purpose:
/// - Avoid noisy debug prints from the legacy ProductionRepository implementation.
/// - Preserve PostgrestException (eg code=P0001) so UI can detect subscription enforcement reliably.
class ProductionBatchRpcRepository {
  final SupabaseClient _client;

  ProductionBatchRpcRepository({SupabaseClient? client}) : _client = client ?? supabase;

  Future<String> recordProductionBatch(ProductionBatchInput input) async {
    final params = <String, dynamic>{
      'p_product_id': input.productId,
      'p_quantity': input.quantity,
      'p_batch_date': input.batchDate.toIso8601String().split('T')[0],
    };

    if (input.expiryDate != null) {
      params['p_expiry_date'] = input.expiryDate!.toIso8601String().split('T')[0];
    }
    if (input.notes != null && input.notes!.isNotEmpty) {
      params['p_notes'] = input.notes;
    }
    if (input.batchNumber != null && input.batchNumber!.isNotEmpty) {
      params['p_batch_number'] = input.batchNumber;
    }

    try {
      final response = await _client.rpc('record_production_batch', params: params);
      return response as String;
    } on PostgrestException catch (e) {
      // Keep original error for upstream handlers (SubscriptionEnforcement checks code=P0001).
      rethrow;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('does not exist') || msg.contains('404')) {
        throw Exception(
          'Function record_production_batch not found. Please apply migration: db/migrations/create_record_production_batch_function.sql',
        );
      }
      if (msg.contains('400') || msg.contains('Bad Request')) {
        throw Exception(
          'Bad Request (400): Function exists but parameters may be incorrect. '
          'Please check: 1) Function is applied correctly, 2) Product ID is valid UUID, '
          '3) Quantity is integer, 4) Dates are in YYYY-MM-DD format. '
          'Error: $msg',
        );
      }
      throw Exception('Failed to record production batch: $e');
    }
  }
}


