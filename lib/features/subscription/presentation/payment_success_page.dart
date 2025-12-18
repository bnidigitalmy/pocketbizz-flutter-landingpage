import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart';
import '../data/models/subscription.dart';
import '../services/subscription_service.dart';

enum _PaymentStatus { processing, success, pending, failed }

class PaymentSuccessPage extends StatefulWidget {
  const PaymentSuccessPage({super.key});

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  final SubscriptionService _subscriptionService = SubscriptionService();

  _PaymentStatus _status = _PaymentStatus.processing;
  int _countdown = 5;
  int _elapsedMs = 0;
  bool _confirming = false;
  bool _confirmationTriggered = false;
  Subscription? _active;
  bool _isLoading = true;
  bool _unauthorized = false;
  Timer? _pollTimer;
  Timer? _elapsedTimer;
  Timer? _countdownTimer;
  RealtimeChannel? _subscriptionChannel;
  RealtimeChannel? _paymentChannel;

  String? _orderNumber;
  String? _amount;
  String? _gatewayRef;
  String? _statusId;
  String? _paymentMethod;

  @override
  void initState() {
    super.initState();
    _parseQuery();
    _startElapsedTimer();
    _setupRealtimeSubscription();
    _loadInitialData();
  }

  /// Setup Supabase realtime subscription for payment status updates
  void _setupRealtimeSubscription() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || _orderNumber == null) {
      // Fallback to polling if no order number
      _pollSubscription();
      return;
    }

    try {
      // Subscribe to subscriptions table changes
      _subscriptionChannel = supabase
          .channel('subscription_payment_${_orderNumber}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'subscriptions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'payment_reference',
              value: _orderNumber,
            ),
            callback: (payload) {
              if (!mounted) return;
              _handleSubscriptionUpdate(payload.newRecord);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'subscriptions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'payment_reference',
              value: _orderNumber,
            ),
            callback: (payload) {
              if (!mounted) return;
              _handleSubscriptionUpdate(payload.newRecord);
            },
          )
          .subscribe();

      // Subscribe to subscription_payments table changes for payment method
      _paymentChannel = supabase
          .channel('payment_details_${_orderNumber}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'subscription_payments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'payment_reference',
              value: _orderNumber,
            ),
            callback: (payload) {
              if (!mounted) return;
              _handlePaymentUpdate(payload.newRecord);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'subscription_payments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'payment_reference',
              value: _orderNumber,
            ),
            callback: (payload) {
              if (!mounted) return;
              _handlePaymentUpdate(payload.newRecord);
            },
          )
          .subscribe();

      print('✅ Realtime subscription setup for payment: $_orderNumber');
    } catch (e) {
      print('⚠️ Failed to setup realtime subscription, falling back to polling: $e');
      // Fallback to polling if realtime fails
      _pollSubscription();
    }
  }

  /// Handle subscription table update from realtime
  void _handleSubscriptionUpdate(Map<String, dynamic>? newRecord) async {
    if (newRecord == null) return;

    try {
      // Check if subscription is now active
      final status = newRecord['status'] as String?;
      if (status == 'active') {
        // Fetch full subscription details
        final sub = await _subscriptionService.getCurrentSubscription();
        if (!mounted) return;
        
        setState(() {
          _active = sub;
          _isLoading = false;
          _status = _PaymentStatus.success;
        });

        // Cancel polling and start countdown
        _pollTimer?.cancel();
        _startCountdown();
      } else if (status == 'pending_payment') {
        setState(() {
          _status = _PaymentStatus.pending;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error handling subscription update: $e');
    }
  }

  /// Handle payment table update from realtime
  void _handlePaymentUpdate(Map<String, dynamic>? newRecord) {
    if (newRecord == null) return;

    final status = newRecord['status'] as String?;
    final paymentMethod = newRecord['payment_method'] as String?;

    if (!mounted) return;

    setState(() {
      if (paymentMethod != null) {
        _paymentMethod = paymentMethod;
      }
      if (status == 'completed') {
        _status = _PaymentStatus.success;
      } else if (status == 'failed') {
        _status = _PaymentStatus.failed;
      }
    });
  }

  /// Load initial subscription and payment data
  Future<void> _loadInitialData() async {
    try {
      // Load current subscription
      final sub = await _subscriptionService.getCurrentSubscription();
      if (!mounted) return;

      setState(() {
        _active = sub != null && (sub.isActive || sub.status == SubscriptionStatus.active)
            ? sub
            : null;
        _isLoading = false;
        _status = _active != null ? _PaymentStatus.success : _PaymentStatus.processing;
      });

      if (_active != null) {
        _startCountdown();
      } else if (_orderNumber != null) {
        // Load payment details to get payment method
        _loadPaymentDetails();
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401') || msg.toLowerCase().contains('unauthorized')) {
        if (!mounted) return;
        setState(() {
          _unauthorized = true;
          _isLoading = false;
          _status = _PaymentStatus.pending;
        });
      }
    }
  }

  /// Load payment details to get payment method
  Future<void> _loadPaymentDetails() async {
    final orderNumber = _orderNumber;
    if (orderNumber == null) return;

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('subscription_payments')
          .select('payment_method, status')
          .eq('payment_reference', orderNumber)
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _paymentMethod = response['payment_method'] as String?;
          final status = response['status'] as String?;
          if (status == 'completed') {
            _status = _PaymentStatus.success;
          } else if (status == 'failed') {
            _status = _PaymentStatus.failed;
          }
        });
      }
    } catch (e) {
      print('Error loading payment details: $e');
    }
  }

  void _parseQuery() {
    final params = Uri.base.queryParameters;
    _orderNumber = params['order'] ?? params['order_number'] ?? params['order_id'];
    _amount = params['amount'];
    _gatewayRef = params['refno'] ?? params['billcode'];
    _statusId = params['status_id'] ?? params['status'];

    // Map status from gateway (fallback to pending if not provided)
    switch (_statusId) {
      case '1': // success
        _status = _PaymentStatus.success;
        break;
      case '3': // failed
        _status = _PaymentStatus.failed;
        break;
      case '2': // pending
        _status = _PaymentStatus.pending;
        break;
      default:
        _status = _PaymentStatus.processing;
    }

    // Always try confirm if we have order number (handles BCL callbacks without status_id)
    if (_orderNumber != null && _status != _PaymentStatus.failed) {
      _confirmPaymentIfNeeded();
    }
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedMs += 2000;
      });
      // Stop polling after 30 seconds
      if (_elapsedMs >= 30000) {
        _elapsedTimer?.cancel();
        _pollTimer?.cancel();
        if (_active == null && !_unauthorized) {
          _navigateTo('/subscription');
        }
      }
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown <= 0) {
        timer.cancel();
        _navigateTo('/subscription');
        return;
      }
      setState(() {
        _countdown--;
      });
    });
  }

  /// Polling subscription status (every 2 seconds, stop after 30s)
  Future<void> _pollSubscription() async {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      // Stop polling after 30 seconds
      if (_elapsedMs >= 30000) {
        _pollTimer?.cancel();
        return;
      }

      try {
        final sub = await _subscriptionService.getCurrentSubscription();
        if (!mounted) return;
        setState(() {
          _active = sub != null && (sub.isActive || sub.status == SubscriptionStatus.active)
              ? sub
              : null;
          _isLoading = false;
          _status = _active != null ? _PaymentStatus.success : _PaymentStatus.processing;
        });
        if (_active != null) {
          _pollTimer?.cancel();
          _startCountdown();
        }
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('401') || msg.toLowerCase().contains('unauthorized')) {
          if (!mounted) return;
          setState(() {
            _unauthorized = true;
            _isLoading = false;
            _status = _PaymentStatus.pending;
          });
          _pollTimer?.cancel();
        }
      }
    });
  }

  Future<void> _confirmPaymentIfNeeded() async {
    if (_confirmationTriggered) return;
    if (_orderNumber == null) return;
    _confirmationTriggered = true;
    try {
      setState(() {
        _confirming = true;
      });
      await _subscriptionService.confirmPendingPayment(
        orderId: _orderNumber!,
        gatewayTransactionId: _gatewayRef,
      );
      // After confirmation, force refresh immediately
      await _pollSubscription();
    } catch (e) {
      // Ignore errors here; polling will continue or unauthorized will be handled
    } finally {
      if (mounted) {
        setState(() {
          _confirming = false;
        });
      }
    }
  }

  void _navigateTo(String route) {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();
    _countdownTimer?.cancel();
    _subscriptionChannel?.unsubscribe();
    _paymentChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _status == _PaymentStatus.failed 
                        ? Colors.red[200]! 
                        : Colors.green[200]!, 
                    width: 1,
                  ),
                ),
                color: _status == _PaymentStatus.failed 
                    ? Colors.red[50] 
                    : Colors.green[50],
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header with icon
                      _buildHeader(),
                      const SizedBox(height: 24),
                      
                      // Payment Details
                      if (_orderNumber != null || _amount != null) ...[
                        _buildPaymentDetails(),
                        const SizedBox(height: 24),
                      ],
                      
                      // Activation Status
                      _buildActivationStatus(),
                      const SizedBox(height: 24),
                      
                      // Action Buttons
                      _buildActions(),
                      const SizedBox(height: 24),
                      
                      // Help Text
                      _buildHelpText(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isFailed = _status == _PaymentStatus.failed;
    final isSuccess = _status == _PaymentStatus.success && _active != null;
    
    return Column(
      children: [
        // Icon in circular background
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isFailed ? Colors.red[100] : Colors.green[100],
            shape: BoxShape.circle,
          ),
          child: Icon(
            isFailed ? Icons.error : Icons.check_circle,
            size: 64,
            color: isFailed ? Colors.red[600] : Colors.green[600],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isFailed ? 'Pembayaran Gagal' : isSuccess ? 'Pembayaran Berjaya!' : 'Memproses Pembayaran',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isFailed ? Colors.red[900] : Colors.green[900],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isFailed 
              ? 'Pembayaran anda tidak berjaya. Sila cuba lagi.'
              : isSuccess
                  ? 'Terima kasih atas pembayaran anda'
                  : 'Sila tunggu sebentar...',
          style: TextStyle(
            fontSize: 14,
            color: isFailed ? Colors.red[700] : Colors.green[700],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPaymentDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Maklumat Pembayaran',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          if (_orderNumber != null) ...[
            _buildDetailRow('Order Number:', _orderNumber!, isMonospace: true),
            const SizedBox(height: 8),
          ],
          if (_amount != null) ...[
            _buildDetailRow('Jumlah Dibayar:', 'RM $_amount', isBold: true, isGreen: true),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, bool isGreen = false, bool isMonospace = false}) {
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isGreen ? Colors.green[600] : Colors.grey[900],
            fontFamily: isMonospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildActivationStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: _unauthorized
          ? _buildUnauthorizedState()
          : _status == _PaymentStatus.failed
              ? _buildFailedState()
              : _isLoading
                  ? _buildLoadingState()
                  : _active != null
                      ? _buildSuccessState()
                      : _buildWaitingState(),
    );
  }

  Widget _buildUnauthorizedState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sila Login Untuk Semak Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[600],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Pembayaran anda telah diterima. Sila login ke akaun anda untuk melihat status aktivasi.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _navigateTo('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Login Sekarang'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Sedang mengaktifkan akaun anda...',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 20),
            const SizedBox(width: 8),
            Text(
              'Akaun Telah Diaktifkan!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Langganan: ${_active!.planName}',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tempoh: ${_active!.durationMonths} bulan',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Redirect ke Subscription dalam $_countdown saat...',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingState() {
    final elapsedSeconds = (_elapsedMs / 1000).floor();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Menunggu pengesahan pembayaran...',
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Sistem sedang memproses pembayaran anda. Ini mungkin mengambil masa 1-2 minit.\nAkaun anda akan diaktifkan secara automatik. ($elapsedSeconds/30 saat)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildFailedState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[600], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pembayaran Tidak Berjaya',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[600],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Pembayaran anda tidak dapat diproses. Sila semak maklumat pembayaran anda atau cuba dengan kaedah pembayaran lain.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        if (_orderNumber != null) ...[
          const SizedBox(height: 8),
          Text(
            'Order Number: $_orderNumber',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontFamily: 'monospace',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions() {
    if (_unauthorized) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _navigateTo('/login'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text('Login Ke Akaun'),
        ),
      );
    }

    final isFailed = _status == _PaymentStatus.failed;
    final showSuccess = _active != null && _status == _PaymentStatus.success;
    final pollingTimedOut = _elapsedMs >= 30000 && _active == null && !isFailed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isFailed) ...[
          ElevatedButton(
            onPressed: () => _navigateTo('/subscription'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Cuba Bayar Semula'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _navigateTo('/home'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Ke Dashboard'),
          ),
        ] else ...[
          // Show manual "Check Status" button if polling timed out
          if (pollingTimedOut) ...[
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  setState(() {
                    _isLoading = true;
                  });
                  await _confirmPaymentIfNeeded();
                  await _pollSubscription();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal semak status: $e'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              },
              icon: const Icon(Icons.refresh),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              label: const Text('Semak Status Pembayaran'),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton(
            onPressed: () => _navigateTo('/subscription'),
            style: ElevatedButton.styleFrom(
              backgroundColor: showSuccess ? AppColors.primary : Colors.white,
              foregroundColor: showSuccess ? Colors.white : AppColors.primary,
              side: showSuccess ? null : BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(showSuccess ? 'Lihat Subscription' : 'Ke Halaman Subscription'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _navigateTo('/home'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Ke Dashboard'),
          ),
        ],
      ],
    );
  }

  Widget _buildHelpText() {
    final pollingTimedOut = _elapsedMs >= 30000 && _active == null && _status != _PaymentStatus.failed;
    
    return Column(
      children: [
        if (pollingTimedOut)
          Text(
            'Nota: Jika pembayaran telah dibuat tetapi status masih belum dikemaskini, sila tekan butang "Semak Status Pembayaran" di atas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange[700],
              fontWeight: FontWeight.w500,
            ),
          )
        else
          Text(
            'Jika akaun anda tidak diaktifkan dalam 5 minit, sila hubungi support.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        if (!pollingTimedOut) const SizedBox(height: 8),
        const SizedBox(height: 8),
        Text(
          'Ref: ${_orderNumber ?? 'N/A'}',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[400],
            fontFamily: 'monospace',
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
