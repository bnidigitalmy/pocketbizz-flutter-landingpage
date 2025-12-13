import '../../core/supabase/supabase_client.dart';
import '../models/business_profile.dart';

/// Business Profile Repository using Supabase
class BusinessProfileRepository {
  /// Get business profile for current user
  Future<BusinessProfile?> getBusinessProfile() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('business_profile')
          .select()
          .eq('business_owner_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return BusinessProfile.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch business profile: $e');
    }
  }

  /// Ensure user exists in users table (for existing users who signed up before trigger was created)
  Future<void> _ensureUserExists(String userId) async {
    try {
      // Check if user exists in users table
      final userCheck = await supabase
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      // If user doesn't exist, create it
      if (userCheck == null) {
        final authUser = supabase.auth.currentUser;
        if (authUser == null) return;

        await supabase.from('users').insert({
          'id': userId,
          'email': authUser.email ?? '',
          'full_name': authUser.userMetadata?['full_name'] ?? 
                      authUser.userMetadata?['name'] ?? 
                      authUser.email?.split('@')[0] ?? 
                      'User',
        }).onConflict('id').doNothing();
      }
    } catch (e) {
      // Log error but don't throw - this is a best-effort operation
      print('Warning: Failed to ensure user exists: $e');
    }
  }

  /// Create or update business profile
  Future<BusinessProfile> saveBusinessProfile({
    required String businessName,
    String? tagline,
    String? registrationNumber,
    String? address,
    String? phone,
    String? email,
    String? bankName,
    String? accountNumber,
    String? accountName,
    String? paymentQrCode,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Ensure user exists in users table before saving business profile
      await _ensureUserExists(userId);

      // Check if profile exists
      final existing = await getBusinessProfile();

      final data = {
        'business_owner_id': userId,
        'business_name': businessName,
        'tagline': tagline,
        'registration_number': registrationNumber,
        'address': address,
        'phone': phone,
        'email': email,
        'bank_name': bankName,
        'account_number': accountNumber,
        'account_name': accountName,
        'payment_qr_code': paymentQrCode,
      };

      Map<String, dynamic> response;

      if (existing != null) {
        // Update existing profile
        response = await supabase
            .from('business_profile')
            .update(data)
            .eq('business_owner_id', userId)
            .select()
            .single();
      } else {
        // Create new profile
        response = await supabase
            .from('business_profile')
            .insert(data)
            .select()
            .single();
      }

      return BusinessProfile.fromJson(response);
    } catch (e) {
      // Provide more specific error messages
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('foreign key constraint') || 
          errorString.contains('business_profile_business_owner_id_fkey')) {
        throw Exception(
          'User account not properly set up. Please try logging out and logging back in, or contact support.'
        );
      }
      
      if (errorString.contains('unique constraint') || 
          errorString.contains('409') ||
          errorString.contains('duplicate')) {
        // If we get a unique constraint error, try to update instead
        try {
          final response = await supabase
              .from('business_profile')
              .update(data)
              .eq('business_owner_id', userId)
              .select()
              .single();
          return BusinessProfile.fromJson(response);
        } catch (retryError) {
          throw Exception('Failed to save business profile: $retryError');
        }
      }
      
      throw Exception('Failed to save business profile: $e');
    }
  }
}

