import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_theme.dart';
import 'core/supabase/supabase_client.dart';
import 'core/utils/date_time_helper.dart';
import 'core/config/env_config.dart';
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
    // Initialize locale data for date formatting (non-blocking with timeout)
    await initializeDateFormatting('ms_MY', null).timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        print('Warning: Locale initialization timeout (ms_MY)');
      },
    );
  } catch (e) {
    print('Error initializing ms_MY locale: $e');
  }
  
  // Initialize timezone data for Malaysia timezone
  DateTimeHelper.initialize();
  
  try {
    await initializeDateFormatting('en_US', null).timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        print('Warning: Locale initialization timeout (en_US)');
      },
    );
  } catch (e) {
    print('Error initializing en_US locale: $e');
  }

  // Initialize Supabase with error handling to prevent hang
  try {
    // For web builds, .env file is not available, so use fallback
    // Anon key is public by design (OAuth standard), safe to include in client
    String? supabaseUrl = dotenv.env['SUPABASE_URL'];
    String? supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    
    // Fallback for web production builds (where .env is not available)
    if (kIsWeb && (supabaseUrl == null || supabaseAnonKey == null)) {
      print('⚠️ Web build: Using production Supabase credentials');
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
    
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    ).timeout(
      const Duration(seconds: 10),
    );
  } on TimeoutException {
    print('Warning: Supabase initialization timeout - continuing anyway');
    // Continue anyway - Supabase might still work
  } catch (e) {
    print('Error initializing Supabase: $e');
    // Don't rethrow for web - allow app to continue
    // App will show error in UI if Supabase is needed
    if (!kIsWeb && e.toString().contains('CRITICAL')) {
      rethrow;
    }
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
            if (focusKey != null && focusKey.isNotEmpty) {
              return FinishedProductsFocusPage(
                focusKey: focusKey,
                focusLabel: focusLabel,
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
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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

