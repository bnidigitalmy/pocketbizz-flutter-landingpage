import 'package:flutter/material.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/admin_helper.dart';
import '../../bookings/presentation/bookings_page_optimized.dart';
import '../../products/presentation/product_list_page.dart';
import '../../sales/presentation/sales_page.dart';
import '../../expenses/presentation/expenses_page.dart';
import '../../expenses/presentation/receipt_scan_page.dart';
import '../../vendors/presentation/vendors_page.dart';
import '../../production/presentation/production_planning_page.dart';
import '../../finished_products/presentation/finished_products_page.dart';
import '../../products/presentation/test_image_upload_page.dart';
import 'dashboard_page_optimized.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardPageOptimized(),
    const BookingsPageOptimized(),
    const ProductListPage(),
    const SalesPage(),
  ];

  /// Open Receipt Scan page
  void _openReceiptScan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReceiptScanPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      // Bottom navigation with Scan in center (Bank Islam style - prominent center)
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildNavItem(0, Icons.dashboard, 'Dashboard'),
                _buildNavItem(1, Icons.event_note, 'Tempahan'),
                // Center Scan button - elevated above others
                Transform.translate(
                  offset: const Offset(0, -12),
                  child: _buildScanButton(),
                ),
                _buildNavItem(2, Icons.inventory, 'Produk'),
                _buildNavItem(3, Icons.point_of_sale, 'Jualan'),
              ],
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: AppColors.logoGradient,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // PocketBizz Text Only - Clean and Simple
                  const Text(
                    'PocketBizz',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    supabase.auth.currentUser?.email ?? 'Guest',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Core Operations
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'OPERASI UTAMA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_note),
              title: const Text('Tempahan'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Produk'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.point_of_sale),
              title: const Text('Jualan'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Planner'),
              subtitle: const Text('Tugas & peringatan'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/planner');
              },
            ),
            const Divider(),
            
            // Production & Inventory
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'PENGELUARAN & INVENTORI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.factory_rounded),
              title: const Text('Pengeluaran'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProductionPlanningPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Stok Siap'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FinishedProductsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('Pengurusan Stok'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/stock');
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Senarai Belian'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/shopping-list');
              },
            ),
            const Divider(),
            
            // Procurement
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'PEROLEHAN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Pesanan Belian'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/purchase-orders');
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Pembekal'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/suppliers');
              },
            ),
            const Divider(),
            
            // Distribution & Partners
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'PENGEDARAN & RAKAN KONGSI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Vendor'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VendorsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: const Text('Penghantaran'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/deliveries');
              },
            ),
            const Divider(),
            
            // Financial
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'KEWANGAN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Perbelanjaan'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/expenses');
              },
            ),
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('Tuntutan'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/claims');
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Laporan & Analitik'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/reports');
              },
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium, color: Colors.amber),
              title: const Text('Langganan'),
              subtitle: const Text('Urus langganan anda', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/subscription');
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder, color: Colors.orange),
              title: const Text('Dokumen Saya'),
              subtitle: const Text('Backup automatik ke Supabase', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/documents');
              },
            ),
            // Hidden from user - development/testing features
            // ListTile(
            //   leading: const Icon(Icons.cloud, color: Colors.blue),
            //   title: const Text('Google Drive Sync'),
            //   subtitle: const Text('Dokumen yang di-sync', style: TextStyle(fontSize: 11)),
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.pushNamed(context, '/drive-sync');
            //   },
            // ),
            // const Divider(),
            // ListTile(
            //   leading: const Icon(Icons.cloud_upload, color: Colors.blue),
            //   title: const Text('Test Image Upload'),
            //   subtitle: const Text('Verify Supabase Storage', style: TextStyle(fontSize: 11)),
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.pushNamed(context, '/test-upload');
            //   },
            // ),
            const Divider(),
            // Admin Section (only visible to admins)
            if (AdminHelper.isAdmin()) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'ADMIN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.purple),
                title: const Text('Admin Dashboard'),
                subtitle: const Text('Subscriptions & Analytics', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/admin/subscriptions');
                },
              ),
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Tetapan'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log Keluar', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await SupabaseHelper.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build bottom navigation item
  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? AppColors.primary : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build center Scan button - Bank Islam style (prominent center button)
  Widget _buildScanButton() {
    return GestureDetector(
      onTap: _openReceiptScan,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.logoGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.document_scanner_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Scan',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

