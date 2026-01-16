import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_theme.dart';
import 'core/supabase/supabase_client.dart';
import 'core/utils/date_time_helper.dart';
import 'core/config/env_config.dart';
import 'core/utils/pwa_update_notifier.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/forgot_password_page.dart';
import 'features/auth/presentation/reset_password_page.dart';
import 'features/dashboard/presentation/home_page.dart';
import 'features/bookings/presentation/bookings_page_optimized.dart';
import 'features/bookings/presentation/create_booking_page_enhanced.dart';
import 'features/products/presentation/product_list_page.dart';
import 'features/products/presentation/add_product_page.dart';
import 'features/products/presentation/add_product_with_recipe_page.dart';
import 'features/sales/presentation/sales_page.dart';
import 'features/sales/presentation/create_sale_page_enhanced.dart';
import 'features/stock/presentation/stock_page.dart';
import 'features/categories/presentation/categories_page.dart';
import 'features/production/presentation/record_production_page.dart';
import 'features/production/presentation/production_planning_page.dart';
import 'features/shopping/presentation/shopping_list_page.dart';
import 'features/purchase_orders/presentation/purchase_orders_page.dart';
import 'features/deliveries/presentation/deliveries_page.dart';
import 'features/claims/presentation/claims_page.dart';
import 'features/claims/presentation/create_consignment_claim_page.dart';
import 'features/claims/presentation/create_claim_simplified_page.dart';
import 'features/claims/presentation/create_consignment_payment_page.dart';
import 'features/claims/presentation/create_payment_simplified_page.dart';
import 'features/claims/presentation/record_payment_page.dart';
import 'features/claims/presentation/claim_detail_page.dart';
import 'features/settings/presentation/settings_page.dart';
import 'features/suppliers/presentation/suppliers_page.dart';
import 'features/expenses/presentation/expenses_page.dart';
import 'features/finished_products/presentation/finished_products_page.dart';
import 'features/finished_products/presentation/finished_products_page_focus.dart';
import 'features/products/presentation/test_image_upload_page.dart';
import 'features/planner/presentation/planner_page.dart';
import 'features/planner/presentation/enhanced_planner_page.dart';
import 'features/reports/presentation/reports_page.dart';
import 'features/subscription/widgets/subscription_guard.dart';
import 'features/drive_sync/presentation/drive_sync_page.dart';
import 'features/documents/presentation/documents_page.dart';
import 'features/subscription/presentation/subscription_page.dart';
import 'features/subscription/presentation/payment_success_page.dart';
import 'features/subscription/presentation/admin/widgets/admin_layout.dart';
import 'features/feedback/presentation/submit_feedback_page.dart';
import 'features/feedback/presentation/my_feedback_page.dart';
import 'features/feedback/presentation/community_page.dart';
import 'features/feedback/presentation/admin/admin_feedback_page.dart';
import 'features/announcements/presentation/notifications_page.dart';
import 'features/announcements/presentation/admin/admin_announcements_page.dart';
import 'features/recipe_documents/presentation/pages/recipe_documents_page.dart';
import 'features/onboarding/presentation/onboarding_page.dart';
import 'features/onboarding/services/onboarding_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await EnvConfig.load();
  } catch (e) {
    print('Warning: Could not load environment variables: $e');
  }

  try {
    // Initialize locale data for date formatting (non-blocking with shorter timeout)
    await initializeDateFormatting('ms_MY', null).timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        print('Warning: Locale initialization timeout (ms_MY)');
      },
    );
  } catch (e) {
    print('Error initializing ms_MY locale: $e');
  }
  
  // Initialize timezone data for Malaysia timezone
  DateTimeHelper.initialize();
  
  // Initialize en_US locale in background; don't block app startup
  // This is mainly for some reports/exports and can be loaded lazily.
  unawaited(Future<void>(() async {
    try {
      await initializeDateFormatting('en_US', null).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          print('Warning: Locale initialization timeout (en_US, background)');
        },
      );
    } catch (e) {
      print('Error initializing en_US locale (background): $e');
    }
  }));

  // Initialize Supabase with error handling to prevent hang
  bool supabaseInitialized = false;
  
  try {
    // Use EnvConfig which handles --dart-define, .env, and fallback automatically
    // Priority: --dart-define > .env file > fallback (hardcoded)
    final supabaseUrl = EnvConfig.supabaseUrl;
    final supabaseAnonKey = EnvConfig.supabaseAnonKey;
    
    debugPrint('✅ Supabase URL: ${supabaseUrl.substring(0, 30)}...');
    debugPrint('✅ Using EnvConfig (supports --dart-define for web)');
    
    // Initialize Supabase with timeout
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      ).timeout(
        const Duration(seconds: 10),
      );
    } on TimeoutException {
      debugPrint('⚠️ Supabase initialization timeout - checking status');
      // Continue to check if it initialized anyway
    } catch (e) {
      debugPrint('⚠️ Supabase initialization error: $e');
      // Continue to check if it initialized anyway
    }
    
    // Verify initialization succeeded (with retry for web)
    int retries = 0;
    while (!Supabase.instance.isInitialized && retries < 3) {
      await Future.delayed(const Duration(milliseconds: 500));
      retries++;
    }
    
    if (Supabase.instance.isInitialized) {
      supabaseInitialized = true;
      debugPrint('✅ Supabase initialized successfully');
    } else {
      throw Exception('Supabase initialization failed - instance not initialized after retries');
    }
  } catch (e) {
    // Check if it's actually initialized despite the error
    if (Supabase.instance.isInitialized) {
      supabaseInitialized = true;
      debugPrint('⚠️ Supabase initialized despite error: $e');
    } else {
      debugPrint('❌ Error initializing Supabase: $e');
      // For web, allow app to continue - it will handle gracefully
      if (!kIsWeb) {
        // For non-web, only throw if it's a critical error
        if (e.toString().contains('CRITICAL')) {
          rethrow;
        }
        // Otherwise, log and continue - app will show error in UI
        debugPrint('⚠️ Supabase not initialized - app will show loading state');
      } else {
        debugPrint('⚠️ Supabase not initialized on web - app will show loading state');
      }
    }
  }
  
  // Final check - log status
  if (!supabaseInitialized && !Supabase.instance.isInitialized) {
    debugPrint('⚠️ WARNING: Supabase not initialized - some features may not work');
  }

  runApp(
    const ProviderScope(
      child: PocketBizzApp(),
    ),
  );
}

