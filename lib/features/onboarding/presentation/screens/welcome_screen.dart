import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pocketbizz_logo.dart';
import '../../data/onboarding_content.dart';

/// Welcome Screen - First screen of onboarding
class WelcomeScreen extends StatelessWidget {
  final OnboardingScreenData content;
  final VoidCallback onStart;
  final VoidCallback onSkip;

  const WelcomeScreen({
    super.key,
    required this.content,
    required this.onStart,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          
          // Logo
          const PocketBizzBrand(
            logoSize: 80,
            textSize: 32,
            useLogoWithText: true,
          ),
          
          const SizedBox(height: 40),
          
          // Welcome Icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: content.iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              content.icon,
              size: 60,
              color: content.iconColor,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Title
          Text(
            '👋 ${content.title}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Subtitle
          Text(
            content.subtitle,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Bullet points
          if (content.bulletPoints != null)
            ...content.bulletPoints!.map((point) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    point,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            )),
          
          const SizedBox(height: 24),
          
          // Footer text
          if (content.footerText != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                content.footerText!,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          
          const SizedBox(height: 12),
          
          // Time estimate
          if (content.timeEstimate != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.schedule, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Anggaran: ${content.timeEstimate}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          
          const SizedBox(height: 40),
          
          // Primary button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.rocket_launch),
              label: Text(content.primaryButtonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
          
          // Skip button
          if (content.secondaryButtonText != null)
            TextButton(
              onPressed: onSkip,
              child: Text(
                content.secondaryButtonText!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
