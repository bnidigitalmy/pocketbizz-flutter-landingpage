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
PocketBizz adalah aplikasi untuk uruskan bisnes kecil anda dengan mudah.

Dalam panduan ini, anda akan belajar:
• Cara daftar produk
• Cara rekod jualan
• Cara urus stok
• Cara lihat laporan

Jom mula! 🚀
''',
    ),
    _GuideStep(
      title: '📦 Langkah 1: Daftar Produk',
      icon: Icons.inventory_2,
      color: Colors.brown,
      content: '''
**Apa perlu buat:**

1. Tekan menu "Produk" di sidebar
2. Tekan butang "+" untuk tambah produk baru
3. Isi maklumat:
   • Nama produk
   • Harga jualan
   • Kos produk (optional)
4. Tekan "Simpan"

**Tips:**
• Boleh upload gambar produk
• Letak harga yang betul dari awal
• Nama produk senang diingat

✅ Siap langkah 1!
''',
    ),
    _GuideStep(
      title: '🛒 Langkah 2: Rekod Jualan',
      icon: Icons.point_of_sale,
      color: Colors.green,
      content: '''
**Apa perlu buat:**

1. Tekan menu "Jualan" di sidebar
2. Tekan butang "+" untuk jualan baru
3. Pilih produk yang dijual
4. Masukkan kuantiti
5. Tekan "Simpan Jualan"

**Tips:**
• Boleh jual banyak produk sekali gus
• Pilih saluran (kedai/online/dll)
• Rekod setiap jualan supaya laporan tepat

✅ Siap langkah 2!
''',
    ),
    _GuideStep(
      title: '📊 Langkah 3: Urus Stok',
      icon: Icons.warehouse,
      color: Colors.blue,
      content: '''
**Apa perlu buat:**

1. Tekan menu "Stok" di sidebar
2. Lihat senarai stok anda
3. Untuk tambah stok:
   • Tekan item stok
   • Pilih "Tambah Stok"
   • Masukkan kuantiti

**Tips:**
• Set "Paras Minimum" untuk amaran stok rendah
• Stok auto tolak bila rekod jualan
• Check stok selalu supaya tak kehabisan

✅ Siap langkah 3!
''',
    ),
    _GuideStep(
      title: '📈 Langkah 4: Lihat Laporan',
      icon: Icons.analytics,
      color: Colors.purple,
      content: '''
**Apa perlu buat:**

1. Tekan menu "Laporan" di sidebar
2. Pilih jenis laporan:
   • Jualan Harian
   • Jualan Bulanan
   • Untung Rugi
3. Pilih tarikh yang nak lihat
4. Tekan "Jana Laporan"

**Tips:**
• Check laporan setiap minggu
• Bandingkan dengan bulan lepas
• Export ke PDF/Excel bila perlu

✅ Siap langkah 4!
''',
    ),
    _GuideStep(
      title: '🎯 Langkah 5: Tips Harian',
      icon: Icons.lightbulb,
      color: Colors.orange,
      content: '''
**Rutin harian yang disarankan:**

☀️ **Pagi:**
• Buka app, check stok rendah
• Sediakan produk untuk hari ini

🌤️ **Siang:**
• Rekod setiap jualan segera
• Update stok bila perlu

🌙 **Malam:**
• Check jualan hari ini
• Lihat untung rugi
• Plan untuk esok

**Ingat:**
• Rekod jualan terus, jangan tunggu
• Data yang tepat = keputusan yang baik
''',
    ),
    _GuideStep(
      title: '🆘 Perlukan Bantuan?',
      icon: Icons.help,
      color: Colors.teal,
      content: '''
**Kalau ada masalah:**

📱 **WhatsApp:**
+60 10-782 7802

📧 **Email:**
support@pocketbizz.my

💬 **Dalam App:**
• Pergi "Sokongan & Komuniti"
• Tekan "Hantar Feedback"

**Tips:**
• Screenshot masalah anda
• Terangkan langkah yang dibuat
• Kami akan bantu secepat mungkin!

🙏 Terima kasih guna PocketBizz!
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

