import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_helper.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../data/models/subscription.dart';
import '../../data/models/subscription_plan.dart';
import '../../data/models/subscription_payment.dart';
import '../../data/repositories/subscription_repository_supabase.dart';
import '../../services/subscription_service.dart';

class AdminSubscriptionListPage extends StatefulWidget {
  const AdminSubscriptionListPage({super.key});

  @override
  State<AdminSubscriptionListPage> createState() => _AdminSubscriptionListPageState();
}

class _AdminSubscriptionListPageState extends State<AdminSubscriptionListPage> {
  final _repo = SubscriptionRepositorySupabase();
  final _service = SubscriptionService();
  bool _isLoading = true;
  bool _isActivating = false;
  bool _isExtending = false;
  List<Subscription> _subscriptions = [];
  List<SubscriptionPlan> _plans = [];
  String? _selectedStatus;
  String _searchQuery = '';
  Subscription? _selectedSubscription;

  // Activate dialog state
  bool _showActivateDialog = false;
  String? _selectedUserId;
  String _activateDuration = '3';
  String _activateNotes = '';
  List<Map<String, dynamic>> _availableUsers = [];

  // Extend dialog state
  bool _showExtendDialog = false;
  String _extendDuration = '3';
  String _extendNotes = '';

  // Pause dialog state
  bool _showPauseDialog = false;
  String _pauseDays = '7';
  String _pauseReason = '';

  // Refund dialog state
  bool _showRefundDialog = false;
  List<SubscriptionPayment> _subscriptionPayments = [];
  SubscriptionPayment? _selectedPayment;
  bool _isFullRefund = true;
  String _refundAmount = '';
  String _refundReason = '';

