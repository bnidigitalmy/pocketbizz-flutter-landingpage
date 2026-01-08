import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pocketbizz_logo.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _hasValidSession = false;
  bool _isChecking = true; // Track if we're still checking session/URL params
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to ensure URL is fully loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSessionAndUrlParams();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Check if user has valid recovery session and handle URL parameters
  void _checkSessionAndUrlParams() async {
    // Check for URL parameters (expired token, errors, etc.)
    // Supabase uses hash fragments (#access_token=...&type=recovery) OR code parameter for password recovery
    final uri = Uri.base;
    final error = uri.queryParameters['error'];
    final errorCode = uri.queryParameters['error_code'];
    final errorDescription = uri.queryParameters['error_description'];
    
    // Check query parameters
    String? type = uri.queryParameters['type'];
    String? accessToken = uri.queryParameters['access_token'];
    String? refreshToken = uri.queryParameters['refresh_token'];
    String? code = uri.queryParameters['code']; // NEW: Supabase uses 'code' parameter for password recovery
    
    // Check hash fragment (Supabase preference for password recovery)
    if (uri.hasFragment) {
      final fragment = uri.fragment;
      final fragmentParams = Uri.splitQueryString(fragment);
      type = type ?? fragmentParams['type'];
      accessToken = accessToken ?? fragmentParams['access_token'];
      refreshToken = refreshToken ?? fragmentParams['refresh_token'];
      code = code ?? fragmentParams['code']; // Check for 'code' in hash fragment too
      
      // Also check for errors in hash fragment
      if (error == null) {
        final hashError = fragmentParams['error'];
        final hashErrorCode = fragmentParams['error_code'];
        final hashErrorDescription = fragmentParams['error_description'];
        if (hashError != null) {
          // Handle errors from hash fragment
          if (hashErrorCode == 'token_expired' || hashErrorCode == 'expired_token') {
            setState(() {
              _errorMessage = 'Link reset kata laluan telah tamat tempoh. Sila minta link baru.';
            });
            return;
          } else if (hashErrorDescription != null) {
            setState(() {
              _errorMessage = Uri.decodeComponent(hashErrorDescription);
            });
            return;
          }
        }
      }
    }

    debugPrint('🔐 Reset Password Page - type=$type, hasAccessToken=${accessToken != null}, hasRefreshToken=${refreshToken != null}, hasCode=${code != null}, path=${uri.path}, hasFragment=${uri.hasFragment}');

    // First, handle any errors from URL parameters
    if (error != null) {
      // Handle expired token or other errors
      if (errorCode == 'token_expired' || errorCode == 'expired_token') {
        if (mounted) {
          setState(() {
            _errorMessage = 'Link reset kata laluan telah tamat tempoh. Sila minta link baru.';
            _hasValidSession = false;
            _isChecking = false; // Done checking
          });
        }
        return;
      } else if (errorDescription != null) {
        if (mounted) {
          setState(() {
            _errorMessage = Uri.decodeComponent(errorDescription);
            _hasValidSession = false;
            _isChecking = false; // Done checking
          });
        }
        return;
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Ralat berlaku. Sila cuba lagi.';
            _hasValidSession = false;
            _isChecking = false; // Done checking
          });
        }
        return;
      }
    }

    // Check if user already has a valid recovery session
    final existingSession = supabase.auth.currentSession;
    if (existingSession != null) {
      debugPrint('✅ Recovery session already exists - user can reset password');
      if (mounted) {
        setState(() {
          _hasValidSession = true;
          _isChecking = false; // Done checking
          _errorMessage = null; // Clear any error if session exists
        });
      }
      return;
    }

    // If we have recovery code or tokens in URL, Supabase should establish session automatically
    // But we need to wait a bit for Supabase to process the code/tokens
    final hasRecoveryIndicators = code != null || 
                                   type == 'recovery' || 
                                   accessToken != null || 
                                   refreshToken != null;

    if (hasRecoveryIndicators) {
      debugPrint('🔐 Password recovery indicators detected in URL - waiting for session...');
      
      // If we have a 'code' parameter or recovery tokens, Supabase will exchange them for a session automatically
      // We just need to wait for Supabase to process it
      // Try multiple times to get session (Supabase may need time to process)
      for (int i = 0; i < 10; i++) { // Increased attempts for code/token exchange
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Check if session is now established
        final session = supabase.auth.currentSession;
        if (session != null) {
          debugPrint('✅ Recovery session established after ${i + 1} attempts');
          if (mounted) {
            setState(() {
              _hasValidSession = true;
              _isChecking = false; // Done checking
              _errorMessage = null; // Clear any error
            });
          }
          return;
        }
        
        // Log progress
        if (i % 2 == 0) {
          debugPrint('⏳ Waiting for session... attempt ${i + 1}/10');
        }
      }
      
      // After all retries, check session one final time
      final finalSession = supabase.auth.currentSession;
      if (finalSession != null) {
        debugPrint('✅ Recovery session established on final check');
        if (mounted) {
          setState(() {
            _hasValidSession = true;
            _isChecking = false; // Done checking
            _errorMessage = null;
          });
        }
        return;
      }
      
      // No session established - show error
      debugPrint('⚠️ Recovery session not established after waiting - code/tokens may be invalid or expired');
      if (mounted) {
        setState(() {
          _hasValidSession = false;
          _isChecking = false; // Done checking
          _errorMessage = 'Link reset kata laluan tidak sah atau telah tamat tempoh. Sila minta link baru.';
        });
      }
    } else {
      // No recovery indicators and no session - user needs to use email link
      debugPrint('⚠️ No recovery indicators in URL and no session - user needs email link');
      if (mounted) {
        setState(() {
          _hasValidSession = false;
          _isChecking = false; // Done checking
          _errorMessage = 'Sila gunakan link reset kata laluan dari email anda untuk menetapkan kata laluan baharu.';
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kata laluan tidak sepadan'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Re-check session before reset
    final session = supabase.auth.currentSession;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sila gunakan link reset kata laluan dari email anda untuk menetapkan kata laluan baharu.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Minta Link Baru',
            textColor: Colors.white,
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/forgot-password');
            },
          ),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // Update password - Supabase Flutter updateUser
      final response = await supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      
      if (response.user == null) {
        throw Exception('Gagal menetapkan kata laluan baharu');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kata laluan berjaya ditetapkan semula! Anda boleh log masuk sekarang.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        // Small delay to show success message
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    } catch (e) {
      debugPrint('❌ Password reset error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      
      String errorMessage = 'Ralat: Gagal menetapkan kata laluan baharu.';
      
      // Check for Supabase AuthException first (most specific)
      if (e is AuthException) {
        final authError = e.message?.toLowerCase() ?? '';
        final statusCode = e.statusCode;
        
        debugPrint('❌ AuthException - message: ${e.message}, status: $statusCode');
        
        // Check if password sama dengan password lama
        // Supabase typically returns: "New password should be different from the old password."
        // or status 422 with similar message
        if (authError.contains('new password') && authError.contains('different')) {
          errorMessage = 'Kata laluan baharu mesti berbeza dari kata laluan lama anda. Sila pilih kata laluan yang berlainan.';
        } else if (authError.contains('same password') || authError.contains('identical')) {
          errorMessage = 'Kata laluan baharu mesti berbeza dari kata laluan lama anda. Sila pilih kata laluan yang berlainan.';
        } else if (statusCode == 422 && authError.contains('password')) {
          // 422 Unprocessable Entity often means password validation failed
          if (authError.contains('different') || authError.contains('same')) {
            errorMessage = 'Kata laluan baharu mesti berbeza dari kata laluan lama anda. Sila pilih kata laluan yang berlainan.';
          }
        }
      }
      
      // Fallback: Check error string for all error types
      if (errorMessage == 'Ralat: Gagal menetapkan kata laluan baharu.') {
        final errorString = e.toString().toLowerCase();
        
        // Check if password sama dengan password lama (various error formats)
        if (errorString.contains('new password should be different') || 
            errorString.contains('new_password should be different') ||
            errorString.contains('password must be different') ||
            errorString.contains('password sama') ||
            errorString.contains('same password') ||
            errorString.contains('identical password') ||
            errorString.contains('password tidak boleh sama') ||
            errorString.contains('password baru mesti berbeza')) {
          errorMessage = 'Kata laluan baharu mesti berbeza dari kata laluan lama anda. Sila pilih kata laluan yang berlainan.';
        } else if (errorString.contains('expired') || errorString.contains('tamat')) {
          errorMessage = 'Link reset kata laluan telah tamat tempoh. Sila minta link baru.';
        } else if (errorString.contains('invalid') || errorString.contains('tidak sah')) {
          errorMessage = 'Link reset kata laluan tidak sah. Sila minta link baru.';
        } else if (errorString.contains('session') || errorString.contains('sesi')) {
          errorMessage = 'Sesi telah tamat tempoh. Sila gunakan link reset kata laluan dari email anda.';
        } else if (errorString.contains('weak') || errorString.contains('lemah')) {
          errorMessage = 'Kata laluan terlalu lemah. Sila pilih kata laluan yang lebih kuat.';
        } else if (errorString.contains('minimum') || errorString.contains('length') || errorString.contains('pendek')) {
          errorMessage = 'Kata laluan terlalu pendek. Sila pilih kata laluan dengan sekurang-kurangnya 6 aksara.';
        }
      }

      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Minta Link Baru',
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/forgot-password');
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
    // Show loading state while checking session/URL params
    if (_isChecking) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false, // Remove back button
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PocketBizzBrand(
                logoSize: 56,
                textSize: 26,
                useLogoWithText: true,
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Menyediakan halaman reset kata laluan...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Show error state if no valid session or error message exists
    if (!_hasValidSession || _errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false, // Remove back button
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PocketBizzBrand(
                  logoSize: 56,
                  textSize: 26,
                  useLogoWithText: true,
                ),
                const SizedBox(height: 32),
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  'Link Tidak Sah atau Tamat Tempoh',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    _errorMessage ?? 'Sila gunakan link reset kata laluan dari email anda untuk menetapkan kata laluan baharu.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.orange.shade900,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/forgot-password');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text(
                    'Minta Link Reset Baru',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  child: const Text(
                    'Kembali ke Log Masuk',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Normal reset password form
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PocketBizzBrand(
                  logoSize: 56,
                  textSize: 26,
                  useLogoWithText: true,
                ),
                const SizedBox(height: 32),
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Tetapkan Kata Laluan Baharu',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Masukkan kata laluan baharu anda di bawah',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // New Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Kata Laluan Baharu',
                    hintText: 'Minimum 6 aksara',
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Sila masukkan kata laluan baharu';
                    }
                    if (value.length < 6) {
                      return 'Kata laluan mesti sekurang-kurangnya 6 aksara';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Sahkan Kata Laluan Baharu',
                    hintText: 'Masukkan semula kata laluan',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Sila sahkan kata laluan anda';
                    }
                    if (value != _passwordController.text) {
                      return 'Kata laluan tidak sepadan';
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
                    onPressed: _loading ? null : _resetPassword,
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
                            'Tetapkan Kata Laluan',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Back to login
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  child: const Text(
                    'Kembali ke Log Masuk',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
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

