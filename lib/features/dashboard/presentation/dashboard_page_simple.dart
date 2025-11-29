import 'package:flutter/material.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/bookings_repository_supabase.dart';
import '../../vendors/presentation/vendors_page.dart';
import 'widgets/modern_stat_card.dart';
import 'widgets/quick_action_card.dart';
import 'widgets/low_stock_alerts_widget.dart';

class DashboardPageSimple extends StatefulWidget {
  const DashboardPageSimple({super.key});

  @override
  State<DashboardPageSimple> createState() => _DashboardPageSimpleState();
}

class _DashboardPageSimpleState extends State<DashboardPageSimple> {
  final _bookingsRepo = BookingsRepositorySupabase();
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    
    try {
      final stats = await _bookingsRepo.getStatistics();
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stats: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.textPrimary),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PocketBizz',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              user?.email ?? 'Guest',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: AppColors.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.business_center,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'PocketBizz',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user?.email ?? 'Guest',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Vendors'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VendorsPage()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Greeting Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '👋 Welcome back!',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Let\'s make today productive',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.business_center,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Stats Cards
                  if (_stats != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ModernStatCard(
                            title: 'Total Bookings',
                            value: _stats!['total_bookings'].toString(),
                            icon: Icons.event_note_rounded,
                            gradient: AppColors.primaryGradient,
                            onTap: () => Navigator.of(context).pushNamed('/bookings'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ModernStatCard(
                            title: 'Pending',
                            value: _stats!['pending'].toString(),
                            icon: Icons.pending_actions_rounded,
                            gradient: AppColors.warningGradient,
                            subtitle: 'Need Action',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ModernStatCard(
                            title: 'Confirmed',
                            value: _stats!['confirmed'].toString(),
                            icon: Icons.check_circle_rounded,
                            gradient: AppColors.accentGradient,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ModernStatCard(
                            title: 'Completed',
                            value: _stats!['completed'].toString(),
                            icon: Icons.done_all_rounded,
                            gradient: AppColors.successGradient,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ModernStatCard(
                      title: 'Total Revenue',
                      value: 'RM${(_stats!['total_revenue'] as double).toStringAsFixed(2)}',
                      icon: Icons.monetization_on_rounded,
                      gradient: AppColors.successGradient,
                      subtitle: '💰 Keep it up!',
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Quick Actions
                  const Row(
                    children: [
                      Icon(Icons.flash_on_rounded, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.3,
                    children: [
                      QuickActionCard(
                        label: 'New Booking',
                        icon: Icons.add_business_rounded,
                        color: AppColors.primary,
                        onTap: () => Navigator.of(context).pushNamed('/bookings/create'),
                      ),
                      QuickActionCard(
                        label: 'New Sale',
                        icon: Icons.point_of_sale_rounded,
                        color: AppColors.success,
                        onTap: () => Navigator.of(context).pushNamed('/sales/create'),
                      ),
                      QuickActionCard(
                        label: 'Stock Management',
                        icon: Icons.inventory_2_rounded,
                        color: AppColors.accent,
                        onTap: () => Navigator.of(context).pushNamed('/stock'),
                      ),
                      QuickActionCard(
                        label: 'Plan Production',
                        icon: Icons.factory_rounded,
                        color: Colors.purple,
                        onTap: () => Navigator.of(context).pushNamed('/production'),
                      ),
                      QuickActionCard(
                        label: 'Add Product',
                        icon: Icons.add_box_rounded,
                        color: AppColors.warning,
                        onTap: () => Navigator.of(context).pushNamed('/products/add'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),

                  // Low Stock Alerts Widget
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Stock Alerts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const LowStockAlertsWidget(),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

}

