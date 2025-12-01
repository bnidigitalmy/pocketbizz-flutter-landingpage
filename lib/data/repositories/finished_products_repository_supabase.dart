import '../../core/supabase/supabase_client.dart';
import '../models/finished_product.dart';

/// Finished Products Repository
/// Handles fetching finished product summaries and batch details
class FinishedProductsRepository {
  /// Get all finished products summary (aggregated by product)
  /// Returns products with total remaining quantity and nearest expiry date
  Future<List<FinishedProductSummary>> getFinishedProductsSummary() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Query to get aggregated finished products
      // Group by product_id and calculate totals
      final response = await supabase
          .from('production_batches')
          .select('''
            product_id,
            product_name,
            remaining_qty,
            expiry_date,
            batch_date
          ''')
          .eq('business_owner_id', userId)
          .gt('remaining_qty', 0)
          .order('product_name');

      final batches = (response as List)
          .map((json) => json as Map<String, dynamic>)
          .toList();

      // Group by product_id and aggregate
      final Map<String, Map<String, dynamic>> productMap = {};

      for (var batch in batches) {
        final productId = batch['product_id'] as String;
        final productName = batch['product_name'] as String;
        final remainingQty = (batch['remaining_qty'] as num).toDouble();
        final expiryDate = batch['expiry_date'] as String?;

        if (!productMap.containsKey(productId)) {
          productMap[productId] = {
            'product_id': productId,
            'product_name': productName,
            'total_remaining': 0.0,
            'nearest_expiry': null,
            'batch_count': 0,
          };
        }

        final product = productMap[productId]!;
        product['total_remaining'] = (product['total_remaining'] as num) + remainingQty;
        product['batch_count'] = (product['batch_count'] as num) + 1;

        // Track nearest expiry date
        if (expiryDate != null) {
          final expiry = DateTime.parse(expiryDate);
          if (product['nearest_expiry'] == null ||
              expiry.isBefore(DateTime.parse(product['nearest_expiry'] as String))) {
            product['nearest_expiry'] = expiryDate;
          }
        }
      }

      return productMap.values
          .map((json) => FinishedProductSummary.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch finished products: $e');
    }
  }

  /// Get all batches for a specific product
  /// Ordered by batch_date (FIFO - oldest first)
  Future<List<ProductionBatch>> getProductBatches(String productId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('production_batches')
          .select('''
            *,
            products:product_id (
              name
            )
          ''')
          .eq('business_owner_id', userId)
          .eq('product_id', productId)
          .gt('remaining_qty', 0)
          .order('batch_date', ascending: true); // FIFO - oldest first

      return (response as List)
          .map((json) => ProductionBatch.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch product batches: $e');
    }
  }
}

