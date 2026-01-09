import '../../core/supabase/supabase_client.dart';
import '../../core/utils/rate_limit_mixin.dart';
import '../../core/utils/rate_limiter.dart';
import 'production_repository_supabase.dart';
import '../../features/subscription/data/repositories/subscription_repository_supabase.dart';
import '../../features/subscription/exceptions/subscription_limit_exception.dart';

/**
 * 🔒 STABLE CORE MODULE – DO NOT MODIFY
 * This file is production-tested.
 * Any changes must be isolated via extension or wrapper.
 */
// ❌ AI WARNING:
// DO NOT refactor, rename, optimize or restructure this logic.
// Only READ-ONLY reference allowed.
/// Sale model
class Sale {
  final String id;
  final String? customerName;
  final String channel;
  final double totalAmount;
  final double? discountAmount;
  final double finalAmount;
  final double? cogs; // Cost of Goods Sold
  final double? profit; // Profit amount
  final String? notes;
  final String? deliveryAddress; // For online and delivery channels
  final DateTime createdAt;
  final List<SaleItem>? items;

  Sale({
    required this.id,
    this.customerName,
    required this.channel,
    required this.totalAmount,
    this.discountAmount,
    required this.finalAmount,
    this.cogs,
    this.profit,
    this.notes,
    this.deliveryAddress,
    required this.createdAt,
    this.items,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'],
      customerName: json['customer_name'],
      channel: json['channel'] ?? 'walk-in',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble(),
      finalAmount: (json['final_amount'] as num?)?.toDouble() ?? 0.0,
      cogs: (json['cogs'] as num?)?.toDouble(),
      profit: (json['profit'] as num?)?.toDouble(),
      notes: json['notes'],
      deliveryAddress: json['delivery_address'],
      createdAt: DateTime.parse(json['created_at']).toLocal(), // Convert UTC to local timezone
      items: json['sale_items'] != null
          ? (json['sale_items'] as List)
              .map((item) => SaleItem.fromJson(item))
              .toList()
          : null,
    );
  }
}

/// Sale item model
class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final double? costOfGoods; // Cost of goods for this item

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.costOfGoods,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id'],
      saleId: json['sale_id'],
      productId: json['product_id'],
      productName: json['product_name'],
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      costOfGoods: (json['cost_of_goods'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
    };
  }
}

/**
 * 🔒 STABLE CORE MODULE – DO NOT MODIFY
 * This file is production-tested.
 * Any changes must be isolated via extension or wrapper.
 */
// ❌ AI WARNING:
// DO NOT refactor, rename, optimize or restructure this logic.
// Only READ-ONLY reference allowed.
/// Sales repository using Supabase with rate limiting
class SalesRepositorySupabase with RateLimitMixin {
  /// Create a new sale with rate limiting
  Future<Sale> createSale({
    String? customerName,
    String channel = 'walk-in',
    required List<Map<String, dynamic>> items,
    double? discountAmount,
    String? notes,
    String? deliveryAddress,
  }) async {
    return await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        // PHASE 3: Enforce usage limits before DB insert (Revenue leak stopper)
        final subscriptionRepo = SubscriptionRepositorySupabase();
        final limits = await subscriptionRepo.getPlanLimits();
        if (!limits.transactions.isUnlimited && limits.transactions.current >= limits.transactions.max) {
          throw SubscriptionLimitException(
            'Had transaksi telah dicapai (${limits.transactions.current}/${limits.transactions.max}). Sila naik taraf langganan anda untuk menambah lebih banyak transaksi.',
            limitType: 'transaksi',
            current: limits.transactions.current,
            max: limits.transactions.max,
          );
        }

        // Atomic DB transaction: create sale + deduct FIFO in one RPC
        final saleId = await supabase.rpc(
          'create_sale_and_deduct_fifo',
          params: {
            'p_customer_name': customerName,
            'p_channel': channel,
            'p_items': items,
            'p_discount_amount': discountAmount ?? 0,
            'p_notes': notes,
            'p_delivery_address': deliveryAddress,
          },
        ) as String;

        return getSale(saleId);
      },
    );
  }

  /// Get sale by ID with items and rate limiting
  Future<Sale> getSale(String saleId) async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        final data = await supabase
            .from('sales')
            .select('*, sale_items(*)')
            .eq('id', saleId)
            .single();

        return Sale.fromJson(data);
      },
    );
  }

  /// List all sales with rate limiting
  Future<List<Sale>> listSales({
    String? channel,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        var query = supabase
            .from('sales')
            .select('*, sale_items(*)');

        // Apply filters
        if (channel != null && channel.isNotEmpty) {
          query = query.eq('channel', channel);
        }

        if (startDate != null) {
          // Convert to UTC for database comparison (created_at is stored in UTC)
          final startDateUtc = startDate.toUtc();
          query = query.gte('created_at', startDateUtc.toIso8601String());
        }

        if (endDate != null) {
          // Convert to UTC for database comparison (created_at is stored in UTC)
          // Add 1 second to include the entire end day (23:59:59)
          final endDateUtc = endDate.toUtc();
          query = query.lte('created_at', endDateUtc.toIso8601String());
        }

        // Execute query with order and limit
        final data = await query
            .order('created_at', ascending: false)
            .limit(limit);

        return (data as List).map((json) => Sale.fromJson(json)).toList();
      },
    );
  }

  /// Get today's sales summary with rate limiting
  Future<Map<String, dynamic>> getTodaySummary() async {
    return await executeWithRateLimit(
      type: RateLimitType.read,
      operation: () async {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final sales = await supabase
            .from('sales')
            .select('final_amount')
            .gte('created_at', startOfDay.toIso8601String())
            .lt('created_at', endOfDay.toIso8601String());

        final totalSales = sales.fold<double>(
          0,
          (sum, sale) => sum + (sale['final_amount'] as num).toDouble(),
        );

        return {
          'total_sales': totalSales,
          'transaction_count': sales.length,
          'date': today,
        };
      },
    );
  }

  /// Delete sale with rate limiting
  Future<void> deleteSale(String saleId) async {
    await executeWithRateLimit(
      type: RateLimitType.write,
      operation: () async {
        await supabase.from('sales').delete().eq('id', saleId);
      },
    );
  }
}

