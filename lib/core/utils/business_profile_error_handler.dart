import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Utility untuk handle error yang berkaitan dengan business profile
/// terutamanya duplicate key errors disebabkan prefix dokumen yang sama
class BusinessProfileErrorHandler {
  /// Detect jika error adalah duplicate invoice key error
  static bool isDuplicateInvoiceKeyError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return (errorStr.contains('duplicate key') || errorStr.contains('23505')) &&
        (errorStr.contains('invoice_number') || 
         errorStr.contains('claim_number') ||
         errorStr.contains('booking_number') ||
         errorStr.contains('po_number') ||
         errorStr.contains('payment_number'));
  }

  /// Show friendly error dialog untuk duplicate key error
  /// Returns true jika error telah dihandle
  static Future<bool> handleDuplicateKeyError({
    required BuildContext context,
    required dynamic error,
    required String actionName,
  }) async {
    if (!isDuplicateInvoiceKeyError(error)) {
      return false;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Nombor Dokumen Bertindih',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gagal mencipta rekod kerana nombor dokumen sudah wujud.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡 Kenapa ini berlaku?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sistem menggunakan 3 huruf pertama nama perniagaan sebagai prefix nombor dokumen. '
                    'Jika anda belum tetapkan nama perniagaan yang unik, prefix default akan digunakan dan boleh bertindih dengan pengguna lain.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.2),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ Cara selesaikan:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Pergi ke Tetapan > Profil Perniagaan\n'
                    '2. Isikan Nama Perniagaan anda\n'
                    '3. (Pilihan) Tetapkan prefix dokumen khas\n'
                    '4. Simpan dan cuba semula',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Tutup',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to settings page
              Navigator.pushNamed(context, '/settings');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Ke Tetapan'),
          ),
        ],
      ),
    );

    return true;
  }

  /// Show snackbar dengan mesej yang friendly untuk duplicate key error
  static void showDuplicateKeySnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nombor dokumen sudah wujud. Sila lengkapkan Profil Perniagaan di Tetapan.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'TETAPAN',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pushNamed(context, '/settings');
          },
        ),
      ),
    );
  }
}
