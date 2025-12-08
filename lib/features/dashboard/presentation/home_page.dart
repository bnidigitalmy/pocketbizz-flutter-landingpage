import 'package:flutter/material.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/widgets/pocketbizz_logo.dart';
import '../../../core/theme/app_colors.dart';
import '../../bookings/presentation/bookings_page_optimized.dart';
import '../../products/presentation/product_list_page.dart';
import '../../sales/presentation/sales_page.dart';
import '../../expenses/presentation/expenses_page.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note),
            label: 'Tempahan',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory),
            label: 'Produk',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale),
            label: 'Jualan',
          ),
        ],
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
                  // PocketBizz Logo - Larger and better positioned
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/transparentlogo2.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/images/transparentlogo.png',
                            width: 56,
                            height: 56,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'assets/images/logo.png',
                                width: 56,
                                height: 56,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.logoGradient,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'PocketBizz',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
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
              leading: const Icon(Icons.cloud, color: Colors.blue),
              title: const Text('Google Drive Sync'),
              subtitle: const Text('Dokumen yang di-sync', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/drive-sync');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cloud_upload, color: Colors.blue),
              title: const Text('Test Image Upload'),
              subtitle: const Text('Verify Supabase Storage', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/test-upload');
              },
            ),
            const Divider(),
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
}

