import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/app_theme.dart';
import 'core/supabase/supabase_client.dart';
import 'core/utils/date_time_helper.dart';
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
import 'features/products/presentation/test_image_upload_page.dart';
import 'features/planner/presentation/planner_page.dart';
import 'features/planner/presentation/enhanced_planner_page.dart';
import 'features/reports/presentation/reports_page.dart';
import 'features/drive_sync/presentation/drive_sync_page.dart';
import 'features/documents/presentation/documents_page.dart';
import 'features/subscription/presentation/subscription_page.dart';
import 'features/subscription/presentation/payment_success_page.dart';
import 'features/subscription/presentation/admin/widgets/admin_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    await Supabase.initialize(
      url: 'https://gxllowlurizrkvpdircw.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4bGxvd2x1cml6cmt2cGRpcmN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMTAyMDksImV4cCI6MjA3OTc4NjIwOX0.Avft6LyKGwmU8JH3hXmO7ukNBlgG1XngjBX-prObycs',
    ).timeout(
      const Duration(seconds: 10),
    );
  } on TimeoutException {
    print('Warning: Supabase initialization timeout - continuing anyway');
    // Continue anyway - Supabase might still work
  } catch (e) {
    print('Error initializing Supabase: $e');
    // Continue anyway - app should still load
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
        '/finished-products': (context) => const FinishedProductsPage(),
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

