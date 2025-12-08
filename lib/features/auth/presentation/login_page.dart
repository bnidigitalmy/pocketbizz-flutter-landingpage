import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/widgets/pocketbizz_logo.dart';
import '../../subscription/services/subscription_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Check for auth errors from URL (e.g., expired OTP links)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAuthError();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
        // Sign up
        final response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (response.user != null) {
          // Check if email confirmation is required
          if (response.session == null) {
            // Email confirmation required - user profile will be created by database trigger
            // Trial will be initialized when user confirms email and signs in
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account created! Please check your email to confirm your account, then sign in to start your free trial.'),
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
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account created! Free 7-day trial started.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );

            setState(() => _isSignUp = false);
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
          }
        }

        if (response.user != null && mounted) {
          // Navigate to home
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
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
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // PocketBizz Logo
                const PocketBizzBrand(
                  logoSize: 80,
                  textSize: 28,
                  useLogoWithText: true, // Use logowithtext.png
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp ? 'Create your account' : 'Sign in to continue',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
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
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (_isSignUp && value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Submit button
                ElevatedButton(
                  onPressed: _loading ? null : _handleAuth,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                ),
                const SizedBox(height: 8),

                // Forgot password link
                if (!_isSignUp)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/forgot-password');
                      },
                      child: const Text('Forgot Password?'),
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
                        ? 'Already have an account? Sign In'
                        : 'Don\'t have an account? Sign Up',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

