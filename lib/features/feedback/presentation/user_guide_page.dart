import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Panduan Pengguna - Step by step guide for new users
class UserGuidePage extends StatefulWidget {
  const UserGuidePage({super.key});

  @override
  State<UserGuidePage> createState() => _UserGuidePageState();
}

class _UserGuidePageState extends State<UserGuidePage> {
  int _currentStep = 0;

  final List<_GuideStep> _steps = [
    _GuideStep(
      title: '👋 Selamat Datang!',
      icon: Icons.waving_hand,
      color: Colors.amber,
      content: '''
PocketBizz adalah aplikasi untuk uruskan bisnes pengeluaran (bakery, F&B, kraftangan dll).

**Flow utama PocketBizz:**

1. 📱 Install app ke phone
2. 📦 Masukkan stok bahan mentah
3. 🍰 Cipta produk & resepi
4. 🏭 Rekod pengeluaran
5. 🛒 Rekod jualan
6. 📊 Lihat laporan

**Penting:**
• Ikut langkah secara berurutan
• Langkah 2-4 WAJIB buat dulu

Jom mula! 🚀
''',
    ),
    _GuideStep(
      title: '📱 Install App ke Phone',
      icon: Icons.install_mobile,
      color: Colors.deepPurple,
      content: '''
**Untuk pengalaman terbaik!**

PocketBizz boleh diinstall macam app biasa supaya lebih senang guna.

**Untuk iPhone (Safari):**

1. Buka app.pocketbizz.my di Safari
2. Tekan icon "Share" (kotak dengan anak panah)
3. Scroll bawah, tekan "Add to Home Screen"
4. Tekan "Add"
5. Siap! Icon PocketBizz ada di home screen

**Untuk Android (Chrome):**

1. Buka app.pocketbizz.my di Chrome
2. Tekan menu (3 titik) di kanan atas
3. Tekan "Add to Home Screen" atau "Install App"
4. Tekan "Add" atau "Install"
5. Siap! Icon PocketBizz ada di home screen

**Kelebihan install:**
• Buka terus macam app biasa
• Tak perlu taip URL
• Lebih laju load
• Boleh guna offline (terhad)

✅ Siap install!
''',
    ),
    _GuideStep(
      title: '📦 Langkah 1: Stok Bahan Mentah',
      icon: Icons.inventory,
      color: Colors.blue,
      content: '''
**Ini langkah PERTAMA dan WAJIB!**

Bahan mentah = bahan untuk buat produk anda.
Contoh: tepung, gula, telur, mentega, dll.

**Cara buat:**

1. Tekan menu "Stok" di sidebar
2. Tekan butang "+" untuk tambah bahan baru
3. Isi maklumat:
   • Nama bahan (cth: Tepung Gandum)
   • Unit ukuran (kg/gram/pcs/dll)
   • Saiz pakej (cth: 1 kg)
   • Harga beli (cth: RM 8.00)
   • Kuantiti semasa
4. Tekan "Simpan"

**Tips:**
• Masukkan SEMUA bahan yang anda guna
• Harga beli penting untuk kira kos produk

✅ Siap langkah 1!
''',
    ),
    _GuideStep(
      title: '🍰 Langkah 2: Cipta Produk & Resepi',
      icon: Icons.cake,
      color: Colors.brown,
      content: '''
**Sekarang boleh cipta produk!**

Produk = barang yang anda jual.
Resepi = senarai bahan untuk buat produk.

**Cara buat:**

1. Tekan menu "Produk" di sidebar
2. Tekan butang "+" untuk tambah produk
3. Isi maklumat produk:
   • Nama produk (cth: Kek Coklat)
   • Harga jualan (cth: RM 15.00)
   • Unit (pcs/kotak/dll)
4. Tambah resepi:
   • Pilih bahan dari stok
   • Masukkan kuantiti (cth: 500g tepung)
   • Tambah semua bahan yang diperlukan
5. Set kos tambahan (optional):
   • Kos buruh
   • Kos pembungkusan
6. Tekan "Simpan"

**Auto-kira:**
• App akan kira kos per unit secara automatik!

✅ Siap langkah 2!
''',
    ),
    _GuideStep(
      title: '🏭 Langkah 3: Rekod Pengeluaran',
      icon: Icons.factory,
      color: Colors.purple,
      content: '''
**Bila dah ada stok & produk, boleh mula buat!**

Pengeluaran = proses buat produk dari bahan mentah.

**Cara buat:**

1. Tekan menu "Pengeluaran" di sidebar
2. Tekan "Rekod Pengeluaran"
3. Pilih produk yang nak buat
4. Masukkan kuantiti (berapa unit)
5. Tekan "Simpan"

**Apa yang berlaku:**
• Bahan mentah AUTO TOLAK dari stok
• Production batch dicipta
• Stok produk siap untuk dijual

**Contoh:**
Buat 20 unit Kek Coklat:
→ Tepung -10kg (auto tolak)
→ Gula -4kg (auto tolak)
→ Kek Coklat +20 unit (ready jual)

✅ Siap langkah 3!
''',
    ),
    _GuideStep(
      title: '🛒 Langkah 4: Rekod Jualan',
      icon: Icons.point_of_sale,
      color: Colors.green,
      content: '''
**Dah ada stok produk siap? Boleh jual!**

**Cara buat:**

1. Tekan menu "Jualan" di sidebar
2. Tekan butang "+" untuk jualan baru
3. Pilih produk yang dijual
4. Masukkan kuantiti
5. Pilih saluran jualan:
   • Kedai
   • Online
   • WhatsApp
   • dll
6. Tekan "Simpan Jualan"

**Auto-tolak (FIFO):**
• Stok produk siap auto tolak
• Sistem ambil dari batch LAMA dulu

**Tips:**
• Rekod setiap jualan dengan segera
• Jangan tunggu akhir hari

✅ Siap langkah 4!
''',
    ),
    _GuideStep(
      title: '🚚 Langkah 5: Vendor (Optional)',
      icon: Icons.local_shipping,
      color: Colors.orange,
      content: '''
**Untuk bisnes konsainan sahaja.**

Kalau anda hantar produk ke kedai/vendor lain untuk dijual.

**Cara buat:**

1. Tekan menu "Vendor" di sidebar
2. Tambah vendor baru (kedai/agent)
3. Set komisyen (% atau tetap)
4. Rekod penghantaran:
   • Pilih vendor
   • Pilih produk & kuantiti
   • Hantar!
5. Buat tuntutan bila produk terjual

**Flow:**
Hantar → Vendor jual → Buat tuntutan → Dapat bayaran

**Skip langkah ini jika:**
• Anda jual sendiri sahaja
• Tak ada agent/konsainan

✅ Siap langkah 5!
''',
    ),
    _GuideStep(
      title: '📊 Langkah 6: Lihat Laporan',
      icon: Icons.analytics,
      color: Colors.indigo,
      content: '''
**Check prestasi bisnes anda!**

**Cara buat:**

1. Tekan menu "Laporan" di sidebar
2. Pilih jenis laporan:
   • Jualan Harian/Bulanan
   • Untung Rugi
   • Stok Keluar/Masuk
3. Pilih tarikh
4. Tekan "Jana Laporan"

**Laporan penting:**
• Jumlah jualan hari ini
• Produk paling laris
• Untung kasar
• Stok rendah

**Tips:**
• Check laporan setiap minggu
• Bandingkan dengan minggu/bulan lepas
• Export ke PDF untuk simpan

✅ Siap langkah 6!
''',
    ),
    _GuideStep(
      title: '🎯 Tips Harian',
      icon: Icons.lightbulb,
      color: Colors.teal,
      content: '''
**Rutin harian untuk guna PocketBizz:**

☀️ **Pagi:**
• Check alert stok bahan rendah
• Plan pengeluaran hari ini
• Beli bahan kalau perlu

🌤️ **Siang/Petang:**
• Rekod pengeluaran yang dibuat
• Rekod setiap jualan dengan segera
• Update stok bila terima bekalan

🌙 **Malam:**
• Check laporan jualan hari ini
• Lihat untung rugi
• Plan untuk esok

**Ingat:**
• Data tepat = laporan tepat
• Rekod segera, jangan tangguh
• Check stok setiap hari
''',
    ),
    _GuideStep(
      title: '🆘 Perlukan Bantuan?',
      icon: Icons.help,
      color: Colors.red,
      content: '''
**Kami sedia membantu!**

📱 **WhatsApp:**
+60 10-782 7802

📧 **Email:**
support@pocketbizz.my

💬 **Dalam App:**
• Pergi "Sokongan & Komuniti"
• Tekan "Hantar Feedback"

**Bila hubungi kami:**
• Screenshot masalah anda
• Terangkan step yang dibuat
• Kami respond dalam 24 jam

**Sumber lain:**
• Video tutorial (coming soon)
• FAQ di website
• Komuniti Facebook/Telegram

🙏 Terima kasih guna PocketBizz!

**Ringkasan Flow:**
📦 Stok → 🍰 Produk → 🏭 Pengeluaran → 🛒 Jualan → 📊 Laporan
''',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentStep = _steps[_currentStep];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panduan Pengguna'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Step indicator
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentStep + 1} / ${_steps.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (_currentStep + 1) / _steps.length,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(currentStep.color),
            minHeight: 4,
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: currentStep.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          currentStep.icon,
                          size: 40,
                          color: currentStep.color,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          currentStep.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Step content
                  _buildContentCard(currentStep.content),
                  
                  const SizedBox(height: 24),
                  
                  // Step dots indicator
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_steps.length, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: index == _currentStep ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: index == _currentStep 
                                ? currentStep.color 
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                // Previous button
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _currentStep--);
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Sebelum'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
                
                const SizedBox(width: 12),
                
                // Next/Finish button
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_currentStep < _steps.length - 1) {
                        setState(() => _currentStep++);
                      } else {
                        // Finished - go back
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🎉 Tahniah! Anda dah bersedia guna PocketBizz!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      _currentStep < _steps.length - 1 
                          ? Icons.arrow_forward 
                          : Icons.check_circle,
                    ),
                    label: Text(
                      _currentStep < _steps.length - 1 
                          ? 'Seterusnya' 
                          : 'Selesai!',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentStep.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(String content) {
    // Parse content for simple markdown-like formatting
    final lines = content.trim().split('\n');
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          final trimmed = line.trim();
          
          // Empty line = spacer
          if (trimmed.isEmpty) {
            return const SizedBox(height: 8);
          }
          
          // Bold header (starts with **)
          if (trimmed.startsWith('**') && trimmed.endsWith('**')) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(
                trimmed.replaceAll('**', ''),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            );
          }
          
          // Bullet point (starts with •)
          if (trimmed.startsWith('•')) {
            return Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 15)),
                  Expanded(
                    child: Text(
                      trimmed.substring(1).trim(),
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }
          
          // Numbered item (starts with number.)
          if (RegExp(r'^\d+\.').hasMatch(trimmed)) {
            return Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 6),
              child: Text(
                trimmed,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            );
          }
          
          // Emoji headers (☀️ 🌤️ 🌙 etc)
          if (trimmed.contains('**') && trimmed.contains(':')) {
            final parts = trimmed.split('**');
            if (parts.length >= 2) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4, top: 8),
                child: Text(
                  trimmed.replaceAll('**', ''),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            }
          }
          
          // Success indicator (✅)
          if (trimmed.startsWith('✅')) {
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Text(
                  trimmed,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ),
            );
          }
          
          // Regular text
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              trimmed,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GuideStep {
  final String title;
  final IconData icon;
  final Color color;
  final String content;

  _GuideStep({
    required this.title,
    required this.icon,
    required this.color,
    required this.content,
  });
}

