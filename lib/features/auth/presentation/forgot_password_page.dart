import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pocketbizz_logo.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _emailSent = false;
  
  // Rate limiting
  DateTime? _lastRequestTime;
  int _requestCount = 0;
  static const int _maxRequestsPerHour = 3;
  static const Duration _cooldownPeriod = Duration(hours: 1);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Check if user can make another request (rate limiting)
  bool _canMakeRequest() {
    if (_lastRequestTime == null) return true;
    
    final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
    
    // Reset count if cooldown period has passed
    if (timeSinceLastRequest > _cooldownPeriod) {
      _requestCount = 0;
      return true;
    }
    
    // Check if under request limit
    return _requestCount < _maxRequestsPerHour;
  }

  /// Get remaining cooldown time
  Duration? _getRemainingCooldown() {
    if (_lastRequestTime == null) return null;
    
    final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
    if (timeSinceLastRequest > _cooldownPeriod) return null;
    
    return _cooldownPeriod - timeSinceLastRequest;
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    // Rate limiting check
    if (!_canMakeRequest()) {
      final remaining = _getRemainingCooldown();
      if (remaining != null) {
        final minutes = remaining.inMinutes;
        final seconds = remaining.inSeconds % 60;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Anda telah menghantar terlalu banyak permintaan. Sila tunggu $minutes minit $seconds saat sebelum cuba lagi.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    setState(() => _loading = true);

    try {
      // Get current URL for redirect (web only)
      String? redirectTo;
      if (kIsWeb) {
        // Use custom domain for production
        redirectTo = 'https://app.pocketbizz.my/reset-password';
      }

      await supabase.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: redirectTo, // Specify where to redirect after clicking link
      );

      // Update rate limiting
      setState(() {
        _lastRequestTime = DateTime.now();
        _requestCount++;
      });

      if (mounted) {
        setState(() => _emailSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email reset kata laluan telah dihantar! Sila semak inbox dan spam folder anda.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      // Log full error for debugging
      debugPrint('❌ Password reset error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      if (e is Exception) {
        debugPrint('❌ Exception message: ${e.toString()}');
      }
      
      // Decrement request count on error (don't count failed requests)
      setState(() {
        _requestCount = _requestCount > 0 ? _requestCount - 1 : 0;
      });

      String errorMessage = 'Ralat: Gagal menghantar email reset kata laluan.';
      String? detailedError;
      
      // Provide more specific error messages
      final errorString = e.toString().toLowerCase();
      
      // Check for specific Supabase errors
      if (errorString.contains('email') && errorString.contains('not found')) {
        // Security: Don't reveal if email exists, but show generic message
        errorMessage = 'Jika email ini berdaftar, anda akan menerima link reset kata laluan.';
      } else if (errorString.contains('rate limit') || errorString.contains('too many')) {
        errorMessage = 'Terlalu banyak permintaan. Sila cuba lagi selepas beberapa minit.';
      } else if (errorString.contains('invalid') || errorString.contains('tidak sah')) {
        errorMessage = 'Alamat email tidak sah. Sila semak dan cuba lagi.';
      } else if (errorString.contains('unexpected_failure') || 
                 (errorString.contains('error sending recovery email') && errorString.contains('500'))) {
        // Specific handling for SMTP/configuration 500 errors
        errorMessage = 'Ralat perkhidmatan email. Sila cuba lagi dalam beberapa minit.';
        detailedError = 'Server error (500). Kemungkinan: SMTP belum sync, redirect URL tidak whitelisted, atau domain belum verified. Sila check Supabase dashboard.';
      } else if (errorString.contains('smtp') || errorString.contains('email service')) {
        errorMessage = 'Perkhidmatan email tidak tersedia. Sila hubungi support.';
        detailedError = 'SMTP configuration issue - check Supabase email settings';
      } else if (errorString.contains('redirect') || errorString.contains('url')) {
        errorMessage = 'Konfigurasi redirect URL tidak sah. Sila hubungi support.';
        detailedError = 'Redirect URL configuration issue - pastikan https://app.pocketbizz.my/** whitelisted di Supabase';
      } else if (errorString.contains('network') || errorString.contains('connection')) {
        errorMessage = 'Masalah sambungan. Sila semak internet dan cuba lagi.';
      } else {
        // Show generic error but log details
        detailedError = e.toString();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage),
                if (detailedError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      detailedError,
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Copy Error',
              textColor: Colors.white,
              onPressed: () {
                // Copy error to clipboard (optional)
                debugPrint('Full error details: $e');
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const cardBg = Colors.white;
    const pageBg = Colors.white; // Match landing page background

    return Scaffold(
      backgroundColor: pageBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.brown.shade50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    const PocketBizzBrand(
                      logoSize: 56,
                      textSize: 26,
                      useLogoWithText: true,
                    ),
                    const SizedBox(height: 20),
                    
                    // Heading
                    Text(
                      'Terlupa Kata Laluan?',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    
                    // Subtitle
                    Text(
                      _emailSent
                          ? 'Sila semak email anda untuk arahan reset kata laluan. Link reset akan tamat tempoh dalam 1 jam.'
                          : 'Masukkan email anda dan kami akan hantar link untuk reset kata laluan anda.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    if (!_emailSent) ...[
                      // Email field
                      _InputField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'anda@pocketbizz.my',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Sila masukkan email';
                          }
                          if (!value.contains('@')) {
                            return 'Sila masukkan email yang sah';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Submit button
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.logoGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppColors.buttonShadow,
                        ),
                        child: ElevatedButton(
                          onPressed: _loading ? null : _sendResetEmail,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Hantar Link Reset',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ] else ...[
                      // Success state
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 64,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Email telah dihantar!',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sila semak inbox dan spam folder anda untuk link reset kata laluan.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.green.shade700,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.logoGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppColors.buttonShadow,
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Kembali ke Log Masuk',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Back to login link (only show if not email sent)
                    if (!_emailSent)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Kembali ke Log Masuk',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    const SizedBox(height: 4),

                    // Back to homepage
                    TextButton(
                      onPressed: () async {
                        final uri = Uri.parse('https://pocketbizz.my');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: const Text(
                        'Kembali ke Homepage',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: validator,
      ),
    );
  }
}

