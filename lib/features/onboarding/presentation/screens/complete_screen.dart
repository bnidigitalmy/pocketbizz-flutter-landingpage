import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/onboarding_content.dart';

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
                
                // Primary button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onComplete,
                    icon: const Icon(Icons.rocket_launch),
                    label: Text(widget.content.primaryButtonText),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
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