class PocketBizzApp extends StatelessWidget {
  const PocketBizzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketBizz',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      
      // EasyLocalization automatically injects delegates from wrapper
      
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/auth/login': (context) => const LoginPage(),
        '/register': (context) => const LoginPage(initialSignUp: true),
        '/auth/register': (context) => const LoginPage(initialSignUp: true),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/reset-password': (context) => const ResetPasswordPage(),
        '/home': (context) => const HomePage(),
        '/bookings': (context) => const BookingsPageOptimized(),
        '/bookings/create': (context) => const CreateBookingPageEnhanced(),
        '/products': (context) => const ProductListPage(),
        '/products/add': (context) => const AddProductPage(),
        '/products/create': (context) => const AddProductWithRecipePage(),
        '/sales': (context) => const SalesPage(),
        '/sales/create': (context) => const CreateSalePageEnhanced(),
        '/stock': (context) => const StockPage(),
        '/categories': (context) => const CategoriesPage(),
        '/production/record': (context) => const RecordProductionPage(),
        '/production': (context) => const ProductionPlanningPage(),
        '/shopping-list': (context) => const ShoppingListPage(),
        '/purchase-orders': (context) => const PurchaseOrdersPage(),
        '/deliveries': (context) => const DeliveriesPage(),
        '/claims': (context) => const ClaimsPage(),
        '/claims/create': (context) => const CreateClaimSimplifiedPage(), // New simplified flow
        '/claims/create-old': (context) => const CreateConsignmentClaimPage(), // Keep old for reference
        '/claims/detail': (context) {
          final claimId = ModalRoute.of(context)!.settings.arguments as String;
          return ClaimDetailPage(claimId: claimId);
        },
        '/payments/record': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return RecordPaymentPage(
            initialVendorId: args?['vendorId'] as String?,
            initialClaimId: args?['claimId'] as String?,
          ); // New simple payment recording flow
        },
        '/payments/create': (context) => const CreatePaymentSimplifiedPage(), // Old simplified flow (for reference)
        '/payments/create-old': (context) => const CreateConsignmentPaymentPage(), // Keep old for reference
        '/settings': (context) => const SettingsPage(),
        '/suppliers': (context) => const SuppliersPage(),
        '/expenses': (context) => const ExpensesPage(),
        '/finished-products': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map) {
            final focusKey = (args['focusKey'] as String?)?.trim();
            final focusLabel = (args['focusLabel'] as String?)?.trim();
            final focusColorValue = args['focusColorValue'] as int?;
            if (focusKey != null && focusKey.isNotEmpty) {
              return FinishedProductsFocusPage(
                focusKey: focusKey,
                focusLabel: focusLabel,
                focusAccent: focusColorValue != null ? Color(focusColorValue) : null,
              );
            }
          }
          return const FinishedProductsPage();
        },
        '/test-upload': (context) => const TestImageUploadPage(),
        '/planner': (context) => const EnhancedPlannerPage(),
        '/planner/old': (context) => const PlannerPage(), // Keep old for reference
        '/reports': (context) => SubscriptionGuard(
          featureName: 'Laporan & Analitik',
          allowTrial: true,
          child: const ReportsPage(),
        ),
        '/drive-sync': (context) => const DriveSyncPage(),
        '/documents': (context) => const DocumentsPage(),
        '/subscription': (context) => const SubscriptionPage(),
        '/payment-success': (context) => const PaymentSuccessPage(),
        '/admin/dashboard': (context) => const AdminLayout(initialRoute: '/admin/dashboard'),
        '/admin/subscriptions': (context) => const AdminLayout(initialRoute: '/admin/subscriptions'),
        '/admin/users': (context) => const AdminLayout(initialRoute: '/admin/users'),
        '/feedback/submit': (context) => const SubmitFeedbackPage(),
        '/feedback/my': (context) => const MyFeedbackPage(),
        // Use static community page (never empty) for end users.
        '/community': (context) => const CommunityPage(),
        '/admin/feedback': (context) => const AdminFeedbackPage(),
        '/notifications': (context) => const NotificationsPage(),
        '/admin/announcements': (context) => const AdminAnnouncementsPage(),
        '/recipe-documents': (context) => const RecipeDocumentsPage(),
      },
    );
  }
}

