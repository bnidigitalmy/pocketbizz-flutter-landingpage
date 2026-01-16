import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/onboarding_content.dart';

/// Step Screen - Reusable for steps 1-4 of onboarding
class StepScreen extends StatelessWidget {
  final OnboardingScreenData content;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;
  final VoidCallback onBack;

  const StepScreen({
    super.key,
    required this.content,
    required this.onPrimary,
    required this.onSecondary,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step header
          if (content.stepNumber != null && content.stepTotal != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: content.iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'LANGKAH ${content.stepNumber}/${content.stepTotal}',
                  style: TextStyle(
                    color: content.iconColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          
          const SizedBox(height: 24),
          
          // Icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: content.iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                content.icon,
                size: 56,
                color: content.iconColor,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Title
          Center(
            child: Text(
              content.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Subtitle
          Center(
            child: Text(
              content.subtitle,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Bullet points
          if (content.bulletPoints != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: content.bulletPoints!.map((point) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: content.iconColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          point,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
          
          // Example section
          if (content.exampleTitle != null && content.exampleContent != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.exampleTitle!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content.exampleContent!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.6,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Tip section
          if (content.tipTitle != null && content.tipContent != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content.tipTitle!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          content.tipContent!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.amber[900],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 32),
          
          // Primary button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPrimary,
              icon: Icon(_getButtonIcon()),
              label: Text(content.primaryButtonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: content.iconColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Secondary button
          if (content.secondaryButtonText != null)
            Center(
              child: TextButton.icon(
                onPressed: onSecondary,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(content.secondaryButtonText!),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  IconData _getButtonIcon() {
    switch (content.stepNumber) {
      case 1:
        return Icons.inventory_2;
      case 2:
        return Icons.cake;
      case 3:
        return Icons.factory;
      case 4:
        return Icons.point_of_sale;
      default:
        return Icons.arrow_forward;
    }
  }
}
