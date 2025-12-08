import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart';
import '../data/models/subscription.dart';
import '../data/models/subscription_plan.dart';
import '../data/models/plan_limits.dart';
import '../services/subscription_service.dart';
import '../data/repositories/subscription_repository_supabase.dart';

/// Subscription Page
/// Manage subscription, view plans, and upgrade
class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final _subscriptionService = SubscriptionService();
  final _subscriptionRepo = SubscriptionRepositorySupabase();

  Subscription? _currentSubscription;
  List<SubscriptionPlan> _plans = [];
  PlanLimits? _planLimits;
  List<Subscription> _subscriptionHistory = [];
  bool _isEarlyAdopter = false;
  bool _loading = true;
  bool _processingPayment = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _subscriptionService.getCurrentSubscription(),
        _subscriptionService.getAvailablePlans(),
        _subscriptionService.getPlanLimits(),
        _subscriptionService.getSubscriptionHistory(),
        _subscriptionService.isEarlyAdopter(),
      ]);

      if (mounted) {
        setState(() {
          _currentSubscription = results[0] as Subscription?;
          _plans = results[1] as List<SubscriptionPlan>;
          _planLimits = results[2] as PlanLimits;
          _subscriptionHistory = results[3] as List<Subscription>;
          _isEarlyAdopter = results[4] as bool;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading subscription: $e')),
        );
      }
    }
  }

  Future<void> _handlePayment(int durationMonths) async {
    final plan = _plans.firstWhere(
      (p) => p.durationMonths == durationMonths,
      orElse: () => _plans.first,
    );

    setState(() => _processingPayment = true);

    try {
      // Get user email for payment form
      final userEmail = supabase.auth.currentUser?.email ?? '';

      // Show dialog with payment instructions
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Penting: Maklumat Pembayaran'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gunakan email yang sama semasa isi borang pembayaran:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Text(
                    userEmail,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bayaran diproses melalui BCL.my. Akaun akan aktif automatik lepas pembayaran berjaya.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _redirectToPayment(durationMonths, plan.id);
                },
                child: const Text('Teruskan ke Pembayaran'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingPayment = false);
      }
    }
  }

  Future<void> _redirectToPayment(int durationMonths, String planId) async {
    try {
      await _subscriptionService.redirectToPayment(
        durationMonths: durationMonths,
        planId: planId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open payment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Langganan'),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Langganan'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Increased bottom padding to prevent overflow
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expiring Soon Alert
              if (_currentSubscription != null && _currentSubscription!.isExpiringSoon)
                _buildExpiringSoonAlert(),

              const SizedBox(height: 16),

              // Current Plan Card
              _buildCurrentPlanCard(),

              const SizedBox(height: 24),

              // Package Selection - Show if no subscription, expired, or on trial
              if (_currentSubscription == null || 
                  _currentSubscription!.status == SubscriptionStatus.expired ||
                  _currentSubscription!.isOnTrial)
                _buildPackageSelection(),

              const SizedBox(height: 24),

              // Subscription History
              if (_subscriptionHistory.isNotEmpty) _buildSubscriptionHistory(),

              const SizedBox(height: 24),

              // Billing Information
              if (_currentSubscription != null && _currentSubscription!.status == SubscriptionStatus.active)
                _buildBillingInfo(),
              
              // Extra bottom spacing to prevent overflow
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiringSoonAlert() {
    final days = _currentSubscription!.daysRemaining;
    final isTrial = _currentSubscription!.isOnTrial;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: AppColors.warning, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTrial ? 'Trial Hampir Tamat' : 'Langganan Hampir Tamat',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isTrial
                      ? 'Trial percuma anda akan tamat dalam $days hari. Pilih pakej untuk teruskan.'
                      : 'Langganan anda akan tamat dalam $days hari. Renew sekarang.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanCard() {
    final subscription = _currentSubscription;
    final planName = subscription != null
        ? (subscription.isOnTrial ? 'Free Trial' : subscription.planName)
        : 'Tiada Langganan Aktif';
    final status = subscription?.status ?? SubscriptionStatus.expired;
    final daysRemaining = subscription?.daysRemaining ?? 0;
    
    // Get price info for display
    String? priceInfo;
    if (subscription != null && !subscription.isOnTrial) {
      final monthlyPrice = subscription.pricePerMonth;
      priceInfo = 'RM${monthlyPrice.toStringAsFixed(0)}/bulan';
      if (subscription.isEarlyAdopter) {
        priceInfo = '$priceInfo (Early Adopter)';
      }
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium, color: AppColors.primary, size: 32),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          planName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          subscription != null
                              ? subscription.isOnTrial
                                  ? 'Trial bermula ${subscription.trialStartedAt != null ? DateFormat('dd MMM yyyy', 'ms').format(subscription.trialStartedAt!) : subscription.formattedStartDate}'
                                  : priceInfo != null
                                      ? priceInfo
                                      : 'Bermula ${subscription.formattedStartDate}'
                              : 'Tiada langganan aktif',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _buildStatusBadge(status),
              ],
            ),

            const SizedBox(height: 20),

            // Progress Bar
            if (subscription != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    subscription.isOnTrial ? 'Tempoh Trial' : 'Tempoh Langganan',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    daysRemaining > 0 ? '$daysRemaining hari lagi' : 'Tamat tempoh',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  // Calculate actual trial duration
                  double progressValue = 0.0;
                  if (subscription.isOnTrial) {
                    final startDate = subscription.trialStartedAt ?? subscription.createdAt;
                    final endDate = subscription.trialEndsAt ?? subscription.expiresAt;
                    if (endDate != null) {
                      final totalDays = endDate.difference(startDate).inDays;
                      progressValue = totalDays > 0 
                          ? (daysRemaining / totalDays).clamp(0.0, 1.0)
                          : 0.0;
                    }
                  } else {
                    // For active subscription, calculate based on duration
                    final startDate = subscription.startedAt ?? subscription.createdAt;
                    final endDate = subscription.expiresAt;
                    final totalDays = endDate.difference(startDate).inDays;
                    progressValue = totalDays > 0 
                        ? (daysRemaining / totalDays).clamp(0.0, 1.0)
                        : 0.0;
                  }
                  
                  return LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      daysRemaining > 7 ? AppColors.primary : AppColors.warning,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    subscription.isOnTrial 
                        ? (subscription.trialStartedAt != null 
                            ? DateFormat('dd MMM yyyy', 'ms').format(subscription.trialStartedAt!)
                            : subscription.formattedStartDate)
                        : subscription.formattedStartDate,
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                  Text(
                    subscription.formattedEndDate,
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),

            // Plan Limits
            if (_planLimits != null) _buildPlanLimits(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(SubscriptionStatus status) {
    Color color;
    String text;

    switch (status) {
      case SubscriptionStatus.trial:
        color = AppColors.info;
        text = 'Trial';
        break;
      case SubscriptionStatus.active:
        color = AppColors.success;
        text = 'Aktif';
        break;
      case SubscriptionStatus.expired:
        color = Colors.grey;
        text = 'Tidak Aktif';
        break;
      case SubscriptionStatus.cancelled:
        color = Colors.orange;
        text = 'Dibatalkan';
        break;
      case SubscriptionStatus.pendingPayment:
        color = AppColors.warning;
        text = 'Menunggu Bayaran';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildPlanLimits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Penggunaan',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildLimitItem('Produk', _planLimits!.products)),
            const SizedBox(width: 12),
            Expanded(child: _buildLimitItem('Stok', _planLimits!.stockItems)),
            const SizedBox(width: 12),
            Expanded(child: _buildLimitItem('Transaksi', _planLimits!.transactions)),
          ],
        ),
      ],
    );
  }

  Widget _buildLimitItem(String label, LimitInfo limit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _getLimitIcon(label),
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${limit.current} / ${limit.displayMax}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: limit.usagePercentage / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            limit.usagePercentage > 80 ? AppColors.warning : AppColors.primary,
          ),
        ),
      ],
    );
  }

  IconData _getLimitIcon(String label) {
    switch (label) {
      case 'Produk':
        return Icons.inventory_2;
      case 'Stok':
        return Icons.shopping_cart;
      case 'Transaksi':
        return Icons.receipt_long;
      default:
        return Icons.info;
    }
  }

  Widget _buildPackageSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Pakej Langganan',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (_currentSubscription != null && _currentSubscription!.isOnTrial)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Trial aktif. Pilih tempoh langganan untuk teruskan selepas trial tamat.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else if (_currentSubscription == null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tiada langganan aktif. Pilih tempoh dan bayar untuk aktifkan akaun.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: _plans.map((plan) => _buildPackageCard(plan)).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: AppColors.info, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PENTING: Gunakan email yang sama (${supabase.auth.currentUser?.email ?? ''}) semasa isi borang pembayaran',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Bayaran diproses melalui BCL.my. Akaun akan aktif automatik lepas pembayaran berjaya.',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPackageCard(SubscriptionPlan plan) {
    final isCurrentPlan = _currentSubscription?.planId == plan.id &&
        _currentSubscription?.status == SubscriptionStatus.active;
    final price = _isEarlyAdopter ? plan.getPriceForEarlyAdopter() : plan.totalPrice;
    final savingsText = plan.getSavingsText();
    final pricePerMonth = price / plan.durationMonths;
    final canUpgrade = _currentSubscription == null || 
                       _currentSubscription!.isOnTrial || 
                       _currentSubscription!.status == SubscriptionStatus.expired;

    return Card(
      elevation: isCurrentPlan ? 4 : 2,
      color: isCurrentPlan ? AppColors.primary.withOpacity(0.1) : null,
      child: InkWell(
        onTap: _processingPayment || !canUpgrade || isCurrentPlan 
            ? null 
            : () => _handlePayment(plan.durationMonths),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (savingsText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    savingsText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (savingsText != null) const SizedBox(height: 8),
              Text(
                '${plan.durationMonths} Bulan',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                // Show exact price with 2 decimals if needed, otherwise whole number
                price % 1 == 0 
                    ? 'RM${price.toInt()}'
                    : 'RM${price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                // Show monthly price rounded to nearest integer
                'RM${pricePerMonth.round()}/bulan',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              if (isCurrentPlan)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Pakej Semasa',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (canUpgrade)
                ElevatedButton(
                  onPressed: _processingPayment 
                      ? null 
                      : () => _handlePayment(plan.durationMonths),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _processingPayment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Upgrade',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sejarah Langganan',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._subscriptionHistory.map((subscription) => _buildHistoryItem(subscription)),
        const SizedBox(height: 8), // Add bottom spacing to prevent overflow
      ],
    );
  }

  Widget _buildHistoryItem(Subscription subscription) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: subscription.status == SubscriptionStatus.active
                ? AppColors.success.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            subscription.status == SubscriptionStatus.active
                ? Icons.check_circle
                : Icons.history,
            color: subscription.status == SubscriptionStatus.active
                ? AppColors.success
                : Colors.grey,
          ),
        ),
        title: Text(
          subscription.planName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subscription.isOnTrial
              ? 'Trial • ${subscription.trialStartedAt != null ? DateFormat('dd MMM yyyy', 'ms').format(subscription.trialStartedAt!) : subscription.formattedStartDate} - ${subscription.formattedEndDate}'
              : '${subscription.durationMonths} bulan • ${subscription.formattedStartDate} - ${subscription.formattedEndDate}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              subscription.isOnTrial 
                  ? 'Percuma'
                  : subscription.totalAmount == 0
                      ? 'Percuma'
                      : subscription.totalAmount % 1 == 0
                          ? 'RM ${subscription.totalAmount.toInt()}'
                          : 'RM ${subscription.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            _buildStatusBadge(subscription.status),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingInfo() {
    final subscription = _currentSubscription!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Maklumat Bil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildBillingRow('Kaedah Pembayaran', subscription.paymentGateway ?? 'N/A'),
            _buildBillingRow('Penyedia Pembayaran', 'BCL.my'),
            _buildBillingRow(
              'ID Transaksi',
              subscription.paymentReference ?? 'N/A',
            ),
            _buildBillingRow(
              'Jumlah Dibayar',
              'RM ${subscription.totalAmount.toStringAsFixed(2)}',
              isAmount: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingRow(String label, String value, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isAmount ? 18 : 14,
              fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

