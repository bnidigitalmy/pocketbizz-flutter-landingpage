import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../data/models/subscription.dart';
import '../../data/repositories/subscription_repository_supabase.dart';
import '../../services/subscription_service.dart';

/// Admin Dashboard for Subscription Management
/// Shows overview, revenue, analytics, and subscription management
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _subscriptionService = SubscriptionService();
  final _subscriptionRepo = SubscriptionRepositorySupabase();
  
  bool _isLoading = true;
  
  // User Stats
  int _totalUsers = 0;
  int _paidUsers = 0;
  int _activeTrial = 0;
  int _expiredTrial = 0;
  int _graceUsers = 0;
  
  // Subscription Stats
  int _totalSubscriptions = 0;
  int _activeSubscriptions = 0;
  
  // Revenue Stats
  double _mrr = 0.0;
  double _totalRevenue = 0.0;
  
  // Early Adopter Stats
  int _earlyAdopterCount = 0;
  int _earlyAdopterSlots = 100;
  
  // Recent Activities
  List<Map<String, dynamic>> _recentActivities = [];
  
  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadUserStats(),
        _loadSubscriptionStats(),
        _loadRevenueStats(),
        _loadEarlyAdopterStats(),
        _loadRecentActivities(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final allSubs = await _subscriptionRepo.getAdminSubscriptions(limit: 1000);
      
      final userIds = allSubs.map((s) => s.userId).toSet();
      _totalUsers = userIds.length;
      
      final paidUserIds = allSubs
          .where((s) => s.status == SubscriptionStatus.active && s.expiresAt.isAfter(DateTime.now()))
          .map((s) => s.userId)
          .toSet();
      _paidUsers = paidUserIds.length;
      
      final trialSubs = allSubs.where((s) => s.status == SubscriptionStatus.trial);
      _activeTrial = trialSubs.where((s) => s.expiresAt.isAfter(DateTime.now())).length;
      _expiredTrial = trialSubs.where((s) => s.expiresAt.isBefore(DateTime.now())).length;
      
      _graceUsers = allSubs.where((s) => s.status == SubscriptionStatus.grace).length;
    } catch (e) {
      debugPrint('Error loading user stats: $e');
    }
  }

  Future<void> _loadSubscriptionStats() async {
    final stats = await _subscriptionRepo.getAdminSubscriptionStats(
      startDate: DateTime.now().subtract(const Duration(days: 365)),
      endDate: DateTime.now(),
    );
    if (mounted) {
      setState(() {
        _totalSubscriptions = stats['total'] as int;
        _activeSubscriptions = stats['active'] as int;
      });
    }
  }

  Future<void> _loadRevenueStats() async {
    final revenue = await _subscriptionRepo.getAdminRevenueStats(
      startDate: DateTime.now().subtract(const Duration(days: 365)),
      endDate: DateTime.now(),
    );
    if (mounted) {
      setState(() {
        _mrr = (revenue['monthly'] as num).toDouble();
        _totalRevenue = (revenue['total'] as num?)?.toDouble() ?? _mrr * 12;
      });
    }
  }

  Future<void> _loadEarlyAdopterStats() async {
    try {
      final response = await supabase
          .from('early_adopters')
          .select('id')
          .count();
      
      if (mounted) {
        setState(() {
          _earlyAdopterCount = response.count;
        });
      }
    } catch (e) {
      debugPrint('Error loading early adopter stats: $e');
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      // Get recent subscriptions with plan info
      final response = await supabase
          .from('subscriptions')
          .select('id, user_id, status, created_at, subscription_plans(name)')
          .order('created_at', ascending: false)
          .limit(5);
      
      if (mounted) {
        final activities = (response as List).map((item) {
          final data = item as Map<String, dynamic>;
          return {
            ...data,
            'plan_name': data['subscription_plans']?['name'] ?? 'PocketBizz',
          };
        }).toList();
        
        setState(() {
          _recentActivities = activities.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('Error loading recent activities: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Memuatkan dashboard...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            _buildWelcomeHeader(),
            const SizedBox(height: 24),
            
            // Main Stats Row
            _buildMainStats(isMobile),
            const SizedBox(height: 20),
            
            // Secondary Stats Row
            _buildSecondaryStats(isMobile),
            const SizedBox(height: 24),
            
            // Early Adopter Progress & Conversion
            if (isMobile) ...[
              _buildEarlyAdopterCard(),
              const SizedBox(height: 16),
              _buildConversionCard(),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildEarlyAdopterCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildConversionCard()),
                ],
              ),
            const SizedBox(height: 24),
            
            // Recent Activity & Quick Stats
            if (isMobile) ...[
              _buildRecentActivityCard(),
              const SizedBox(height: 16),
              _buildQuickStatsCard(),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildRecentActivityCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildQuickStatsCard()),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Selamat Pagi' : now.hour < 18 ? 'Selamat Petang' : 'Selamat Malam';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
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
                Text(
                  '$greeting, Admin! 👋',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, d MMMM yyyy', 'ms').format(now),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pantau prestasi PocketBizz anda di sini',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStats(bool isMobile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : 4,
      childAspectRatio: isMobile ? 1.4 : 1.6,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildStatCard(
          title: 'Jumlah Pengguna',
          value: '$_totalUsers',
          icon: Icons.people_rounded,
          color: Colors.blue,
          gradient: [Colors.blue[400]!, Colors.blue[600]!],
        ),
        _buildStatCard(
          title: 'Pengguna Aktif',
          value: '$_paidUsers',
          icon: Icons.verified_user_rounded,
          color: Colors.green,
          gradient: [Colors.green[400]!, Colors.green[600]!],
        ),
        _buildStatCard(
          title: 'Trial Aktif',
          value: '$_activeTrial',
          icon: Icons.schedule_rounded,
          color: Colors.orange,
          gradient: [Colors.orange[400]!, Colors.orange[600]!],
        ),
        _buildStatCard(
          title: 'MRR',
          value: 'RM ${_mrr.toStringAsFixed(0)}',
          icon: Icons.trending_up_rounded,
          color: Colors.purple,
          gradient: [Colors.purple[400]!, Colors.purple[600]!],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required List<Color> gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryStats(bool isMobile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : 4,
      childAspectRatio: isMobile ? 2.0 : 2.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildMiniStatCard('Trial Tamat', '$_expiredTrial', Icons.timer_off, Colors.red),
        _buildMiniStatCard('Grace Period', '$_graceUsers', Icons.warning_amber_rounded, Colors.amber),
        _buildMiniStatCard('Total Subs', '$_totalSubscriptions', Icons.subscriptions, Colors.indigo),
        _buildMiniStatCard('Early Adopters', '$_earlyAdopterCount', Icons.star, Colors.amber),
      ],
    );
  }

  Widget _buildMiniStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarlyAdopterCard() {
    final progress = _earlyAdopterCount / _earlyAdopterSlots;
    final remaining = _earlyAdopterSlots - _earlyAdopterCount;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Early Adopter Program',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_earlyAdopterCount / $_earlyAdopterSlots',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$remaining slot tersisa',
                    style: TextStyle(
                      fontSize: 12,
                      color: remaining > 0 ? Colors.green[600] : Colors.red[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                width: 70,
                height: 70,
                child: Stack(
                  children: [
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0 ? Colors.red : Colors.amber,
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? Colors.red : Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversionCard() {
    final conversionRate = _totalUsers > 0 ? (_paidUsers / _totalUsers * 100) : 0.0;
    final trialConversion = _activeTrial + _expiredTrial > 0 
        ? (_paidUsers / (_activeTrial + _expiredTrial) * 100).clamp(0, 100)
        : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics_rounded, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Conversion Metrics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildMetricRow(
            'Overall Conversion',
            '${conversionRate.toStringAsFixed(1)}%',
            conversionRate / 100,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildMetricRow(
            'Trial to Paid',
            '${trialConversion.toStringAsFixed(1)}%',
            trialConversion / 100,
            Colors.green,
          ),
          const SizedBox(height: 16),
          _buildMetricRow(
            'Active Rate',
            '${(_activeSubscriptions / (_totalSubscriptions > 0 ? _totalSubscriptions : 1) * 100).toStringAsFixed(1)}%',
            _activeSubscriptions / (_totalSubscriptions > 0 ? _totalSubscriptions : 1),
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 6,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.history_rounded, color: Colors.blue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Aktiviti Terkini',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gunakan sidebar untuk lihat semua subscriptions')),
                  );
                },
                child: Text(
                  'Lihat Semua',
                  style: TextStyle(color: AppColors.primary, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentActivities.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Tiada aktiviti terkini',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            )
          else
            ..._recentActivities.map((activity) => _buildActivityItem(activity)).toList(),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final status = activity['status'] as String? ?? 'unknown';
    final userId = activity['user_id'] as String? ?? '';
    final createdAt = activity['created_at'] != null
        ? DateTime.parse(activity['created_at'] as String)
        : DateTime.now();
    
    IconData icon;
    Color color;
    String statusText;
    
    switch (status) {
      case 'active':
        icon = Icons.check_circle;
        color = Colors.green;
        statusText = 'Subscription aktif';
        break;
      case 'trial':
        icon = Icons.schedule;
        color = Colors.blue;
        statusText = 'Trial bermula';
        break;
      case 'expired':
        icon = Icons.cancel;
        color = Colors.red;
        statusText = 'Subscription tamat';
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
        statusText = status;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${userId.substring(0, 8)}...',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('dd/MM HH:mm').format(createdAt.toLocal()),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insights_rounded, color: Colors.purple, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Quick Stats',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildQuickStatRow('Total Revenue', 'RM ${_totalRevenue.toStringAsFixed(0)}'),
          const Divider(height: 20),
          _buildQuickStatRow('Avg Per User', 'RM ${_paidUsers > 0 ? (_totalRevenue / _paidUsers).toStringAsFixed(0) : '0'}'),
          const Divider(height: 20),
          _buildQuickStatRow('Active Subs', '$_activeSubscriptions'),
          const Divider(height: 20),
          _buildQuickStatRow('Churn Risk', '$_expiredTrial users'),
        ],
      ),
    );
  }

  Widget _buildQuickStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
