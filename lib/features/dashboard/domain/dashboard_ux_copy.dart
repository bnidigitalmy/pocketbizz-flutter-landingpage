/// Dashboard UX Copy Helper
/// Coach-style, BM santai messages
/// Rule: Nada coach, ayat pendek, jangan guna caps lock, jangan bunyi macam boss

import 'package:flutter/material.dart';
import 'package:pocketbizz/core/theme/app_colors.dart';
import 'dashboard_mood_engine.dart';
import '../presentation/widgets/v2/dashboard_v2_format.dart';

class DashboardUXCopy {
  /// Get suggestion title (coach style)
  static String getSuggestionTitle({
    required String type, // 'low_stock', 'no_sales', 'high_expense', etc.
    required MoodTone mood,
  }) {
    if (mood == MoodTone.urgent) {
      switch (type) {
        case 'stock_zero':
          return 'Stok kritikal';
        case 'order_overdue':
          return 'Order perlu tindakan';
        case 'batch_expired':
          return 'Batch tamat tempoh';
        default:
          return 'Perhatian diperlukan';
      }
    }

    // Calm/Focused tone
    switch (type) {
      case 'low_stock':
        return 'Satu persediaan kecil hari ini';
      case 'no_sales':
        return 'Mula momentum hari ini';
      case 'high_expense':
        return 'Perhatian kecil';
      case 'production_suggestion':
        return 'Cadangan untuk hari ini';
      default:
        return 'Cadangan ringkas';
    }
  }

  /// Get suggestion message (coach style, encouraging)
  static String getSuggestionMessage({
    required String type,
    required MoodTone mood,
    Map<String, dynamic>? data,
  }) {
    if (mood == MoodTone.urgent) {
      switch (type) {
        case 'stock_zero':
          return 'Stok habis. Produksi tidak boleh diteruskan tanpa restock.';
        case 'order_overdue':
          return 'Ada order belum diproses. Perlu tindakan segera.';
        case 'batch_expired':
          return 'Batch tamat tempoh. Perlu semak stok siap.';
        default:
          return 'Perlu tindakan segera.';
      }
    }

    // Calm/Focused tone - coach style
    switch (type) {
      case 'low_stock':
        final productName = data?['productName'] ?? 'produk';
        return 'Untuk elak gangguan produksi, stok $productName disyorkan untuk ditambah.';
      
      case 'no_sales':
        return 'Belum ada jualan hari ini. Buat 1 transaksi awal untuk mula momentum.';
      
      case 'high_expense':
        final expense = data?['expense'];
        final inflow = data?['inflow'];
        if (expense != null && inflow != null) {
          return 'Kos agak tinggi. Boleh semak bila ada masa.';
        }
        return 'Perhatian kecil: Kos agak tinggi. Boleh semak bila ada masa.';
      
      case 'production_suggestion':
        final message = data?['message'] ?? '';
        return message.isNotEmpty 
            ? message 
            : 'Satu persediaan kecil hari ini boleh elakkan masalah esok.';
      
      default:
        return 'Satu langkah kecil untuk hari ini.';
    }
  }

  /// Get CTA button text (coach style, not bossy)
  static String getCTAText({
    required String action, // 'add_stock', 'add_sale', 'view_expense', etc.
    required MoodTone mood,
  }) {
    if (mood == MoodTone.urgent) {
      switch (action) {
        case 'add_stock':
          return 'Tambah Stok Sekarang';
        case 'add_sale':
          return 'Buat Jualan';
        case 'view_order':
          return 'Semak Order';
        default:
          return 'Tindakan';
      }
    }

    // Calm/Focused tone - encouraging, not bossy
    switch (action) {
      case 'add_stock':
        return 'Tambah Stok Supaya Produksi Lancar';
      case 'add_sale':
        return 'Buat Jualan Pertama';
      case 'view_expense':
        return 'Semak Belanja';
      case 'view_sales':
        return 'Lihat Jualan';
      case 'view_finished_stock':
        return 'Semak Stok Siap';
      case 'start_production':
        return 'Mula Produksi';
      default:
        return 'Lanjutkan';
    }
  }

  /// Get status message (positive reinforcement)
  static String getStatusMessage({
    required String type, // 'profit', 'sales', 'good_day', etc.
    required MoodTone mood,
    Map<String, dynamic>? data,
  }) {
    switch (type) {
      case 'profit':
        final profit = data?['profit'] ?? 0.0;
        if (profit > 0) {
          return 'Good job 👍 Jualan hari ini memberi keuntungan.';
        }
        return 'Jualan hari ini perlu dipertingkatkan.';
      
      case 'sales':
        final sales = data?['sales'] ?? 0.0;
        if (sales > 0) {
          return 'Jualan hari ini dalam keadaan baik.';
        }
        return 'Belum ada jualan hari ini.';
      
      case 'good_day':
        return 'Hari ini berjalan lancar.';
      
      default:
        return '';
    }
  }

  /// Get evening summary message (reflective)
  static String getEveningSummary({
    required Map<String, dynamic> data,
  }) {
    final sales = data['sales'] ?? 0.0;
    final profit = data['profit'] ?? 0.0;
    final improvements = data['improvements'] ?? 0;

    final buffer = StringBuffer();
    buffer.writeln('Ringkasan Hari Ini');
    buffer.writeln('• Jualan: ${DashboardV2Format.currency(sales)}');
    buffer.writeln('• Untung: ${DashboardV2Format.currency(profit)}');
    
    if (improvements > 0) {
      buffer.writeln('• $improvements perkara boleh diperbaiki esok');
    } else {
      buffer.writeln('• Semuanya berjalan lancar hari ini');
    }

    return buffer.toString();
  }

  /// Get color for suggestion based on mood
  static Color getSuggestionColor({
    required String type,
    required MoodTone mood,
  }) {
    if (mood == MoodTone.urgent) {
      return AppColors.error; // Red for urgent
    }

    switch (type) {
      case 'low_stock':
      case 'production_suggestion':
        return AppColors.warning; // Orange/Amber
      case 'no_sales':
        return AppColors.info; // Blue
      case 'high_expense':
        return AppColors.warning; // Orange
      default:
        return AppColors.primary; // Teal
    }
  }
}

