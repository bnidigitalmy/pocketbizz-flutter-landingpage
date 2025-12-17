import 'package:intl/intl.dart';

/// Structured receipt data from OCR
class ReceiptData {
  final String? merchant;
  final String? date;
  final List<ReceiptItem> items;
  final double? subtotal;
  final double? tax;
  final double? total;

  ReceiptData({
    this.merchant,
    this.date,
    this.items = const [],
    this.subtotal,
    this.tax,
    this.total,
  });

  factory ReceiptData.fromJson(Map<String, dynamic> json) {
    return ReceiptData(
      merchant: json['merchant'] as String?,
      date: json['date'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => ReceiptItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      tax: (json['tax'] as num?)?.toDouble(),
      total: (json['total'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchant': merchant,
      'date': date,
      'items': items.map((i) => i.toJson()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
    }..removeWhere((_, value) => value == null);
  }
}

/// Receipt item from OCR
class ReceiptItem {
  final String name;
  final double price;
  final double? quantity;

  ReceiptItem({
    required this.name,
    required this.price,
    this.quantity,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      if (quantity != null) 'quantity': quantity,
    };
  }
}

/// Expense model mapped from Supabase `expenses` table.
class Expense {
  final String id;
  final String businessOwnerId;
  final String? vendorId;
  final String category;
  final double amount;
  final String currency;
  final DateTime expenseDate;
  final String? notes;
  final String? ocrReceiptId;
  final String? receiptImageUrl; // URL to receipt image in Supabase Storage
  final ReceiptData? receiptData; // Structured receipt data from OCR
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense({
    required this.id,
    required this.businessOwnerId,
    required this.category,
    required this.amount,
    required this.currency,
    required this.expenseDate,
    required this.createdAt,
    required this.updatedAt,
    this.vendorId,
    this.notes,
    this.ocrReceiptId,
    this.receiptImageUrl,
    this.receiptData,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      vendorId: json['vendor_id'] as String?,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: (json['currency'] as String?) ?? 'MYR',
      expenseDate: json['expense_date'] is String
          ? DateTime.parse(json['expense_date'] as String)
          : DateTime.now(),
      notes: json['notes'] as String?,
      ocrReceiptId: json['ocr_receipt_id'] as String?,
      receiptImageUrl: json['receipt_image_url'] as String?,
      receiptData: json['receipt_data'] != null
          ? ReceiptData.fromJson(json['receipt_data'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] is String
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'vendor_id': vendorId,
      'category': category,
      'amount': amount,
      'currency': currency,
      'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
      'notes': notes,
      'ocr_receipt_id': ocrReceiptId,
      'receipt_image_url': receiptImageUrl,
      'receipt_data': receiptData?.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}