  // Package prices (matching database: RM 39/month standard)
  // Early adopter: RM 29/month (calculated dynamically)
  static const Map<int, double> PACKAGE_PRICES = {
    1: 39.0,   // 1 Bulan: RM 39
    3: 117.0,  // 3 Bulan: RM 117 (no discount)
    6: 215.0,  // 6 Bulan: RM 215 (8% discount)
    12: 398.0, // 12 Bulan: RM 398 (15% discount)
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repo.getAdminSubscriptions(
          status: _selectedStatus,
          limit: 1000,
        ),
        _service.getAvailablePlans(),
      ]);
      if (mounted) {
        final subs = results[0] as List<Subscription>;
        setState(() {
          _subscriptions = subs;
          _plans = results[1] as List<SubscriptionPlan>;
          _isLoading = false;
        });
        
        // Extract unique users for dropdown
        final userIds = <String>{};
        final usersList = <Map<String, dynamic>>[];
        for (final sub in subs) {
          if (!userIds.contains(sub.userId)) {
            userIds.add(sub.userId);
            usersList.add({
              'id': sub.userId,
              'email': '${sub.userId.substring(0, 8)}...', // Placeholder - will be replaced with actual email from Edge Function
            });
          }
        }
        setState(() => _availableUsers = usersList);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  double _getPerMonthRate(int duration) {
    return PACKAGE_PRICES[duration]! / duration;
  }

  int _getDiscount(int duration) {
    // Discount percentages from database:
    // 1 month: 0%, 3 months: 0%, 6 months: 8%, 12 months: 15%
    switch (duration) {
      case 1:
        return 0;
      case 3:
        return 0;
      case 6:
        return 8;
      case 12:
        return 15;
      default:
        return 0;
    }
  }

  List<Subscription> get _filteredSubscriptions {
    if (_searchQuery.isEmpty) return _subscriptions;
    final query = _searchQuery.toLowerCase();
    return _subscriptions.where((sub) {
      return sub.userId.toLowerCase().contains(query) ||
          sub.planName.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildStatusBadge(SubscriptionStatus status, bool isExpired) {
    Color color;
    String text;
    
    if (isExpired) {
      color = Colors.red;
      text = 'Expired';
    } else {
      switch (status) {
        case SubscriptionStatus.active:
          color = Colors.green;
          text = 'Active';
          break;
        case SubscriptionStatus.trial:
          color = Colors.blue;
          text = 'Trial';
          break;
        case SubscriptionStatus.paused:
          color = Colors.orange;
          text = 'Paused';
          break;
        case SubscriptionStatus.cancelled:
          color = Colors.grey;
          text = 'Canceled';
          break;
        default:
          color = Colors.grey;
          text = status.toString().split('.').last;
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProviderBadge(String? provider) {
    if (provider == null) {
      return const Text('-', style: TextStyle(fontSize: 12));
    }
    
    Color bgColor;
    Color textColor;
    Color borderColor;
    String label;
    
    if (provider.toLowerCase().contains('manual')) {
      bgColor = Colors.yellow.shade50;
      textColor = Colors.yellow.shade700;
      borderColor = Colors.yellow.shade300;
      label = 'Manual Admin';
    } else if (provider.toLowerCase().contains('bcl')) {
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
      borderColor = Colors.blue.shade300;
      label = 'BCL Auto';
    } else {
      bgColor = Colors.grey.shade50;
      textColor = Colors.grey.shade700;
      borderColor = Colors.grey.shade300;
      label = provider;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showFilters() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Subscriptions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                const DropdownMenuItem(value: 'active', child: Text('Active')),
                const DropdownMenuItem(value: 'trial', child: Text('Trial')),
                const DropdownMenuItem(value: 'expired', child: Text('Expired')),
                const DropdownMenuItem(value: 'paused', child: Text('Paused')),
              ],
              onChanged: (value) {
                setState(() => _selectedStatus = value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _selectedStatus = null);
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Stack(
        children: [
          Column(
            children: [
              // Header with search and activate button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by email, name, or plan...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _showActivateDialog = true),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Activate New', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Stats summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Total: ${_subscriptions.length}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Active: ${_subscriptions.where((s) => s.status == SubscriptionStatus.active && s.expiresAt.isAfter(DateTime.now())).length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Table
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredSubscriptions.isEmpty
                        ? const Center(child: Text('No subscriptions found'))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('User')),
                                        DataColumn(label: Text('Plan')),
                                        DataColumn(label: Text('Duration')),
                                        DataColumn(label: Text('Start Date')),
                                        DataColumn(label: Text('End Date')),
                                        DataColumn(label: Text('Total Paid')),
                                        DataColumn(label: Text('Source')),
                                        DataColumn(label: Text('Status')),
                                        DataColumn(label: Text('Actions')),
                                      ],
                                      rows: _filteredSubscriptions.map((sub) {
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(
                                              sub.userId.length > 20
                                                  ? '${sub.userId.substring(0, 20)}...'
                                                  : sub.userId,
                                              style: const TextStyle(fontSize: 12),
                                            )),
                                            DataCell(Text(sub.planName)),
                                            DataCell(Text('${sub.durationMonths} month${sub.durationMonths > 1 ? 's' : ''}')),
                                            DataCell(Text(DateFormat('dd MMM yyyy', 'ms').format(DateTimeHelper.toLocalTime(sub.startedAt ?? sub.createdAt)))),
                                            DataCell(Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(DateFormat('dd MMM yyyy', 'ms').format(sub.expiresAt)),
                                                if (sub.status == SubscriptionStatus.expired || sub.expiresAt.isBefore(DateTime.now()))
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 4),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        'Expired',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            )),
                                            DataCell(Text('RM ${sub.totalAmount.toStringAsFixed(2)}')),
                                            DataCell(_buildProviderBadge(sub.paymentGateway)),
                                            DataCell(_buildStatusBadge(sub.status, sub.status == SubscriptionStatus.expired || sub.expiresAt.isBefore(DateTime.now()))),
                                            DataCell(
                                              PopupMenuButton<String>(
                                                onSelected: (value) {
                                                  setState(() {
                                                    _selectedSubscription = sub;
                                                    if (value == 'extend') {
                                                      _showExtendDialog = true;
                                                    } else if (value == 'pause') {
                                                      _showPauseDialog = true;
                                                    } else if (value == 'resume') {
                                                      _handleResumeSubscription(sub);
                                                    } else if (value == 'refund') {
                                                      _loadPaymentsForRefund(sub);
                                                    }
                                                  });
                                                },
                                                itemBuilder: (context) => [
                                                  if (sub.status != SubscriptionStatus.cancelled)
                                                    const PopupMenuItem(
                                                      value: 'extend',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.schedule, size: 16),
                                                          SizedBox(width: 8),
                                                          Text('Extend'),
                                                        ],
                                                      ),
                                                    ),
                                                  if (sub.status == SubscriptionStatus.active && !sub.isPaused)
                                                    const PopupMenuItem(
                                                      value: 'pause',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.pause, size: 16, color: Colors.orange),
                                                          SizedBox(width: 8),
                                                          Text('Pause'),
                                                        ],
                                                      ),
                                                    ),
                                                  if (sub.status == SubscriptionStatus.paused || sub.isPaused)
                                                    const PopupMenuItem(
                                                      value: 'resume',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.play_arrow, size: 16, color: Colors.green),
                                                          SizedBox(width: 8),
                                                          Text('Resume'),
                                                        ],
                                                      ),
                                                    ),
                                                  const PopupMenuItem(
                                                    value: 'refund',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.undo, size: 16, color: Colors.red),
                                                        SizedBox(width: 8),
                                                        Text('Refund'),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text('Actions', style: TextStyle(fontSize: 12)),
                                                      SizedBox(width: 4),
                                                      Icon(Icons.arrow_drop_down, size: 16),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          
          // Dialogs
          if (_showActivateDialog) _buildActivateDialog(),
          if (_showExtendDialog) _buildExtendDialog(),
        ],
    );
  }

  Widget _buildActivateDialog() {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Activate Manual Subscription',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Backup method untuk activate subscription bila payment BCL tak berjaya',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              
              // User selection
              const Text('Select User', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedUserId,
                decoration: const InputDecoration(
                  hintText: 'Choose user...',
                  border: OutlineInputBorder(),
                ),
                items: _availableUsers.map((user) {
                  return DropdownMenuItem(
                    value: user['id'] as String,
                    child: Text(
                      user['email'] as String,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedUserId = value);
                },
              ),
              if (_availableUsers.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'No users found. Please load subscriptions first.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              const SizedBox(height: 16),
              
              // Plan info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plan', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('PocketBizz', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(
                      'Single plan with duration-based pricing (1, 3, 6, or 12 months)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Duration selection
              const Text('Duration Package', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _activateDuration,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '1', child: Text('1 Bulan - RM39')),
                  DropdownMenuItem(value: '3', child: Text('3 Bulan - RM117')),
                  DropdownMenuItem(value: '6', child: Text('6 Bulan - RM215 (Save 8%)')),
                  DropdownMenuItem(value: '12', child: Text('12 Bulan - RM398 (Save 15%)')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _activateDuration = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Price display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Package Price',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[900],
                      ),
                    ),
                    Text(
                      'RM ${PACKAGE_PRICES[int.parse(_activateDuration)]!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    Text(
                      'RM ${_getPerMonthRate(int.parse(_activateDuration)).toStringAsFixed(2)}/month',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                      ),
                    ),
                    if (_getDiscount(int.parse(_activateDuration)) > 0)
                      Text(
                        '💰 Save ${_getDiscount(int.parse(_activateDuration))}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Notes
              const Text('Admin Notes (Optional)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'e.g., Customer paid via bank transfer on 15/11/2025',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) => setState(() => _activateNotes = value),
              ),
              const SizedBox(height: 24),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _showActivateDialog = false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedUserId == null || _isActivating
                        ? null
                        : () => _handleActivateSubscription(),
                    child: _isActivating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Activate Subscription'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExtendDialog() {
    if (_selectedSubscription == null) return const SizedBox.shrink();
    
    final currentEnd = _selectedSubscription!.expiresAt;
    final newEnd = DateTime(
      currentEnd.year,
      currentEnd.month + int.parse(_extendDuration),
      currentEnd.day,
    );
    
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Extend Subscription',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Extend langganan untuk pelanggan yang dah bayar',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              
              // Current subscription info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('User:', _selectedSubscription!.userId.substring(0, 8) + '...'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Current Plan:', _selectedSubscription!.planName),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Current End Date:',
                      DateFormat('dd MMM yyyy', 'ms').format(currentEnd),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Duration selection
              const Text('Extension Package', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _extendDuration,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '1', child: Text('1 Bulan - RM39')),
                  DropdownMenuItem(value: '3', child: Text('3 Bulan - RM117')),
                  DropdownMenuItem(value: '6', child: Text('6 Bulan - RM215 (Save 8%)')),
                  DropdownMenuItem(value: '12', child: Text('12 Bulan - RM398 (Save 15%)')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _extendDuration = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Price display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extension Price',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[900],
                      ),
                    ),
                    Text(
                      'RM ${PACKAGE_PRICES[int.parse(_extendDuration)]!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    Text(
                      'RM ${_getPerMonthRate(int.parse(_extendDuration)).toStringAsFixed(2)}/month',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                      ),
                    ),
                    if (_getDiscount(int.parse(_extendDuration)) > 0)
                      Text(
                        '💰 Save ${_getDiscount(int.parse(_extendDuration))}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // New end date
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New End Date',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green[900],
                      ),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy', 'ms').format(newEnd),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    Text(
                      'Extended by ${_extendDuration} month${int.parse(_extendDuration) > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Notes
              const Text('Admin Notes (Optional)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'e.g., Payment received via bank transfer',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) => setState(() => _extendNotes = value),
              ),
              const SizedBox(height: 24),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showExtendDialog = false;
                        _selectedSubscription = null;
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isExtending
                        ? null
                        : () => _handleExtendSubscription(),
                    child: _isExtending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Extend Subscription'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _handleActivateSubscription() async {
    if (_selectedUserId == null || _plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user and ensure plans are loaded')),
      );
      return;
    }

    setState(() => _isActivating = true);
    try {
      final plan = _plans.first; // Use first plan (PocketBizz)
      await _service.manualActivateSubscription(
        userId: _selectedUserId!,
        planId: plan.id,
        durationMonths: int.parse(_activateDuration),
        notes: _activateNotes.isEmpty ? null : _activateNotes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Subscription activated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _showActivateDialog = false;
          _selectedUserId = null;
          _activateDuration = '3';
          _activateNotes = '';
        });
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to activate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActivating = false);
      }
    }
  }

  Future<void> _handleExtendSubscription() async {
    if (_selectedSubscription == null) return;

    setState(() => _isExtending = true);
    try {
      await _service.extendSubscription(
        subscriptionId: _selectedSubscription!.id,
        extensionMonths: int.parse(_extendDuration),
        notes: _extendNotes.isEmpty ? null : _extendNotes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Subscription extended successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _showExtendDialog = false;
          _selectedSubscription = null;
          _extendDuration = '3';
          _extendNotes = '';
        });
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to extend: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExtending = false);
      }
    }
  }

  // ============================================================================
  // PAUSE/RESUME HANDLERS
  // ============================================================================

  Widget _buildPauseDialog() {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pause Subscription',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pause subscription untuk ${_selectedSubscription?.userId.substring(0, 8)}...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Days to Pause',
                  border: OutlineInputBorder(),
                  helperText: 'Subscription expiry akan dipanjangkan dengan bilangan hari ini',
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: _pauseDays),
                onChanged: (value) => _pauseDays = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Reason (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                controller: TextEditingController(text: _pauseReason),
                onChanged: (value) => _pauseReason = value,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showPauseDialog = false;
                        _pauseDays = '7';
                        _pauseReason = '';
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isExtending ? null : _handlePauseSubscription,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Pause'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePauseSubscription() async {
    if (_selectedSubscription == null) return;

    setState(() => _isExtending = true);
    try {
      await _service.pauseSubscription(
        subscriptionId: _selectedSubscription!.id,
        daysToPause: int.parse(_pauseDays),
        reason: _pauseReason.isEmpty ? null : _pauseReason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Subscription paused successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _showPauseDialog = false;
          _selectedSubscription = null;
          _pauseDays = '7';
          _pauseReason = '';
        });
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to pause: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExtending = false);
      }
    }
  }

  Future<void> _handleResumeSubscription(Subscription subscription) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resume Subscription?'),
        content: Text('Resume subscription untuk ${subscription.userId.substring(0, 8)}...?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Resume'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isExtending = true);
    try {
      await _service.resumeSubscription(subscription.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Subscription resumed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to resume: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExtending = false);
      }
    }
  }

  // ============================================================================
  // REFUND HANDLERS
  // ============================================================================

  Future<void> _loadPaymentsForRefund(Subscription subscription) async {
    setState(() => _isLoading = true);
    try {
      // Load payments for this subscription (admin can query without user_id filter)
      final response = await supabase
          .from('subscription_payments')
          .select()
          .eq('subscription_id', subscription.id)
          .eq('status', 'completed')
          .order('created_at', ascending: false);

      final payments = (response as List)
          .map((json) => SubscriptionPayment.fromJson(json as Map<String, dynamic>))
          .where((p) => !p.hasRefund) // Only show payments that haven't been refunded
          .toList() as List<SubscriptionPayment>;

      if (mounted) {
        setState(() {
          _subscriptionPayments = payments;
          _selectedPayment = payments.isNotEmpty ? payments.first : null;
          _showRefundDialog = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading payments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildRefundDialog() {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Process Refund',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Refund untuk subscription ${_selectedSubscription?.userId.substring(0, 8)}...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              if (_subscriptionPayments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No refundable payments found'),
                )
              else ...[
                const Text(
                  'Select Payment',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<SubscriptionPayment>(
                  value: _selectedPayment,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: _subscriptionPayments.map((payment) {
                    return DropdownMenuItem(
                      value: payment,
                      child: Text(
                        'RM ${payment.amount.toStringAsFixed(2)} - ${DateFormat('dd MMM yyyy', 'ms').format(DateTimeHelper.toLocalTime(payment.paidAt ?? payment.createdAt))}',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPayment = value;
                      if (value != null) {
                        _refundAmount = value.amount.toStringAsFixed(2);
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Full Refund'),
                  value: _isFullRefund,
                  onChanged: (value) {
                    setState(() {
                      _isFullRefund = value ?? true;
                      if (_isFullRefund && _selectedPayment != null) {
                        _refundAmount = _selectedPayment!.amount.toStringAsFixed(2);
                      }
                    });
                  },
                ),
                if (!_isFullRefund) ...[
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Refund Amount (RM)',
                      border: const OutlineInputBorder(),
                      helperText: _selectedPayment != null
                          ? 'Max: RM ${_selectedPayment!.amount.toStringAsFixed(2)}'
                          : null,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    controller: TextEditingController(text: _refundAmount),
                    onChanged: (value) => _refundAmount = value,
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Refund Reason',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  controller: TextEditingController(text: _refundReason),
                  onChanged: (value) => _refundReason = value,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showRefundDialog = false;
                        _selectedPayment = null;
                        _subscriptionPayments = [];
                        _isFullRefund = true;
                        _refundAmount = '';
                        _refundReason = '';
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _subscriptionPayments.isEmpty || _isExtending
                        ? null
                        : _handleRefundPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Process Refund'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRefundPayment() async {
    if (_selectedPayment == null) return;

    final amount = double.tryParse(_refundAmount) ?? 0.0;
    if (amount <= 0 || amount > _selectedPayment!.amount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid refund amount')),
      );
      return;
    }

    setState(() => _isExtending = true);
    try {
      await _service.processRefund(
        paymentId: _selectedPayment!.id,
        refundAmount: amount,
        reason: _refundReason.isEmpty ? 'Admin refund' : _refundReason,
        fullRefund: _isFullRefund,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Refund processed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _showRefundDialog = false;
          _selectedPayment = null;
          _subscriptionPayments = [];
          _isFullRefund = true;
          _refundAmount = '';
          _refundReason = '';
        });
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to process refund: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExtending = false);
      }
    }
  }
}
