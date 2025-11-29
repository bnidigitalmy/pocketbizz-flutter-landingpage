import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/app_theme.dart';
import 'core/supabase/supabase_client.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/dashboard/presentation/home_page.dart';
import 'features/bookings/presentation/bookings_page.dart';
import 'features/bookings/presentation/create_booking_page.dart';
import 'features/products/presentation/product_list_page.dart';
import 'features/products/presentation/add_product_page.dart';
import 'features/sales/presentation/sales_page.dart';
import 'features/sales/presentation/create_sale_page.dart';
import 'features/stock/presentation/stock_page.dart';
import 'features/categories/presentation/categories_page.dart';
import 'features/production/presentation/record_production_page.dart';
import 'features/production/presentation/production_planning_page.dart';
import 'features/shopping/presentation/shopping_list_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize locale data for date formatting
  await initializeDateFormatting('ms_MY', null);
  await initializeDateFormatting('en_US', null);

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://gxllowlurizrkvpdircw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4bGxvd2x1cml6cmt2cGRpcmN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMTAyMDksImV4cCI6MjA3OTc4NjIwOX0.Avft6LyKGwmU8JH3hXmO7ukNBlgG1XngjBX-prObycs',
  );

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
        '/home': (context) => const HomePage(),
        '/bookings': (context) => const BookingsPage(),
        '/bookings/create': (context) => const CreateBookingPage(),
        '/products': (context) => const ProductListPage(),
        '/products/add': (context) => const AddProductPage(),
        '/sales': (context) => const SalesPage(),
        '/sales/create': (context) => const CreateSalePage(),
        '/stock': (context) => const StockPage(),
        '/categories': (context) => const CategoriesPage(),
        '/production/record': (context) => const RecordProductionPage(),
        '/production': (context) => const ProductionPlanningPage(),
        '/shopping-list': (context) => const ShoppingListPage(),
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

