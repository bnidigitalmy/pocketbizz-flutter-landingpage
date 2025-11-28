import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://gxllowlurizrkvpdircw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4bGxvd2x1cml6cmt2cGRpcmN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMTAyMDksImV4cCI6MjA3OTc4NjIwOX0.Avft6LyKGwmU8JH3hXmO7ukNBlgG1XngjBX-prObycs',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketBizz - Supabase Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TestPage(),
    );
  }
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final supabase = Supabase.instance.client;
  bool _loading = false;
  String _status = 'Ready to test';
  List<Map<String, dynamic>> _products = [];

  Future<void> _testConnection() async {
    setState(() {
      _loading = true;
      _status = 'Signing in & testing connection...';
    });

    try {
      // Sign in first (required for RLS)
      await supabase.auth.signInWithPassword(
        email: 'admin@pocketbizz.my',
        password: 'Bani@#243643',
      );

      // Test: List products
      final products = await supabase
          .from('products')
          .select()
          .limit(10);

      final userId = supabase.auth.currentUser?.id ?? 'Not authenticated';
      
      setState(() {
        _products = List<Map<String, dynamic>>.from(products);
        _status = 'Success! Signed in as admin@pocketbizz.my (ID: $userId). Found ${products.length} products';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _createTestProduct() async {
    setState(() {
      _loading = true;
      _status = 'Signing in & creating product...';
    });

    try {
      // Sign in with admin user
      await supabase.auth.signInWithPassword(
        email: 'admin@pocketbizz.my',
        password: 'Bani@#243643',
      );

      // Get authenticated user ID
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Now create product (with correct column names!)
      final newProduct = await supabase
          .from('products')
          .insert({
            'business_owner_id': userId,  // Required!
            'name': 'Test Product ${DateTime.now().millisecond}',
            'sku': 'TEST-${DateTime.now().millisecond}',
            'category': 'Test',
            'sale_price': 100.0,
            'cost_price': 50.0,
            'unit': 'pcs',
          })
          .select()
          .single();

      setState(() {
        _status = 'Success! Product created: ${newProduct['name']}';
        _loading = false;
      });

      // Refresh list
      await _testConnection();
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PocketBizz - Supabase Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      '✅ Supabase Connected',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('URL: https://gxllowlurizrkvpdircw.supabase.co'),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _testConnection,
              child: const Text('Test Connection (List Products)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : _createTestProduct,
              child: const Text('Create Test Product'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Products:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _products.isEmpty
                  ? const Center(child: Text('No products yet. Click "Test Connection" or "Create Test Product"'))
                  : ListView.builder(
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return Card(
                          child: ListTile(
                            title: Text(product['name'] ?? 'Unknown'),
                            subtitle: Text('SKU: ${product['sku']} | Price: RM${product['sale_price']} | Cost: RM${product['cost_price']}'),
                            trailing: Text(product['category'] ?? ''),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

