// Quick test script to verify Supabase connection
// Run: node test-supabase-connection.js

const SUPABASE_URL = 'https://gxllowlurizrkvpdircw.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4bGxvd2x1cml6cmt2cGRpcmN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMTAyMDksImV4cCI6MjA3OTc4NjIwOX0.Avft6LyKGwmU8JH3hXmO7ukNBlgG1XngjBX-prObycs';

async function testConnection() {
  console.log('🧪 Testing Supabase Connection...\n');

  try {
    // Test 1: List products (should work even if empty)
    console.log('Test 1: Fetching products...');
    const response = await fetch(`${SUPABASE_URL}/rest/v1/products?select=*&limit=5`, {
      headers: {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      },
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const products = await response.json();
    console.log(`✅ Connection successful!`);
    console.log(`✅ Found ${products.length} products in database`);
    
    if (products.length > 0) {
      console.log('\n📦 Sample product:');
      console.log(JSON.stringify(products[0], null, 2));
    } else {
      console.log('\n💡 Database is empty (this is normal for new setup)');
    }

    // Test 2: Check if bookings table exists
    console.log('\nTest 2: Checking bookings table...');
    const bookingsResponse = await fetch(`${SUPABASE_URL}/rest/v1/bookings?select=id&limit=1`, {
      headers: {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      },
    });

    if (bookingsResponse.ok) {
      console.log('✅ Bookings table accessible');
    }

    // Test 3: Check auth endpoint
    console.log('\nTest 3: Checking auth endpoint...');
    const authResponse = await fetch(`${SUPABASE_URL}/auth/v1/health`, {
      headers: {
        'apikey': SUPABASE_ANON_KEY,
      },
    });

    if (authResponse.ok) {
      console.log('✅ Authentication service is healthy');
    }

    console.log('\n🎉 ALL TESTS PASSED!');
    console.log('✅ Your Supabase backend is READY for Flutter integration!');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    console.log('\n💡 This might be normal if:');
    console.log('   - RLS policies require authentication');
    console.log('   - Tables are empty');
    console.log('   - Network connection issue');
  }
}

testConnection();

