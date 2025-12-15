import 'package:intl/intl.dart';

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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}