/// Wrapper to check authentication status
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Note: PWA update checking will be initialized only when user is authenticated
    // See build() method where we check for session before initializing
  }

  @override
  void dispose() {
    // Clean up PWA update checking resources
    PWAUpdateNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if Supabase is initialized before accessing auth stream
    if (!Supabase.instance.isInitialized) {
      // Show loading while Supabase initializes
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Handle errors gracefully
        if (snapshot.hasError) {
          debugPrint('Auth state error: ${snapshot.error}');
          // Show login page on error (user can retry)
          return const LoginPage();
        }

        final authState = snapshot.data;
        final session = authState?.session;
        final event = authState?.event;

        // Handle password recovery deep link FIRST (before session check)
        // Supabase uses hash fragments (#access_token=...&type=recovery) for password recovery
        // Check both query parameters and hash fragments
        final uri = Uri.base;
        
        // Check query parameters
        final type = uri.queryParameters['type'];
        final accessToken = uri.queryParameters['access_token'];
        final refreshToken = uri.queryParameters['refresh_token'];
        final code = uri.queryParameters['code']; // Supabase uses 'code' parameter for password recovery
        
        // Check hash fragment (Supabase uses this for password recovery)
        String? hashType;
        String? hashAccessToken;
        String? hashRefreshToken;
        String? hashCode;
        
        if (uri.hasFragment) {
          final fragment = uri.fragment;
          final fragmentParams = Uri.splitQueryString(fragment);
          hashType = fragmentParams['type'];
          hashAccessToken = fragmentParams['access_token'];
          hashRefreshToken = fragmentParams['refresh_token'];
          hashCode = fragmentParams['code'];
        }
        
        // Use hash fragment values if available (Supabase preference), otherwise use query params
        final recoveryType = hashType ?? type;
        final recoveryAccessToken = hashAccessToken ?? accessToken;
        final recoveryRefreshToken = hashRefreshToken ?? refreshToken;
        final recoveryCode = hashCode ?? code; // Check for 'code' parameter (new Supabase flow)
        
        debugPrint('🔐 Auth check - type=$recoveryType, hasAccessToken=${recoveryAccessToken != null}, hasCode=${recoveryCode != null}, event=$event, path=${uri.path}');
        
        // Check for password recovery in multiple ways:
        // 1. PASSWORD_RECOVERY event from onAuthStateChange
        // 2. type=recovery in URL (query params or hash fragment)
        // 3. access_token present with type=recovery
        // 4. code parameter present (new Supabase password recovery flow)
        // 5. URL path contains /reset-password (in case already navigated)
        final isPasswordRecovery = event == AuthChangeEvent.passwordRecovery || 
                                   recoveryType == 'recovery' ||
                                   (recoveryAccessToken != null && recoveryType == 'recovery') ||
                                   recoveryCode != null || // NEW: Check for 'code' parameter
                                   uri.path.contains('/reset-password');

        // CRITICAL: Handle recovery BEFORE session check to prevent auto-login to dashboard
        // This handles both /reset-password path AND root path with recovery tokens
        if (isPasswordRecovery && (recoveryType == 'recovery' || recoveryAccessToken != null || recoveryCode != null)) {
          debugPrint('🔐 Password recovery detected (type=$recoveryType, event=$event, hasSession=${session != null}, path=${uri.path})');
          
          // If already on reset password page, just render it (no need to navigate)
          if (uri.path.contains('/reset-password')) {
            debugPrint('🔐 Already on reset password page, rendering directly');
            return const ResetPasswordPage();
          }
          
          // CRITICAL: If user lands on root path (/) with recovery tokens, navigate to reset password IMMEDIATELY
          // This handles Supabase redirect_to=https://app.pocketbizz.my/ (root) case
          if (uri.path == '/' || uri.path.isEmpty) {
            debugPrint('🔐 Recovery tokens detected on root path - navigating to reset password immediately');
            // Navigate immediately without waiting for session
            Future.microtask(() {
              if (mounted) {
                // Preserve recovery tokens in URL when navigating
                Navigator.of(context).pushReplacementNamed('/reset-password');
              }
            });
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Menyediakan halaman reset kata laluan...'),
                  ],
                ),
              ),
            );
          }
          
          // If we have recovery code or tokens but no session yet, wait a bit for Supabase to establish session
          if (session == null && (recoveryAccessToken != null || recoveryRefreshToken != null || recoveryCode != null)) {
            debugPrint('⏳ Waiting for recovery session to be established from tokens...');
            // Show loading and wait for session, then navigate
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                debugPrint('🔐 Navigating to reset password page after session wait');
                Navigator.of(context).pushReplacementNamed('/reset-password');
              }
            });
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Menyediakan halaman reset kata laluan...'),
                  ],
                ),
              ),
            );
          }
          
          // Navigate to reset password page IMMEDIATELY (even if session exists, we need to reset password)
          // Use immediate navigation instead of postFrameCallback to prevent race condition
          debugPrint('🔐 Navigating to reset password page immediately');
          Future.microtask(() {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/reset-password');
            }
          });
          
          // Show loading while navigating
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Menyediakan halaman reset kata laluan...'),
                ],
              ),
            ),
          );
        }

        // Regular session check - if session exists and NOT recovery, go to home
        // IMPORTANT: Only check session AFTER recovery check to prevent auto-login during recovery
        if (session != null) {
          // Initialize PWA update checking only for authenticated users
          // Delay to ensure context is ready and user is fully authenticated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                try {
                  print('🔄 PWA Update: Initializing update checking for authenticated user...');
                  PWAUpdateNotifier.initialize(context);
                } catch (e) {
                  // Silently fail - PWA update check is non-critical
                  print('PWA Update: Failed to initialize update checking: $e');
                }
              }
            });
          });
          // Final safety check: if URL still has recovery indicators, force reset password page
          final currentUri = Uri.base;
          final currentType = currentUri.queryParameters['type'];
          String? currentHashType;
          if (currentUri.hasFragment) {
            final fragmentParams = Uri.splitQueryString(currentUri.fragment);
            currentHashType = fragmentParams['type'];
          }
          
          // Check for recovery indicators: type=recovery, code parameter, or /reset-password path
          final currentCode = currentUri.queryParameters['code'];
          String? currentHashCode;
          if (currentUri.hasFragment) {
            final fragmentParams = Uri.splitQueryString(currentUri.fragment);
            currentHashCode = fragmentParams['code'];
          }
          
          if (currentType == 'recovery' || currentHashType == 'recovery' || 
              currentCode != null || currentHashCode != null || 
              currentUri.path.contains('/reset-password')) {
            // Still in recovery flow, show reset password page
            debugPrint('🔐 Session exists but recovery indicators detected (type=$currentType, code=${currentCode ?? currentHashCode}) - showing reset password page');
            return const ResetPasswordPage();
          }
          
          // Normal authenticated user - check onboarding first
          return const _AuthenticatedUserWrapper();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

/// Wrapper for authenticated users - checks onboarding status
class _AuthenticatedUserWrapper extends StatefulWidget {
  const _AuthenticatedUserWrapper();

  @override
  State<_AuthenticatedUserWrapper> createState() => _AuthenticatedUserWrapperState();
}

class _AuthenticatedUserWrapperState extends State<_AuthenticatedUserWrapper> {
  final OnboardingService _onboardingService = OnboardingService();
  bool _loading = true;
  bool _shouldShowOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    try {
      final shouldShow = await _onboardingService.shouldShowOnboarding();
      if (mounted) {
        setState(() {
          _shouldShowOnboarding = shouldShow;
          _loading = false;
        });
      }
    } catch (e) {
      // On error, skip onboarding and go to home
      debugPrint('Error checking onboarding: $e');
      if (mounted) {
        setState(() {
          _shouldShowOnboarding = false;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_shouldShowOnboarding) {
      return const OnboardingPage();
    }

    return const HomePage();
  }
}
