import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/onboarding_content.dart';
import '../../../subscription/services/subscription_service.dart';
import '../../../subscription/presentation/subscription_page.dart';

/// Complete Screen - Final screen of onboarding (Tahniah!)
class CompleteScreen extends StatefulWidget {
  final OnboardingScreenData content;
  final VoidCallback onComplete;

  const CompleteScreen({
    super.key,
    required this.content,
    required this.onComplete,
  });

  @override
  State<CompleteScreen> createState() => _CompleteScreenState();
}

class _CompleteScreenState extends State<CompleteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _hasActiveSubscription = false;
  bool _checkingSubscription = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    
    _controller.forward();
    _checkSubscription();
  }

  Future<void> _checkSubscription() async {
    try {
      final hasSubscription = await _subscriptionService.hasActiveSubscription();
      if (mounted) {
        setState(() {
          _hasActiveSubscription = hasSubscription;
          _checkingSubscription = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasActiveSubscription = false;
          _checkingSubscription = false;
        });
      }
    }
  }

  Future<void> _navigateToSubscription() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SubscriptionPage(),
      ),
    );
    // After returning from subscription page, check again
    _checkSubscription();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // Celebration icon with animation
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: widget.content.iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '🎉',
                      style: TextStyle(fontSize: 64),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Title
                Text(
                  widget.content.title,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  widget.content.subtitle,
                  style: const TextStyle(
                    fontSize: 20,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Flow summary
                if (widget.content.flowSummary != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.1),
                          AppColors.primary.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.content.flowSummary!.split('\n')[0],
                          style: const TextStyle(
                            fontSize: 24,
                            letterSpacing: 4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.content.flowSummary!.split('\n')[1],
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Completion message
                if (widget.content.completionMessage != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.content.completionMessage!,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                
                const SizedBox(height: 24),
                
                // Tips section
                if (widget.content.tipTitle != null && widget.content.tipBullets != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              widget.content.tipTitle!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...widget.content.tipBullets!.map((tip) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.check, size: 16, color: Colors.amber[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tip,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.amber[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Help section
                if (widget.content.helpText != null && widget.content.helpContact != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.content.helpText!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.phone, size: 18, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              widget.content.helpContact!,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 40),
                
                // Subscription offer card (if no subscription)
                if (!_checkingSubscription && !_hasActiveSubscription) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.15),
                          AppColors.primary.withOpacity(0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.workspace_premium,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Mula Menggunakan PocketBizz',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Langgan sekarang untuk mula menambah produk, rekod jualan, dan gunakan semua ciri.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _navigateToSubscription,
                            icon: const Icon(Icons.workspace_premium, size: 20),
                            label: const Text(
                              'Langgan Sekarang',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Primary button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onComplete,
                    icon: Icon(_hasActiveSubscription ? Icons.rocket_launch : Icons.arrow_forward),
                    label: Text(
                      _hasActiveSubscription 
                          ? widget.content.primaryButtonText 
                          : 'Teruskan ke Dashboard',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasActiveSubscription 
                          ? AppColors.primary 
                          : Colors.grey[300],
                      foregroundColor: _hasActiveSubscription 
                          ? Colors.white 
                          : Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
