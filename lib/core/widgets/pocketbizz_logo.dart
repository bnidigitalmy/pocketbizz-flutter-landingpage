import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// PocketBizz Official Logo Widget
/// Displays the PocketBizz logo image
class PocketBizzLogo extends StatelessWidget {
  const PocketBizzLogo({
    super.key,
    this.size = 48,
    this.showText = true,
    this.textStyle,
  });

  final double size;
  final bool showText;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo Image - Use transparent logo for better appearance
        Image.asset(
          'assets/images/transparentlogo2.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to other transparent logo
            return Image.asset(
              'assets/images/transparentlogo.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to regular logo
                return Image.asset(
                  'assets/images/logo.png',
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Final fallback to gradient icon
                    return Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        gradient: AppColors.logoGradient,
                        borderRadius: BorderRadius.circular(size * 0.25),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha((255 * 0.3).round()),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: size * 0.6,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
        if (showText) ...[
          const SizedBox(width: 12),
          Text(
            'PocketBizz',
            style: textStyle ??
                TextStyle(
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
          ),
        ],
      ],
    );
  }
}

/// PocketBizz Logo with Text (Full Brand)
class PocketBizzBrand extends StatelessWidget {
  const PocketBizzBrand({
    super.key,
    this.logoSize = 64,
    this.textSize,
    this.alignment = MainAxisAlignment.center,
    this.useLogoWithText = false,
  });

  final double logoSize;
  final double? textSize;
  final MainAxisAlignment alignment;
  final bool useLogoWithText; // Use logowithtext.png if true

  @override
  Widget build(BuildContext context) {
    // If useLogoWithText is true, use the combined logo+text image
    if (useLogoWithText) {
      return Image.asset(
        'assets/images/Logowithtext1024x512edited.png',
        width: logoSize * 2.5, // Adjust width for logo with text (2:1 aspect ratio)
        height: logoSize,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to other logo files if main one not found
          return Image.asset(
            'assets/images/logowithtext.png',
            width: logoSize * 2.5,
            height: logoSize,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Final fallback to separate logo + text
              return _buildSeparateLogoAndText();
            },
          );
        },
      );
    }

    // Default: Separate logo and text
    return _buildSeparateLogoAndText();
  }

  Widget _buildSeparateLogoAndText() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo Image - Use transparent logo for better appearance
        Image.asset(
          'assets/images/transparentlogo2.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to other transparent logo
            return Image.asset(
              'assets/images/transparentlogo.png',
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to regular logo
                return Image.asset(
                  'assets/images/logo.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Final fallback to gradient icon
                    return Container(
                      width: logoSize,
                      height: logoSize,
                      decoration: BoxDecoration(
                        gradient: AppColors.logoGradient,
                        borderRadius: BorderRadius.circular(logoSize * 0.25),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha((255 * 0.3).round()),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: logoSize * 0.6,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
        // Brand Text
        Text(
          'PocketBizz',
          style: TextStyle(
            fontSize: textSize ?? logoSize * 0.5,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

