import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../core/utils/date_time_helper.dart';

/// Early Adopters Dashboard
/// Track the first 100 users who get special pricing
class EarlyAdoptersPage extends StatefulWidget {
  const EarlyAdoptersPage({super.key});

  @override
  State<EarlyAdoptersPage> createState() => _EarlyAdoptersPageState();
}

class _EarlyAdoptersPageState extends State<EarlyAdoptersPage> {
  bool _isLoading = true;
  
  // Stats
  int _totalSlots = 100;
  int _usedSlots = 0;
  int _remainingSlots = 100;
  bool _quotaFull = false;
  
  // Early adopters list
  List<Map<String, dynamic>> _earlyAdopters = [];
  
  // Early adopter pricing
  static const double EARLY_ADOPTER_MONTHLY = 29.0;
  static const double STANDARD_MONTHLY = 39.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadEarlyAdopterStats(),
        _loadEarlyAdoptersList(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadEarlyAdopterStats() async {
    try {
      // Get early adopter count
      final countResponse = await supabase
          .from('early_adopters')
          .select('id')
          .count();
      
      final count = countResponse.count;
      
      // Check if quota is full
      final settingsResponse = await supabase
          .from('subscription_settings')
          .select('value')
          .eq('key', 'early_adopter_quota_full')
          .maybeSingle();
      
      if (mounted) {
        setState(() {
          _usedSlots = count;
          _remainingSlots = _totalSlots - count;
          _quotaFull = settingsResponse?['value'] == 'true';
        });
      }
    } catch (e) {
      debugPrint('Error loading early adopter stats: $e');
    }
  }

  Future<void> _loadEarlyAdoptersList() async {
    try {
      final response = await supabase
          .from('early_adopters')
          .select('''
            id,
            user_id,
            registration_number,
            registered_at,
            converted_at,
            subscription_id
          ''')
          .order('registration_number', ascending: true)
          .limit(100);
      
      final data = (response as List).cast<Map<String, dynamic>>();
      
      // Enrich with user emails if possible
      final enrichedData = <Map<String, dynamic>>[];
      for (final item in data) {
        final userId = item['user_id'] as String;
        
        // Try to get user email from subscriptions table
        String email = '${userId.substring(0, 8)}...';
        try {
          final subResponse = await supabase
              .from('subscriptions')
              .select('user_id')
              .eq('user_id', userId)
              .limit(1)
              .maybeSingle();
          
          if (subResponse != null) {
            // For now, use truncated user ID
            email = '${userId.substring(0, 12)}...';
          }
        } catch (_) {}
        
        enrichedData.add({
          ...item,
          'email': email,
        });
      }
      
      if (mounted) {
        setState(() {
          _earlyAdopters = enrichedData;
        });
      }
    } catch (e) {
      debugPrint('Error loading early adopters list: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 24),
            
            // Stats Cards
            _buildStatsCards(isMobile),
            const SizedBox(height: 24),
            
            // Progress Bar
            _buildProgressSection(),
            const SizedBox(height: 24),
            
            // Pricing Info
            _buildPricingInfo(isMobile),
            const SizedBox(height: 24),
            
            // Early Adopters List
            _buildEarlyAdoptersList(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 32),
            const SizedBox(width: 12),
            const Text(
              'Early Adopters',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '100 pengguna pertama mendapat harga istimewa RM29/bulan seumur hidup',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards(bool isMobile) {
    final cards = [
      _StatCard(
        title: 'Slot Digunakan',
        value: '$_usedSlots',
        description: 'daripada $_totalSlots slot',
        icon: Icons.people,
        color: Colors.blue,
      ),
      _StatCard(
        title: 'Slot Tinggal',
        value: '$_remainingSlots',
        description: _quotaFull ? 'Kuota penuh!' : 'slot masih ada',
        icon: Icons.card_giftcard,
        color: _remainingSlots > 0 ? Colors.green : Colors.red,
      ),
      _StatCard(
        title: 'Status Kuota',
        value: _quotaFull ? 'PENUH' : 'AKTIF',
        description: _quotaFull ? 'Harga standard' : 'Masih menerima',
        icon: _quotaFull ? Icons.lock : Icons.lock_open,
        color: _quotaFull ? Colors.red : Colors.green,
      ),
      _StatCard(
        title: 'Jimat Per User',
        value: 'RM${(STANDARD_MONTHLY - EARLY_ADOPTER_MONTHLY).toStringAsFixed(0)}',
        description: 'setiap bulan',
        icon: Icons.savings,
        color: Colors.amber,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        childAspectRatio: isMobile ? 1.3 : 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) => cards[index],
    );
  }

  Widget _buildProgressSection() {
    final progress = _usedSlots / _totalSlots;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Progress Early Adopter',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$_usedSlots / $_totalSlots',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 20,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? Colors.red : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress * 100).toStringAsFixed(1)}% penuh',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingInfo(bool isMobile) {
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Maklumat Harga',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: isMobile ? 16 : 48,
              runSpacing: 16,
              children: [
                _buildPriceItem(
                  'Early Adopter',
                  'RM${EARLY_ADOPTER_MONTHLY.toStringAsFixed(0)}/bulan',
                  'Harga seumur hidup untuk 100 pengguna pertama',
                  Colors.green,
                ),
                _buildPriceItem(
                  'Standard',
                  'RM${STANDARD_MONTHLY.toStringAsFixed(0)}/bulan',
                  'Harga normal selepas kuota penuh',
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceItem(String title, String price, String desc, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          price,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          desc,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEarlyAdoptersList(bool isMobile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Senarai Early Adopters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_earlyAdopters.length} pengguna',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_earlyAdopters.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Belum ada early adopters',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('User ID', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Tarikh Daftar', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _earlyAdopters.map((adopter) {
                    final registrationNumber = adopter['registration_number'] as int?;
                    final userId = adopter['user_id'] as String;
                    final registeredAt = adopter['registered_at'] != null
                        ? DateTime.parse(adopter['registered_at'] as String)
                        : null;
                    final convertedAt = adopter['converted_at'];
                    final hasConverted = convertedAt != null;
                    
                    return DataRow(
                      cells: [
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '#${registrationNumber ?? '-'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${userId.substring(0, 12)}...',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            registeredAt != null
                                ? DateFormat('dd MMM yyyy, HH:mm').format(
                                    DateTimeHelper.toLocalTime(registeredAt))
                                : '-',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: hasConverted ? Colors.green[100] : Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              hasConverted ? 'Subscribed' : 'Trial',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: hasConverted ? Colors.green[800] : Colors.orange[800],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String description;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

