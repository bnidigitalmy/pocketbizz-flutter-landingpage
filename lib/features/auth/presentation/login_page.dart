import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pocketbizz_logo.dart';
import '../../subscription/services/subscription_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.initialSignUp = false,
  });

  /// When true, the page opens directly in Sign Up mode (for /auth/register deep link).
  final bool initialSignUp;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  late bool _isSignUp;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Check URL to determine if we should show sign-up mode
    final uri = Uri.base;
    final path = uri.path;
    final shouldShowSignUp = widget.initialSignUp || 
        path.contains('/register') || 
        path.contains('/auth/register');
    _isSignUp = shouldShowSignUp;
    
    // Check for auth errors from URL (e.g., expired OTP links)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAuthError();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Send welcome email to new user (fire and forget)
  void _sendWelcomeEmail({required String email, required String name}) {
    // Fire and forget - don't await, don't block signup
    supabase.functions.invoke(
      'send-welcome-email',
      body: {'email': email, 'name': name},
    ).then((response) {
      if (response.status == 200) {
        debugPrint('Welcome email sent successfully');
      } else {
        debugPrint('Failed to send welcome email: ${response.status}');
      }
    }).catchError((e) {
      debugPrint('Error sending welcome email: $e');
    });
  }

  /// Handle authentication errors from URL parameters
  void _handleAuthError() {
    final uri = Uri.base;
    final error = uri.queryParameters['error'];
    final errorCode = uri.queryParameters['error_code'];
    final errorDescription = uri.queryParameters['error_description'];

    if (error != null && mounted) {
      String message = 'Authentication error occurred.';
      
      if (errorCode == 'otp_expired') {
        message = 'Email confirmation link telah tamat tempoh. Sila minta email pengesahan baru.';
      } else if (errorCode == 'access_denied') {
        message = 'Akses ditolak. Sila cuba lagi.';
      } else if (errorDescription != null) {
        message = Uri.decodeComponent(errorDescription);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 6),
          action: errorCode == 'otp_expired'
              ? SnackBarAction(
                  label: 'Daftar Semula',
                  textColor: Colors.white,
                  onPressed: () {
                    setState(() => _isSignUp = true);
                  },
                )
              : null,
        ),
      );

      // Clear URL parameters
      if (mounted) {
        final cleanUri = uri.replace(queryParameters: {});
        // Note: In web, we can't directly modify the URL without navigation
        // This is just for logging
        debugPrint('Clearing error parameters from URL');
      }
    }
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      if (_isSignUp) {
        final fullName = _nameController.text.trim();
        final phone = _phoneController.text.trim();

        // Sign up
        final response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {
            'full_name': fullName,
            if (phone.isNotEmpty) 'phone': phone,
          },
        );

        if (response.user != null) {
          // Send welcome email immediately (fire and forget)
          // This should be sent regardless of email confirmation requirement
          _sendWelcomeEmail(
            email: _emailController.text.trim(),
            name: _nameController.text.trim(),
          );

          // Check if email confirmation is required
          if (response.session == null) {
            // Email confirmation required - user profile will be created by database trigger
            // Trial will be initialized when user confirms email and signs in
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Akaun berjaya dicipta! Sila semak email anda untuk pengesahan, kemudian log masuk untuk mulakan trial percuma.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 6),
                ),
              );
              setState(() => _isSignUp = false);
            }
            return; // Exit early - user needs to confirm email first
          }

          // Session exists - user is already authenticated
          // User profile should be auto-created by database trigger
          // But we'll try to initialize trial if session exists
          try {
            final subscriptionService = SubscriptionService();
            await subscriptionService.initializeTrial();
          } catch (e) {
            // Log error but don't block registration
            debugPrint('Failed to initialize trial: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Akaun berjaya dicipta, tapi trial gagal diaktifkan. Sila log keluar & log masuk semula. ($e)'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 6),
                ),
              );
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Akaun berjaya dicipta! Trial percuma 7 hari bermula.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );

            // Navigate to home page after successful signup
            Navigator.of(context).pushReplacementNamed('/home');
          }
        }
      } else {
        // Sign in
        final response = await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Check if this is a new user who just confirmed email
        // Initialize trial if they don't have one yet
        if (response.user != null) {
          try {
            final subscriptionService = SubscriptionService();
            final hasActiveSubscription = await subscriptionService.hasActiveSubscription();
            
            // If no active subscription, initialize trial
            if (!hasActiveSubscription) {
              await subscriptionService.initializeTrial();
            }
          } catch (e) {
            // Log error but don't block sign in
            debugPrint('Failed to check/initialize trial on sign in: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Trial gagal diaktifkan. Sila cuba log keluar & log masuk semula. ($e)'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 6),
                ),
              );
            }
          }
        }

        if (response.user != null && mounted) {
          // Navigate to home
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        String errorMessage = e.message;
        // Translate common error messages to Bahasa Malaysia
        if (e.message.contains('Invalid login credentials') || 
            e.message.contains('Invalid email or password')) {
          errorMessage = 'Email atau kata laluan tidak betul. Sila cuba lagi.';
        } else if (e.message.contains('Email not confirmed')) {
          errorMessage = 'Sila semak email anda untuk pengesahan akaun.';
        } else if (e.message.contains('User already registered')) {
          errorMessage = 'Email ini sudah didaftarkan. Sila log masuk.';
        } else if (e.message.contains('Password')) {
          errorMessage = 'Kata laluan tidak memenuhi syarat. Sila cuba lagi.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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
    final badgeColor = AppColors.warning;
    final badgeBg = AppColors.warning.withOpacity(0.12);
    final cardBg = Colors.white;
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
                    const SizedBox(height: 12),
                    // Trial badge (only show in sign up mode)
                    if (_isSignUp) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Trial Percuma 7 Hari',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      _isSignUp ? 'Daftar PocketBizz' : 'Log Masuk PocketBizz',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isSignUp
                          ? 'Tiada credit card diperlukan. Setup dalam 5 minit.'
                          : 'Masukkan email dan password anda untuk log masuk.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    if (_isSignUp) ...[
                      // Full name
                      _InputField(
                        controller: _nameController,
                        label: 'Nama Penuh',
                        hint: 'Ahmad Abdullah',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Sila masukkan nama penuh';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email
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
                      const SizedBox(height: 16),

                      // Phone (optional)
                      _InputField(
                        controller: _phoneController,
                        label: 'No. Telefon (Optional)',
                        hint: '01X-XXX XXXX',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      // Email for login
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
                      const SizedBox(height: 16),
                    ],

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: _isSignUp ? 'Minima 6 aksara' : null,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Sila masukkan kata laluan';
                        }
                        if (_isSignUp && value.length < 6) {
                          return 'Minimum 6 aksara';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    if (_isSignUp) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Trial percuma termasuk:',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 10),
                            _BenefitRow(text: 'Semua features (had 10 produk)'),
                            _BenefitRow(text: 'Setup & tutorial percuma'),
                            _BenefitRow(text: 'Tiada credit card diperlukan'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Submit button
                    ElevatedButton(
                      onPressed: _loading ? null : _handleAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        shadowColor: AppColors.primary.withOpacity(0.3),
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
                          : Text(
                              _isSignUp ? 'Daftar & Mulai Trial Percuma' : 'Log Masuk',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),

                    // Forgot password link
                    if (!_isSignUp)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/forgot-password');
                          },
                          child: const Text('Terlupa kata laluan?'),
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Toggle sign up/sign in
                    TextButton(
                      onPressed: () {
                        setState(() => _isSignUp = !_isSignUp);
                      },
                      child: Text(
                        _isSignUp
                            ? 'Sudah ada akaun? Log Masuk'
                            : 'Belum ada akaun? Daftar Percuma',
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
                      child: const Text('Kembali ke Homepage'),
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

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
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

