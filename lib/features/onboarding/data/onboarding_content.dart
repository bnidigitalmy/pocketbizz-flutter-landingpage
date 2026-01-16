import 'package:flutter/material.dart';

/// Content/Copy untuk setiap screen dalam onboarding
class OnboardingContent {
  // Screen 1: Welcome
  static const welcome = OnboardingScreenData(
    icon: Icons.waving_hand,
    iconColor: Colors.amber,
    title: 'Selamat Datang!',
    subtitle: 'PocketBizz bantu anda urus:',
    bulletPoints: [
      'Stok bahan mentah',
      'Produk & resepi',
      'Pengeluaran & jualan',
    ],
    footerText: 'Ikut 4 langkah mudah untuk setup bisnes anda.',
    timeEstimate: '5-10 minit',
    primaryButtonText: 'Mula Sekarang',
    secondaryButtonText: 'Setup Nanti',
  );

  // Screen 2: Step 1 - Tambah Bahan
  static const stepStock = OnboardingScreenData(
    icon: Icons.inventory_2,
    iconColor: Colors.blue,
    stepNumber: 1,
    stepTotal: 4,
    title: 'Tambah Bahan',
    subtitle: 'Masukkan bahan-bahan yang anda guna untuk buat produk:',
    bulletPoints: [
      'Tepung, gula, telur',
      'Mentega, susu, koko',
      'Packaging (kotak, plastik)',
    ],
    tipTitle: 'Kenapa penting?',
    tipContent: 'Sistem guna harga bahan untuk KIRA KOS produk anda secara automatik.',
    primaryButtonText: 'Tambah Bahan Pertama',
    secondaryButtonText: 'Nanti Dulu',
    navigateTo: '/stock',
  );

  // Screen 3: Step 2 - Cipta Produk
  static const stepProduct = OnboardingScreenData(
    icon: Icons.cake,
    iconColor: Colors.brown,
    stepNumber: 2,
    stepTotal: 4,
    title: 'Cipta Produk',
    subtitle: 'Produk = barang yang anda jual\nResepi = senarai bahan + kuantiti',
    exampleTitle: 'Contoh:',
    exampleContent: '''🎂 Kek Coklat 7"
   Tepung: 500g
   Gula: 300g
   Telur: 4 biji
   Harga Jual: RM 45''',
    tipTitle: 'Auto-kira kos!',
    tipContent: 'Sistem kira kos setiap produk dari resepi anda.',
    primaryButtonText: 'Cipta Produk Pertama',
    secondaryButtonText: 'Nanti Dulu',
    navigateTo: '/products/create',
  );

  // Screen 4: Step 3 - Rekod Pengeluaran
  static const stepProduction = OnboardingScreenData(
    icon: Icons.factory,
    iconColor: Colors.purple,
    stepNumber: 3,
    stepTotal: 4,
    title: 'Rekod Pengeluaran',
    subtitle: 'Bila anda BUAT produk, rekod di sini.',
    exampleTitle: 'Contoh:',
    exampleContent: '''📦 Bahan    →    🍰 Produk

Tepung -500g      Kek +1 unit
Gula -300g
Telur -4 biji''',
    tipTitle: 'Stok auto-tolak!',
    tipContent: 'Bila rekod pengeluaran, bahan mentah AUTO TOLAK. Tak perlu update manual!',
    primaryButtonText: 'Rekod Pengeluaran',
    secondaryButtonText: 'Nanti Dulu',
    navigateTo: '/production/record',
  );

  // Screen 5: Step 4 - Rekod Jualan
  static const stepSales = OnboardingScreenData(
    icon: Icons.point_of_sale,
    iconColor: Colors.green,
    stepNumber: 4,
    stepTotal: 4,
    title: 'Rekod Jualan',
    subtitle: 'Setiap kali anda JUAL, rekod di sini.',
    exampleTitle: 'Contoh:',
    exampleContent: '''💰 Jualan Hari Ini

Kek Coklat x 2     RM 90
Brownies x 5       RM 50
─────────────────────
JUMLAH             RM 140''',
    tipTitle: 'Stok auto-update!',
    tipContent: 'Produk siap AUTO TOLAK bila rekod jualan. Laporan jana automatik!',
    primaryButtonText: 'Rekod Jualan Pertama',
    secondaryButtonText: 'Nanti Dulu',
    navigateTo: '/sales/create',
  );

  // Screen 6: Completion
  static const completion = OnboardingScreenData(
    icon: Icons.celebration,
    iconColor: Colors.amber,
    title: 'Tahniah!',
    subtitle: 'Anda Dah Bersedia!',
    flowSummary: '📦 → 🍰 → 🏭 → 🛒 → 📊\nStok   Produk   Buat   Jual   Laporan',
    completionMessage: 'Flow bisnes anda dah setup',
    tipTitle: 'Tips Harian:',
    tipBullets: [
      'Rekod jualan SETIAP hari',
      'Check stok setiap pagi',
      'Lihat laporan setiap minggu',
    ],
    helpText: 'Perlukan bantuan?',
    helpContact: '010-782 7802 (WhatsApp)',
    primaryButtonText: 'Mula Guna PocketBizz',
  );
}

/// Data model untuk setiap onboarding screen
class OnboardingScreenData {
  final IconData icon;
  final Color iconColor;
  final int? stepNumber;
  final int? stepTotal;
  final String title;
  final String subtitle;
  final List<String>? bulletPoints;
  final String? exampleTitle;
  final String? exampleContent;
  final String? tipTitle;
  final String? tipContent;
  final List<String>? tipBullets;
  final String? flowSummary;
  final String? completionMessage;
  final String? helpText;
  final String? helpContact;
  final String? timeEstimate;
  final String? footerText;
  final String primaryButtonText;
  final String? secondaryButtonText;
  final String? navigateTo;

  const OnboardingScreenData({
    required this.icon,
    required this.iconColor,
    this.stepNumber,
    this.stepTotal,
    required this.title,
    required this.subtitle,
    this.bulletPoints,
    this.exampleTitle,
    this.exampleContent,
    this.tipTitle,
    this.tipContent,
    this.tipBullets,
    this.flowSummary,
    this.completionMessage,
    this.helpText,
    this.helpContact,
    this.timeEstimate,
    this.footerText,
    required this.primaryButtonText,
    this.secondaryButtonText,
    this.navigateTo,
  });
}
