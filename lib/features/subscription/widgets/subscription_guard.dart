import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/subscription_service.dart';
import '../data/models/subscription.dart';
import '../../../core/theme/app_colors.dart';
import '../presentation/subscription_page.dart';
import 'upgrade_modal_enhanced.dart';

/// Subscription Guard Widget
/// Wraps content and shows upgrade prompt if subscription is not active
class SubscriptionGuard extends StatelessWidget {
  final Widget child;
  final String? featureName; // Optional: name of feature being gated
  final bool allowTrial; // Whether trial users can access (default: true)

  const SubscriptionGuard({
    super.key,
    required this.child,
    this.featureName,
    this.allowTrial = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Subscription?>(
      future: SubscriptionService().getCurrentSubscription(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final subscription = snapshot.data;
        final hasAccess = _checkAccess(subscription);

        if (hasAccess) {
          return child;
        }

        // Show upgrade prompt
        return _buildUpgradePrompt(context, subscription);
      },
    );
  }

  bool _checkAccess(Subscription? subscription) {
    if (subscription == null) return false;

    // isActive already checks trial/active/grace with time validation
    if (!subscription.isActive) return false;
    
    // If trial users not allowed for this feature, deny even if active
    if (subscription.isOnTrial && !allowTrial) return false;

    return true;
  }

  Widget _buildUpgradePrompt(BuildContext context, Subscription? subscription) {
    final isTrial = subscription?.isOnTrial ?? false;
    final daysRemaining = subscription?.daysRemaining ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.workspace_premium,
            size: 64,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            isTrial
                ? 'Trial Hampir Tamat'
                : 'Upgrade ke PocketBizz Pro',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (isTrial)
            Text(
              'Trial percuma anda akan tamat dalam $daysRemaining hari.',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            )
          else
            Text(
              'Fitur ini memerlukan langganan aktif.',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          if (featureName != null) ...[
            const SizedBox(height: 8),
            Text(
              'Fitur: $featureName',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionPage(),
                ),
              );
            },
            icon: const Icon(Icons.workspace_premium),
            label: const Text('Lihat Pakej Langganan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kembali'),
          ),
        ],
      ),
    );
  }
}

/// Simple subscription check helper
class SubscriptionHelper {
  static final _service = SubscriptionService();

  /// Check if user has active subscription (trial or paid)
  static Future<bool> hasActiveSubscription() async {
    final subscription = await _service.getCurrentSubscription();
    return subscription?.isActive ?? false;
  }

  /// Check if user is on trial
  static Future<bool> isOnTrial() async {
    final subscription = await _service.getCurrentSubscription();
    return subscription?.isOnTrial ?? false;
  }

  /// Check if subscription is expiring soon (7 days or less)
  static Future<bool> isExpiringSoon() async {
    final subscription = await _service.getCurrentSubscription();
    return subscription?.isExpiringSoon ?? false;
  }
}

/// Universal wrapper for requiring active subscription
/// PHASE: Subscriber Expired System - Soft block dengan action block message
/// 
/// 🔴 B. ACTION BLOCK MESSAGE (BILA USER KLIK BUTANG)
/// 
/// Usage:
/// ```dart
/// await requirePro(context, 'Tambah Jualan', () async {
///   // Your create/edit/delete logic here
/// });
/// ```
Future<void> requirePro(
  BuildContext context,
  String action,
  Future<void> Function() run,
) async {
  final subscription = await SubscriptionService().getCurrentSubscription();
  
  // Check if user has active subscription (includes trial, active, grace)
  if (subscription == null || !subscription.isActive) {
    // Show enhanced upgrade modal with action context
    if (context.mounted) {
      await UpgradeModalEnhanced.show(
        context,
        action: action,
        subscription: subscription,
      );
    }
    return;
  }
  
  // User has access, proceed with action
  await run();
}

/// Detect & handle backend subscription enforcement errors consistently.
///
/// This is used when the UI thinks the user can proceed (cached subscription)
/// but the backend blocks the write (eg. Postgres trigger raises P0001).
class SubscriptionEnforcement {
  static bool isSubscriptionRequiredError(Object error) {
    if (error is PostgrestException) {
      // Our DB trigger raises exception which bubbles up as PostgrestException code P0001.
      if (error.code == 'P0001') return true;
      final msg = (error.message).toLowerCase();
      if (msg.contains('subscription required')) return true;
      if (msg.contains('not active subscription')) return true;
      if (msg.contains('langganan')) return true;
    }

    final msg = error.toString().toLowerCase();
    return msg.contains('subscription required') ||
        msg.contains('not active subscription') ||
        msg.contains('p0001') ||
        // Edge Functions (OCR etc) typically surface as a string with 403 somewhere.
        msg.contains('status: 403') ||
        msg.contains('http 403') ||
        msg.contains('403') ||
        msg.contains('langganan anda telah tamat');
  }

  /// Returns true if it handled the error (showed upgrade modal).
  static Future<bool> maybePromptUpgrade(
    BuildContext context, {
    required String action,
    required Object error,
  }) async {
    if (!isSubscriptionRequiredError(error)) return false;

    final subscription = await SubscriptionService().getCurrentSubscription();
    if (!context.mounted) return true;

    await UpgradeModalEnhanced.show(
      context,
      action: action,
      subscription: subscription,
    );
    return true;
  }
}

/// Show upgrade modal for expired/no subscription users
void _showUpgradeModal(
  BuildContext context,
  String action,
  Subscription? subscription,
) {
  final isTrial = subscription?.isOnTrial ?? false;
  final daysRemaining = subscription?.daysRemaining ?? 0;
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.workspace_premium, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('Upgrade Diperlukan'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tindakan: $action',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (isTrial)
            Text(
              'Trial percuma anda akan tamat dalam $daysRemaining hari. Upgrade untuk teruskan menggunakan semua ciri.',
              style: const TextStyle(fontSize: 14),
            )
          else
            const Text(
              'Fitur ini memerlukan langganan aktif. Upgrade sekarang untuk akses penuh.',
              style: TextStyle(fontSize: 14),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SubscriptionPage(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Lihat Pakej'),
        ),
      ],
    ),
  );
}


