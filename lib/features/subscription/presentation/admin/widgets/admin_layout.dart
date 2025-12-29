import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../admin_dashboard_page.dart';
import '../subscription_list_page.dart';
import '../user_management_page.dart';
import '../early_adopters_page.dart';
import '../../../../announcements/presentation/admin/admin_announcements_page.dart';
import '../../../../feedback/presentation/admin/admin_feedback_page.dart';

/// Admin Layout with Sidebar Navigation
/// Responsive untuk desktop dan mobile
class AdminLayout extends StatefulWidget {
  final Widget? child;
  final String initialRoute;

  const AdminLayout({
    super.key,
    this.child,
    this.initialRoute = '/admin/dashboard',
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  final List<AdminNavItem> _navItems = [
    AdminNavItem(
      icon: Icons.dashboard,
      label: 'Dashboard',
      route: '/admin/dashboard',
    ),
    AdminNavItem(
      icon: Icons.subscriptions,
      label: 'Subscriptions',
      route: '/admin/subscriptions',
    ),
    AdminNavItem(
      icon: Icons.people,
      label: 'User Management',
      route: '/admin/users',
    ),
    AdminNavItem(
      icon: Icons.star,
      label: 'Early Adopters',
      route: '/admin/early-adopters',
    ),
    AdminNavItem(
      icon: Icons.campaign,
      label: 'Announcements',
      route: '/admin/announcements',
    ),
    AdminNavItem(
      icon: Icons.feedback,
      label: 'Feedback',
      route: '/admin/feedback',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Set initial index based on route
    _selectedIndex = _navItems.indexWhere(
      (item) => item.route == widget.initialRoute,
    );
    if (_selectedIndex == -1) _selectedIndex = 0;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    if (isMobile) {
      // Mobile: Bottom Navigation - Scrollable horizontal
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: _navItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = _selectedIndex == index;
                  
                  return InkWell(
                    onTap: () => _onNavItemTapped(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? AppColors.primary.withOpacity(0.1) 
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey[600],
                            size: 20,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label.length > 10 
                                ? '${item.label.substring(0, 8)}...' 
                                : item.label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );
    }

    // Desktop: Sidebar
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo/Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Panel',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'PocketBizz',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: _navItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = _selectedIndex == index;
                
                return _buildNavItem(
                  item: item,
                  index: index,
                  isSelected: isSelected,
                );
              }).toList(),
            ),
          ),
          
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.person,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin User',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'admin@pocketbizz.my',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required AdminNavItem item,
    required int index,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: isSelected ? AppColors.primary : Colors.grey[600],
          size: 24,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppColors.primary : Colors.grey[800],
            fontSize: 15,
          ),
        ),
        selected: isSelected,
        onTap: () => _onNavItemTapped(index),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: isMobile
          ? Column(
              children: [
                // Mobile: Top AppBar
                AppBar(
                  title: const Text('Admin Panel'),
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                ),
                // Mobile: Page View
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _selectedIndex = index);
                    },
                    children: [
                      AdminDashboardPage(),
                      AdminSubscriptionListPage(),
                      AdminUserManagementPage(),
                      EarlyAdoptersPage(),
                      AdminAnnouncementsPage(),
                      AdminFeedbackPage(),
                    ],
                  ),
                ),
                // Mobile: Bottom Navigation
                _buildSidebar(context),
              ],
            )
          : Row(
              children: [
                // Desktop: Sidebar
                _buildSidebar(context),
                // Desktop: Main Content
                Expanded(
                  child: Column(
                    children: [
                      // Desktop: Top AppBar
                      Container(
                        height: 70,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text(
                              _navItems[_selectedIndex].label,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined),
                              onPressed: () {},
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Desktop: Page View
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            AdminDashboardPage(),
                            AdminSubscriptionListPage(),
                            AdminUserManagementPage(),
                            EarlyAdoptersPage(),
                            AdminAnnouncementsPage(),
                            AdminFeedbackPage(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class AdminNavItem {
  final IconData icon;
  final String label;
  final String route;

  AdminNavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

