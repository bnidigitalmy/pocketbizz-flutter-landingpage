import '../../core/supabase/supabase_client.dart';
import 'production_repository_supabase.dart';

/// Sale model
class Sale {
  final String id;
  final String? customerName;
  final String channel;
  final double totalAmount;
  final double? discountAmount;
  final double finalAmount;
  final String? notes;
  final DateTime createdAt;
  final List<SaleItem>? items;

  Sale({
    required this.id,
    this.customerName,
    required this.channel,
    required this.totalAmount,
    this.discountAmount,
    required this.finalAmount,
    this.notes,
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
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
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

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
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

/// Sales repository using Supabase
class SalesRepositorySupabase {
  /// Create a new sale
  Future<Sale> createSale({
    String? customerName,
    String channel = 'walk-in',
    required List<Map<String, dynamic>> items,
    double? discountAmount,
    String? notes,
    String? deliveryAddress,
  }) async {
    // Get current user ID
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Check stock availability for all items BEFORE creating sale
    final productionRepo = ProductionRepository(supabase);
    for (final item in items) {
      final productId = item['product_id'] as String;
      final quantityNeeded = (item['quantity'] as num).toDouble();
      final productName = item['product_name'] as String? ?? 'Unknown';
      
      // Get total available stock for this product
      final availableStock = await productionRepo.getTotalRemainingForProduct(productId);
      
      if (availableStock < quantityNeeded) {
        throw Exception(
          'Insufficient stock for "$productName": Available: $availableStock, Required: $quantityNeeded'
        );
      }
    }

    // Calculate totals
    final totalAmount = items.fold<double>(
      0,
      (sum, item) => sum + (item['quantity'] * item['unit_price']),
    );

    final finalAmount = totalAmount - (discountAmount ?? 0);

    // Insert sale
    final sale = await supabase.from('sales').insert({
      'business_owner_id': userId,
      'customer_name': customerName,
      'channel': channel,
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'final_amount': finalAmount,
      'notes': notes,
      'delivery_address': deliveryAddress,
    }).select().single();

    // Insert sale items
    final saleItems = items.map((item) => {
      'sale_id': sale['id'],
      'product_id': item['product_id'],
      'product_name': item['product_name'],
      'quantity': item['quantity'],
      'unit_price': item['unit_price'],
      'subtotal': item['quantity'] * item['unit_price'],
    }).toList();

    await supabase.from('sale_items').insert(saleItems);

    // Deduct stock from production batches (FIFO)
    for (final item in items) {
      final productId = item['product_id'] as String;
      final quantityToDeduct = (item['quantity'] as num).toDouble();
      
      // Use FIFO to deduct from oldest batches first
      // Log with reference to this sale for tracking
      await productionRepo.deductFIFO(
        productId,
        quantityToDeduct,
        referenceId: sale['id'],
        referenceType: 'sale',
        notes: 'Jualan #${sale['id'].toString().substring(0, 8)}',
      );
    }

    // Return sale with items
    return getSale(sale['id']);
  }

  /// Get sale by ID with items
  Future<Sale> getSale(String saleId) async {
    final data = await supabase
        .from('sales')
        .select('*, sale_items(*)')
        .eq('id', saleId)
        .single();

    return Sale.fromJson(data);
  }

  /// List all sales
  Future<List<Sale>> listSales({
    String? channel,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    var query = supabase
        .from('sales')
        .select('*, sale_items(*)');

    // Apply filters
    if (channel != null && channel.isNotEmpty) {
      query = query.eq('channel', channel);
    }

    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }

    if (endDate != null) {
      query = query.lte('created_at', endDate.toIso8601String());
    }

    // Execute query with order and limit
    final data = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List).map((json) => Sale.fromJson(json)).toList();
  }

  /// Get today's sales summary
  Future<Map<String, dynamic>> getTodaySummary() async {
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
  }

  /// Delete sale
  Future<void> deleteSale(String saleId) async {
    await supabase.from('sales').delete().eq('id', saleId);
  }
}

