import 'package:flutter/material.dart';
import 'core/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  // TODO: Replace with your actual Supabase credentials
  await SupabaseConfig.initialize(
    url: 'YOUR_SUPABASE_URL', // e.g., https://xxxxx.supabase.co
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  runApp(const PocketBizzApp());
}

class PocketBizzApp extends StatelessWidget {
  const PocketBizzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketBizz',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // Check if user is authenticated
    if (SupabaseConfig.isAuthenticated) {
      // Navigate to home
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // Navigate to login
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

