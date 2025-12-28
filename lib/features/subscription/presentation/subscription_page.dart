/**
 * 🔒 STABLE CORE MODULE – DO NOT MODIFY
 * This file is production-tested.
 * Any changes must be isolated via extension or wrapper.
 */
// ❌ AI WARNING:
// DO NOT refactor, rename, optimize or restructure this logic.
// Only READ-ONLY reference allowed.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_helper.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/admin_helper.dart';
import '../../../core/utils/pdf_generator.dart';
import '../../../core/services/document_storage_service.dart';
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../data/models/subscription.dart';
import '../data/models/subscription_plan.dart';
import '../data/models/subscription_payment.dart';
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
  List<SubscriptionPayment> _paymentHistory = [];
  String? _retryingPaymentId;
  RealtimeChannel? _paymentChannel;
  bool _isEarlyAdopter = false;
  bool _loading = true;
  bool _processingPayment = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _paymentChannel?.unsubscribe();
    super.dispose();
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
        _subscriptionService.getPaymentHistory(),
      ]);

      if (mounted) {
        setState(() {
          _currentSubscription = results[0] as Subscription?;
          _plans = results[1] as List<SubscriptionPlan>;
          _planLimits = results[2] as PlanLimits;
          _subscriptionHistory = results[3] as List<Subscription>;
          _isEarlyAdopter = results[4] as bool;
          _paymentHistory = results[5] as List<SubscriptionPayment>;
          _loading = false;
        });

        // Subscribe to payment status changes for in-app notifications
        _paymentChannel ??= _subscriptionService.subscribePaymentNotifications((payment) {
          if (!mounted) return;
          String message;
          Color bg = AppColors.primary;
          if (payment.isCompleted) {
            message = 'Pembayaran berjaya: ${payment.formattedAmount}';
            bg = AppColors.success;
          } else if (payment.isFailed) {
            message = 'Pembayaran gagal. Sila cuba semula.';
            bg = AppColors.error;
            _subscriptionService.sendPaymentFailedEmail(payment).ignore();
          } else {
            message = 'Status pembayaran dikemas kini: ${payment.status}';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: bg,
            ),
          );
          _loadData();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          // Initialize empty lists on error to prevent crashes
          _subscriptionHistory = _subscriptionHistory.isNotEmpty ? _subscriptionHistory : [];
          _paymentHistory = _paymentHistory.isNotEmpty ? _paymentHistory : [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading subscription: $e')),
        );
        print('Error loading subscription data: $e');
      }
    }
  }

  Future<void> _handlePayment(int durationMonths, {bool isExtend = false}) async {
    final plan = _plans.firstWhere(
      (p) => p.durationMonths == durationMonths,
      orElse: () => _plans.first,
    );

    setState(() => _processingPayment = true);

    try {
      // Get user email for payment form
      final userEmail = supabase.auth.currentUser?.email ?? '';
      final remainingDays = _currentSubscription?.daysRemaining ?? 0;

      // Show dialog with payment instructions
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(isExtend ? 'Tambah Tempoh Langganan' : 'Penting: Maklumat Pembayaran'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isExtend && remainingDays > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.info),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.info, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Baki tempoh: $remainingDays hari\nTempoh baharu akan ditambah dari tarikh tamat semasa.',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
                  _redirectToPayment(durationMonths, plan.id, isExtend: isExtend);
                },
                child: Text(isExtend ? 'Teruskan Tambah Tempoh' : 'Teruskan ke Pembayaran'),
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

  Future<void> _redirectToPayment(int durationMonths, String planId, {bool isExtend = false}) async {
    try {
      await _subscriptionService.redirectToPayment(
        durationMonths: durationMonths,
        planId: planId,
        isExtend: isExtend,
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Langganan'),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
              // Grace Period Alert
              if (_currentSubscription != null && _currentSubscription!.isInGrace)
                _buildGraceAlert(),
              // Expiring Soon Alert (active/trial)
              if (_currentSubscription != null && !_currentSubscription!.isInGrace && _currentSubscription!.isExpiringSoon)
                _buildExpiringSoonAlert(),

              const SizedBox(height: 16),

              // Current Plan Card
              _buildCurrentPlanCard(),

              const SizedBox(height: 24),

              // Package Selection - Show if no subscription, expired, on trial, OR active (for extend)
              if (_currentSubscription == null || 
                  _currentSubscription!.status == SubscriptionStatus.expired ||
                  _currentSubscription!.isOnTrial ||
                  _currentSubscription!.status == SubscriptionStatus.active ||
                  _currentSubscription!.status == SubscriptionStatus.grace)
                _buildPackageSelection(),

              const SizedBox(height: 24),

              // Subscription History
              if (_subscriptionHistory.isNotEmpty) _buildSubscriptionHistory(),

              const SizedBox(height: 24),

              // Payment History
              _buildPaymentHistory(),

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

  Widget _buildGraceAlert() {
    final days = _currentSubscription!.daysRemaining;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tempoh Tangguh (Grace Period)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  days > 0
                      ? 'Akaun dalam tempoh tangguh. Lengkapkan pembayaran dalam $days hari untuk elak tamat.'
                      : 'Akaun dalam tempoh tangguh. Sila lengkapkan pembayaran segera.',
                  style: const TextStyle(fontSize: 12, height: 1.3),
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
    // Handle pending_payment status separately for clearer display
    final isPendingPayment = subscription?.status == SubscriptionStatus.pendingPayment;
    final planName = subscription != null
        ? isPendingPayment
            ? 'Menunggu Bayaran'
            : (subscription.isOnTrial ? 'Free Trial' : subscription.planName)
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
            // Header - Responsive layout for mobile
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  // Mobile: Stack vertically
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.workspace_premium, color: AppColors.primary, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  planName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subscription != null
                                      ? isPendingPayment
                                          ? 'Pakej ${subscription.planName} • Sila lengkapkan pembayaran'
                                          : subscription.isOnTrial
                                              ? 'Trial bermula ${subscription.trialStartedAt != null ? DateTimeHelper.formatDate(subscription.trialStartedAt!) : subscription.formattedStartDate}'
                                              : priceInfo != null
                                                  ? priceInfo
                                                  : 'Bermula ${subscription.formattedStartDate}'
                                      : 'Tiada langganan aktif',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _buildStatusBadge(status),
                      ),
                    ],
                  );
                } else {
                  // Desktop: Horizontal layout
                  return Row(
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
                                    ? isPendingPayment
                                        ? 'Pakej ${subscription.planName} • Sila lengkapkan pembayaran'
                                        : subscription.isOnTrial
                                            ? 'Trial bermula ${subscription.trialStartedAt != null ? DateTimeHelper.formatDate(subscription.trialStartedAt!) : subscription.formattedStartDate}'
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
                  );
                }
              },
            ),

            const SizedBox(height: 20),

            // Note: Pause/Resume and Refund features moved to Admin Dashboard
            // Regular users can contact support for subscription management requests

            const SizedBox(height: 8),

            // Pending Payment: clearer copy + continue payment CTA (avoid confusing "days remaining")
            if (subscription != null && subscription.status == SubscriptionStatus.pendingPayment) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Menunggu bayaran',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Langganan belum aktif lagi. Sila lengkapkan pembayaran melalui BCL.my. Akaun akan aktif serta-merta selepas bayaran berjaya.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: subscription.paymentReference == null
                                ? null
                                : () async {
                                    try {
                                      await _subscriptionService.openBclPaymentForm(
                                        durationMonths: subscription.durationMonths,
                                        orderId: subscription.paymentReference!,
                                        isEarlyAdopter: subscription.isEarlyAdopter,
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Gagal buka pembayaran: $e')),
                                      );
                                    }
                                  },
                            child: const Text('Teruskan Pembayaran'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: _loadData,
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ]
            // Progress Bar (Active/Trial/Grace)
            else if (subscription != null) ...[
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
                            ? DateTimeHelper.formatDate(subscription.trialStartedAt!)
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
      case SubscriptionStatus.grace:
        color = Colors.orange;
        text = 'Grace';
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
      case SubscriptionStatus.paused:
        color = Colors.blue;
        text = 'Ditangguhkan';
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
    // Check if any limit is approaching (>= 80% usage)
    final isApproachingLimit = _planLimits!.products.usagePercentage >= 80 ||
        _planLimits!.stockItems.usagePercentage >= 80 ||
        _planLimits!.transactions.usagePercentage >= 80;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Penggunaan',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // Horizontal layout untuk semua screen - lebih compact
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildLimitItem('Produk', _planLimits!.products)),
            const SizedBox(width: 8),
            Expanded(child: _buildLimitItem('Stok', _planLimits!.stockItems)),
            const SizedBox(width: 8),
            Expanded(child: _buildLimitItem('Transaksi', _planLimits!.transactions)),
          ],
        ),
        // Show warning if approaching limits
        if (isApproachingLimit && !_planLimits!.products.isUnlimited) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Penggunaan anda hampir mencapai had. Pertimbangkan untuk upgrade pakej untuk teruskan menggunakan semua ciri.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLimitItem(String label, LimitInfo limit) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getLimitIcon(label),
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${limit.current} / ${limit.displayMax}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        LinearProgressIndicator(
          value: limit.usagePercentage / 100,
          backgroundColor: Colors.grey[200],
          minHeight: 4, // Make progress bar thinner
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
    final hasPendingPayment = _currentSubscription?.status == SubscriptionStatus.pendingPayment;
    final isExtending = !hasPendingPayment &&
        _currentSubscription != null &&
        (_currentSubscription!.status == SubscriptionStatus.active ||
            _currentSubscription!.status == SubscriptionStatus.grace);
    final remainingDays = _currentSubscription?.daysRemaining ?? 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasPendingPayment
              ? 'Selesaikan Pembayaran'
              : isExtending
                  ? 'Tambah Tempoh Langganan'
                  : 'Pilih Pakej Langganan',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (hasPendingPayment) ...[
          const SizedBox(height: 8),
          Text(
            'Anda ada pembayaran belum selesai. Tekan "Teruskan Pembayaran" pada kad atas untuk sambung.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
        ],
        if (isExtending && remainingDays > 0 && _currentSubscription != null) ...[
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final currentExpiry = _currentSubscription!.expiresAt;
              final currentExpiryStr = DateTimeHelper.formatDate(currentExpiry);
              
              // Calculate example for 3 months extension
              final exampleMonths = 3;
              final exampleDays = exampleMonths * 30;
              final newExpiryExample = currentExpiry.add(Duration(days: exampleDays));
              final newExpiryStr = DateTimeHelper.formatDate(newExpiryExample);
              final totalDaysExample = remainingDays + exampleDays;
              
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.info, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Baki tempoh: $remainingDays hari',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tarikh tamat semasa: $currentExpiryStr',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tempoh baharu akan ditambah dari tarikh tamat semasa.',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Contoh: Jika extend $exampleMonths bulan ($exampleDays hari),\n'
                        'Jumlah hari baru = $remainingDays + $exampleDays = $totalDaysExample hari\n'
                        'Tarikh baru = $newExpiryStr',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.info.withOpacity(0.9),
                          height: 1.4,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.local_fire_department, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Early Bird: 100 pengguna pertama RM29/bulan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Diskaun automatik dipaparkan jika layak. Harga standard RM39/bulan.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
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
        // Grid 2x2 untuk semua screen sizes (lebih cantik dan mudah untuk comparison)
        // Adjusted childAspectRatio untuk mobile - lebih tinggi supaya button tidak tertindih
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate aspect ratio based on screen width untuk better mobile fit
            final screenWidth = constraints.maxWidth;
            // Untuk mobile (narrow screen), use taller aspect ratio
            final aspectRatio = screenWidth < 400 ? 0.65 : 0.75;
            
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: aspectRatio, // Dynamic untuk mobile
              children: _plans.map((plan) => _buildPackageCard(plan)).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PENTING: Gunakan email yang sama semasa isi borang pembayaran',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Email dengan copy button
              GestureDetector(
                onTap: () async {
                  final email = supabase.auth.currentUser?.email ?? '';
                  if (email.isNotEmpty) {
                    await Clipboard.setData(ClipboardData(text: email));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Email disalin: $email'),
                              ),
                            ],
                          ),
                          backgroundColor: AppColors.success,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          supabase.auth.currentUser?.email ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.copy,
                        color: Colors.amber.shade800,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Salin',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
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
    final hasPendingPayment = _currentSubscription?.status == SubscriptionStatus.pendingPayment;
    final canUpgrade = !hasPendingPayment &&
        (_currentSubscription == null ||
            _currentSubscription!.isOnTrial ||
            _currentSubscription!.status == SubscriptionStatus.expired);
    final isExtending = _currentSubscription != null && 
                        (_currentSubscription!.status == SubscriptionStatus.active ||
                         _currentSubscription!.status == SubscriptionStatus.grace);
    // Allow extend untuk semua plans (kecuali current plan) kalau subscription active/grace
    final canExtend = isExtending && !isCurrentPlan;
    // Untuk extend, semua plan boleh dipilih (kecuali current)
    final canSelectPlan = !hasPendingPayment && (canUpgrade || (isExtending && !isCurrentPlan));
    final isPopular = plan.durationMonths == 6;
    
    // Enhanced styling for current plan
    final cardColor = isCurrentPlan
        ? null // Use gradient instead
        : isPopular
            ? const Color(0xFFE6F4EA) // soft green for contrast
            : null;
    final borderColor = isCurrentPlan
        ? AppColors.primary
        : isPopular
            ? AppColors.primary.withOpacity(0.6)
            : Colors.grey.withOpacity(0.2);

    // Soft brown/light peach color scheme for current plan
    final lightPeach = const Color(0xFFFFE5D9); // Soft light peach
    final softBrown = const Color(0xFFE8D5C4); // Soft brown
    final borderBrown = const Color(0xFFC9A882); // Light brown for border
    final textBrown = const Color(0xFF8B6F47); // Dark brown for text
    
    return Container(
      decoration: isCurrentPlan
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  lightPeach, // Soft light peach
                  softBrown.withOpacity(0.8), // Soft brown
                  Colors.white,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderBrown, // Soft brown border
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: borderBrown.withOpacity(0.2), // Subtle shadow
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : null,
      child: Card(
        elevation: isCurrentPlan ? 0 : (isPopular ? 5 : 2), // No elevation if using container decoration
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: borderColor,
            width: isCurrentPlan ? 0 : (isPopular ? 1.4 : 1), // No border if using container decoration
          ),
        ),
        child: InkWell(
          onTap: _processingPayment || !canSelectPlan || isCurrentPlan 
            ? null 
            : () => _handlePayment(plan.durationMonths, isExtend: isExtending),
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Adjust padding untuk mobile (smaller screens)
              final isMobile = constraints.maxWidth < 200;
              final cardPadding = isMobile ? 12.0 : 16.0;
              final fontSize = isMobile ? 12.0 : 14.0;
              final priceFontSize = isMobile ? 24.0 : 28.0;
              final buttonPadding = isMobile 
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                  : const EdgeInsets.symmetric(horizontal: 20, vertical: 10);
              
              return Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isCurrentPlan)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: borderBrown, // Soft brown
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: borderBrown.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Aktif',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (isPopular)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepOrange.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Paling Popular',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 1),
                  if (savingsText != null && !isCurrentPlan)
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
                ],
              ),
              if (savingsText != null || isPopular) const SizedBox(height: 12),
                    Text(
                      '${plan.durationMonths} Bulan',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: isCurrentPlan ? textBrown : AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: isMobile ? 6 : 8),
                    Text(
                      // Always show whole number for professional display (prices are rounded)
                      'RM${price.round()}',
                      style: TextStyle(
                        fontSize: priceFontSize,
                        fontWeight: FontWeight.bold,
                        color: isCurrentPlan ? textBrown : AppColors.primary,
                      ),
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(
                      // Show monthly price rounded to nearest integer
                      'RM${pricePerMonth.round()}/bulan',
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 12,
                        color: isCurrentPlan
                            ? textBrown.withOpacity(0.8)
                            : AppColors.textSecondary,
                        fontWeight: isCurrentPlan ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    SizedBox(height: isMobile ? 4 : 6),
                    Text(
                      _isEarlyAdopter
                          ? 'Harga Early Bird aktif (RM29/bulan)'
                          : 'Early Bird: 100 pengguna pertama RM29/bulan',
                      style: TextStyle(
                        fontSize: isMobile ? 9 : 11,
                        color: _isEarlyAdopter ? AppColors.success : AppColors.textSecondary,
                        fontWeight: _isEarlyAdopter ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    // Show calculation for extend
                    if (isExtending && !isCurrentPlan && _currentSubscription != null) ...[
                      SizedBox(height: isMobile ? 6 : 8),
                      Builder(
                        builder: (context) {
                          final currentExpiry = _currentSubscription!.expiresAt;
                          final remainingDays = _currentSubscription!.daysRemaining;
                          // Calculate actual days using calendar months (not fixed 30 days)
                          final tempYear = currentExpiry.year + (currentExpiry.month + plan.durationMonths - 1) ~/ 12;
                          final tempMonth = ((currentExpiry.month + plan.durationMonths - 1) % 12) + 1;
                          final daysInNewMonth = DateTime(tempYear, tempMonth + 1, 0).day;
                          final adjustedDay = currentExpiry.day > daysInNewMonth ? daysInNewMonth : currentExpiry.day;
                          final newExpiry = DateTime(tempYear, tempMonth, adjustedDay);
                          final newDurationDays = newExpiry.difference(currentExpiry).inDays;
                          final totalDays = remainingDays + newDurationDays;
                          
                          return Container(
                            padding: EdgeInsets.all(isMobile ? 6 : 8),
                            decoration: BoxDecoration(
                              color: AppColors.info.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.info.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Tarikh baru: ${DateTimeHelper.formatDate(newExpiry)}',
                                  style: TextStyle(
                                    fontSize: isMobile ? 9 : 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.info,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: isMobile ? 1 : 2),
                                Text.rich(
                                  TextSpan(
                                    style: TextStyle(
                                      fontSize: isMobile ? 8 : 9,
                                      color: AppColors.textSecondary,
                                    ),
                                    children: [
                                      const TextSpan(text: 'Jumlah hari: '),
                                      TextSpan(text: '$remainingDays + $newDurationDays'),
                                      const TextSpan(text: '\n= '),
                                      TextSpan(
                                        text: '$totalDays hari',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    SizedBox(height: isMobile ? 8 : 12),
                    if (isCurrentPlan)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 16, 
                          vertical: isMobile ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: borderBrown, // Soft brown
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: borderBrown.withOpacity(0.3),
                              blurRadius: 6,
                              spreadRadius: 0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: isMobile ? 14 : 16,
                            ),
                            SizedBox(width: isMobile ? 4 : 6),
                            Text(
                              'Pakej Semasa',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 10 : 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (canSelectPlan)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _processingPayment 
                              ? null 
                              : () => _handlePayment(plan.durationMonths, isExtend: isExtending),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: buttonPadding,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            minimumSize: Size.zero, // Remove minimum size constraint
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce tap target
                          ),
                          child: _processingPayment
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  isExtending ? 'Tambah Tempoh' : 'Upgrade',
                                  style: TextStyle(
                                    fontSize: isMobile ? 11 : 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              );
            },
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
        isThreeLine: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subscription.isOnTrial
                  ? 'Trial • ${subscription.trialStartedAt != null ? DateTimeHelper.formatDate(subscription.trialStartedAt!) : subscription.formattedStartDate} - ${subscription.formattedEndDate}'
                  : '${subscription.durationMonths} bulan • ${subscription.formattedStartDate} - ${subscription.formattedEndDate}',
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  subscription.isOnTrial 
                      ? 'Percuma'
                      : subscription.totalAmount == 0
                          ? 'Percuma'
                          : 'RM ${subscription.totalAmount.round()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                _buildStatusBadge(subscription.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sejarah Pembayaran',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_paymentHistory.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.payment, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'Tiada sejarah pembayaran',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ..._paymentHistory.map((payment) => _buildPaymentHistoryItem(payment)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPaymentHistoryItem(SubscriptionPayment payment) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (payment.status) {
      case 'completed':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        statusText = 'Berjaya';
        break;
      case 'pending':
        statusColor = AppColors.warning;
        statusIcon = Icons.schedule;
        statusText = 'Menunggu';
        break;
      case 'failed':
        statusColor = AppColors.error;
        statusIcon = Icons.error;
        statusText = 'Gagal';
        break;
      case 'refunded':
        statusColor = Colors.orange;
        statusIcon = Icons.refresh;
        statusText = 'Dikembalikan';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
        statusText = payment.status;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 400) {
              // Mobile: Stack vertically
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    payment.formattedAmount,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            } else {
              // Desktop: Horizontal layout
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      payment.formattedAmount,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            }
          },
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              payment.formattedDate,
              style: const TextStyle(fontSize: 12),
            ),
            if (payment.paymentMethod != null) ...[
              const SizedBox(height: 2),
              Text(
                'Kaedah: ${payment.formattedPaymentMethod}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (payment.paymentReference != null) ...[
              const SizedBox(height: 2),
              Text(
                'Rujukan: ${payment.paymentReference}',
                style: const TextStyle(fontSize: 10, color: AppColors.textHint, fontFamily: 'monospace'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (payment.failureReason != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        payment.failureReason!,
                        style: TextStyle(fontSize: 11, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (payment.isFailed || payment.isPending) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: _retryingPaymentId == payment.id
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(
                    _retryingPaymentId == payment.id ? 'Menjana...' : 'Cuba Bayar Semula',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  onPressed: _retryingPaymentId == payment.id ? null : () => _handleRetryPayment(payment),
                ),
              ),
            ],
            // Note: Refund functionality moved to Admin Dashboard
            // Regular users can contact support for refund requests
            // Show refund info if already refunded
            if (payment.hasRefund) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.undo, color: Colors.orange, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Refunded: RM ${payment.refundedAmount.toStringAsFixed(2)}${payment.refundReason != null ? ' - ${payment.refundReason}' : ''}',
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        trailing: payment.isCompleted
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.receipt, color: AppColors.primary),
                tooltip: 'Resit',
                onSelected: (value) async {
                  if (value == 'generate') {
                    // Receipt not yet generated, generate on demand
                    await _generateReceiptOnDemand(payment);
                  } else if (value == 'view') {
                    // Receipt already exists - view it
                    if (payment.receiptUrl != null) {
                      _openReceipt(payment.receiptUrl!);
                    }
                  } else if (value == 'download') {
                    // Receipt already exists - download it
                    if (payment.receiptUrl != null) {
                      _downloadReceipt(payment.receiptUrl!, payment.paymentReference ?? 'receipt');
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: payment.receiptUrl != null ? 'view' : 'generate',
                    child: Row(
                      children: [
                        Icon(
                          payment.receiptUrl != null ? Icons.visibility : Icons.receipt_long,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(payment.receiptUrl != null ? 'Lihat Resit' : 'Jana Resit'),
                      ],
                    ),
                  ),
                  if (payment.receiptUrl != null)
                    const PopupMenuItem(
                      value: 'download',
                      child: Row(
                        children: [
                          Icon(Icons.download, size: 20),
                          SizedBox(width: 8),
                          Text('Muat Turun PDF'),
                        ],
                      ),
                    ),
                ],
              )
            : null,
        isThreeLine: payment.failureReason != null || payment.paymentMethod != null,
      ),
    );
  }

  Future<void> _openReceipt(String receiptUrl) async {
    try {
      final uri = Uri.parse(receiptUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka resit')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _downloadReceipt(String receiptUrl, String paymentReference) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('Memuat turun resit...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      Uint8List pdfBytes;
      
      // Try to extract storage path from URL and use Supabase Storage API
      // Format: https://[project].supabase.co/storage/v1/object/public/user-documents/[path]
      try {
        final uri = Uri.parse(receiptUrl);
        final pathSegments = uri.pathSegments;
        
        // Find 'user-documents' in path and extract everything after it
        final bucketIndex = pathSegments.indexOf('user-documents');
        if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
          final storagePath = pathSegments.sublist(bucketIndex + 1).join('/');
          
          // Use Supabase Storage API to download (handles authentication)
          pdfBytes = await supabase.storage
              .from('user-documents')
              .download(storagePath);
        } else {
          // Fallback: try direct HTTP GET with auth headers
          final accessToken = supabase.auth.currentSession?.accessToken;
          if (accessToken != null) {
            final response = await http.get(
              Uri.parse(receiptUrl),
              headers: {
                'Authorization': 'Bearer $accessToken',
              },
            );
            if (response.statusCode != 200) {
              throw Exception('Failed to download receipt: ${response.statusCode}');
            }
            pdfBytes = response.bodyBytes;
          } else {
            // Last resort: try direct HTTP GET
            final response = await http.get(Uri.parse(receiptUrl));
            if (response.statusCode != 200) {
              throw Exception('Failed to download receipt: ${response.statusCode}');
            }
            pdfBytes = response.bodyBytes;
          }
        }
      } catch (e) {
        // Fallback: try direct HTTP GET
        final response = await http.get(Uri.parse(receiptUrl));
        if (response.statusCode != 200) {
          throw Exception('Failed to download receipt: ${response.statusCode}');
        }
        pdfBytes = response.bodyBytes;
      }

      final fileName = 'resit_subscription_${paymentReference}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

      if (kIsWeb) {
        // Web: trigger download
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile: open in browser (user can download from there)
        final uri = Uri.parse(receiptUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kIsWeb ? '✅ Resit berjaya dimuat turun!' : '✅ Resit dibuka dalam browser'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal muat turun resit: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _generateReceiptOnDemand(SubscriptionPayment payment) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('Menjana resit...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Fetch subscription and plan data
      final subscription = await _subscriptionService.getCurrentSubscription();
      if (subscription == null) {
        throw Exception('Subscription not found');
      }

      // Get plan details
      final plans = await _subscriptionService.getAvailablePlans();
      final plan = plans.firstWhere(
        (p) => p.id == subscription.planId,
        orElse: () => plans.first,
      );

      // Get user info
      final user = supabase.auth.currentUser;
      final userEmail = user?.email;
      final userName = user?.userMetadata?['full_name'] as String?;

      // Generate PDF receipt (uses fixed PocketBizz/BNI Digital Enterprise info in header)
      final pdfBytes = await PDFGenerator.generateSubscriptionReceipt(
        paymentReference: payment.paymentReference ?? payment.id,
        planName: subscription.planName,
        durationMonths: subscription.durationMonths,
        amount: payment.amount,
        paidAt: payment.paidAt ?? payment.createdAt,
        paymentGateway: payment.paymentGateway,
        gatewayTransactionId: payment.gatewayTransactionId,
        userEmail: userEmail,
        userName: userName,
        isEarlyAdopter: subscription.isEarlyAdopter,
      );

      // Upload to Supabase Storage
      final fileName = 'subscription_receipt_${payment.paymentReference ?? payment.id}_${DateFormat('yyyyMMdd').format(payment.paidAt ?? payment.createdAt)}.pdf';
      final uploadResult = await DocumentStorageService.uploadDocument(
        pdfBytes: pdfBytes,
        fileName: fileName,
        documentType: 'subscription_receipt',
        relatedEntityType: 'subscription',
        relatedEntityId: payment.subscriptionId,
      );

      // Get receipt URL from upload result
      final receiptUrl = uploadResult['url'] as String?;
      if (receiptUrl == null) {
        throw Exception('Failed to get receipt URL after upload');
      }

      // Update payment record with receipt URL
      await supabase
          .from('subscription_payments')
          .update({
            'receipt_url': receiptUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', payment.id);

      // Reload payment history to get updated receipt URL
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        // Show success message with option to view/download
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Resit berjaya dijana!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: kIsWeb ? 'Muat Turun' : 'Lihat',
              textColor: Colors.white,
              onPressed: () {
                if (kIsWeb) {
                  _downloadReceipt(receiptUrl, payment.paymentReference ?? 'receipt');
                } else {
                  _openReceipt(receiptUrl);
                }
              },
            ),
          ),
        );

        // Auto-action: Download for web, open for mobile
        Future.delayed(const Duration(milliseconds: 500), () {
          if (kIsWeb) {
            // Web: Auto-download receipt
            _downloadReceipt(receiptUrl, payment.paymentReference ?? 'receipt');
          } else {
            // Mobile: Open in browser
            _openReceipt(receiptUrl);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal jana resit: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handleRetryPayment(SubscriptionPayment payment) async {
    // Payment method options (extensible)
    final methods = [
      {'code': 'bcl_my', 'label': 'BCL.my'},
    ];
    String selectedGateway = payment.paymentGateway.isNotEmpty
        ? payment.paymentGateway
        : 'bcl_my';
    final selectedLabel = (methods.firstWhere(
      (m) => m['code'] == selectedGateway,
      orElse: () => methods.first,
    )['label']) as String;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cuba Bayar Semula?'),
        content: Text(
            'Pembayaran sebelumnya gagal atau belum selesai.\nKaedah: $selectedLabel\nTeruskan untuk jana pautan pembayaran baharu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Teruskan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _retryingPaymentId = payment.id);
    try {
      await _subscriptionService.retryPayment(
        payment: payment,
        paymentGateway: selectedGateway,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pautan pembayaran baharu dibuka. Sila lengkapkan bayaran.')),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menjana pembayaran semula: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _retryingPaymentId = null);
      }
    }
  }

  Future<void> _showChangePlanDialog() async {
    if (_currentSubscription == null) return;

    final currentId = _currentSubscription!.planId;
    SubscriptionPlan? selected;
    double? amountDuePreview;
    double? creditPreview;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> _selectPlan(SubscriptionPlan plan) async {
              if (plan.id == currentId) return;
              setSheetState(() {
                selected = plan;
                amountDuePreview = null;
                creditPreview = null;
              });
              try {
                final quote = await _subscriptionService.getProrationQuote(plan.id);
                setSheetState(() {
                  amountDuePreview = quote.amountDue;
                  creditPreview = quote.creditApplied;
                });
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal kira prorata: $e')),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tukar Pelan (Prorata)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ..._plans.map((plan) {
                    final isCurrent = plan.id == currentId;
                    return Card(
                      child: ListTile(
                        title: Text(plan.name),
                        subtitle: Text('${plan.durationMonths} bulan'),
                        trailing: isCurrent
                            ? const Chip(label: Text('Semasa'))
                            : const Icon(Icons.chevron_right),
                        onTap: isCurrent ? null : () => _selectPlan(plan),
                      ),
                    );
                  }),
                  if (selected != null) ...[
                    const SizedBox(height: 12),
                    const Text('Ringkasan', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (creditPreview != null)
                      Text('Kredit baki: RM ${creditPreview!.toStringAsFixed(2)}'),
                    if (amountDuePreview != null)
                      Text(
                        amountDuePreview == 0
                            ? 'Jumlah perlu bayar: RM 0 (ditukar serta-merta)'
                            : 'Jumlah perlu bayar: RM ${amountDuePreview!.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: amountDuePreview == null
                          ? null
                          : () async {
                              Navigator.of(context).pop(true);
                              await _handleChangePlan(selected!, amountDuePreview!);
                            },
                      child: const Text('Teruskan'),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleChangePlan(SubscriptionPlan plan, double amountDuePreview) async {
    try {
      setState(() => _processingPayment = true);
      await _subscriptionService.changePlanProrated(plan.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              amountDuePreview == 0
                  ? 'Tukar pelan dijadualkan pada akhir kitaran semasa (tanpa caj).'
                  : 'Pautan pembayaran dibuka. Sila lengkapkan bayaran.',
            ),
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal tukar pelan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingPayment = false);
    }
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
              'RM ${subscription.totalAmount.round()}',
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

  Future<void> _handlePauseSubscription(Subscription subscription) async {
    int selectedDays = 30;
    final reasonController = TextEditingController();
    
    final confirm = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Pause Subscription'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pilih bilangan hari untuk pause:'),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedDays,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Days to Pause',
                  ),
                  items: [7, 14, 30, 60, 90].map((days) {
                    return DropdownMenuItem(
                      value: days,
                      child: Text('$days days'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedDays = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Reason (Optional)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop({
                'days': selectedDays,
                'reason': reasonController.text.trim(),
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('Pause'),
            ),
          ],
        ),
      ),
    );

    if (confirm == null) return;

    setState(() => _processingPayment = true);
    try {
      await _subscriptionService.pauseSubscription(
        subscriptionId: subscription.id,
        daysToPause: confirm['days'] as int,
        reason: (confirm['reason'] as String?)?.isNotEmpty == true 
            ? confirm['reason'] as String 
            : 'Admin pause',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Subscription berjaya dipause'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal pause subscription: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingPayment = false);
    }
  }

  Future<void> _handleResumeSubscription(Subscription subscription) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resume Subscription?'),
        content: const Text(
          'Subscription akan disambung semula. Tempoh yang dipanjangkan akan digunakan. Teruskan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Resume'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _processingPayment = true);
    try {
      await _subscriptionService.resumeSubscription(subscription.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Subscription berjaya disambung semula'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal resume subscription: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingPayment = false);
    }
  }

  Future<void> _handleRefundPayment(SubscriptionPayment payment) async {
    final amountController = TextEditingController(text: payment.amount.toStringAsFixed(2));
    final reasonController = TextEditingController();
    bool isFullRefund = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Process Refund'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment: ${payment.formattedAmount}'),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Full Refund'),
                  value: isFullRefund,
                  onChanged: (value) {
                    setState(() {
                      isFullRefund = value ?? true;
                      if (isFullRefund) {
                        amountController.text = payment.amount.toStringAsFixed(2);
                      }
                    });
                  },
                ),
                if (!isFullRefund) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Refund Amount (RM)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Refund Reason',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0.0;
                if (amount <= 0 || amount > payment.amount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid refund amount')),
                  );
                  return;
                }
                Navigator.of(context).pop({
                  'amount': amount,
                  'reason': reasonController.text.trim(),
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Process Refund'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    setState(() => _processingPayment = true);
    try {
      await _subscriptionService.processRefund(
        paymentId: payment.id,
        refundAmount: result['amount'] as double,
        reason: result['reason'] as String? ?? 'Admin refund',
        fullRefund: (result['amount'] as double) >= payment.amount,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Refund berjaya diproses'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal proses refund: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingPayment = false);
    }
  }
}

