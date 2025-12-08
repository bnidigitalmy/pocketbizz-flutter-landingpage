import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../data/models/subscription.dart';
import '../../../core/theme/app_colors.dart';
import '../presentation/subscription_page.dart';

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

    // Active paid subscription always has access
    if (subscription.status == SubscriptionStatus.active) {
      return true;
    }

    // Trial users can access if allowTrial is true
    if (subscription.status == SubscriptionStatus.trial && allowTrial) {
      return true;
    }

    return false;
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


