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
    // For web builds, .env file is not available, so use fallback
    // Anon key is public by design (OAuth standard), safe to include in client
    String? supabaseUrl = dotenv.env['SUPABASE_URL'];
    String? supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    
    // Fallback for web production builds (where .env is not available)
    if (kIsWeb && (supabaseUrl == null || supabaseAnonKey == null)) {
      debugPrint('⚠️ Web build: Using production Supabase credentials');
      supabaseUrl = supabaseUrl ?? 'https://gxllowlurizrkvpdircw.supabase.co';
      supabaseAnonKey = supabaseAnonKey ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4bGxvd2x1cml6cmt2cGRpcmN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMTAyMDksImV4cCI6MjA3OTc4NjIwOX0.Avft6LyKGwmU8JH3hXmO7ukNBlgG1XngjBX-prObycs';
    }
    
    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception(
        '❌ CRITICAL: Missing required environment variables!\n'
        'Please create a .env file with:\n'
        '  SUPABASE_URL=your_supabase_url\n'
        '  SUPABASE_ANON_KEY=your_supabase_anon_key\n'
        '\n'
        'For production web builds, credentials are embedded in code.\n'
        'For local development, use .env file.'
      );
    }
    
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
        '/reports': (context) => const ReportsPage(),
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
    // Check for PWA updates on app start (non-blocking)
    // Delay to ensure Supabase is initialized and context is ready
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        try {
          // Ensure Supabase is initialized before checking updates
          // PWA update check doesn't need Supabase, but delay ensures app is ready
          print('🔄 PWA Update: Checking for updates...');
          PWAUpdateNotifier.checkForUpdate(context);
        } catch (e) {
          // Silently fail - PWA update check is non-critical
          print('PWA Update: Failed to check for updates: $e');
        }
      }
    });
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

        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          return const HomePage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

