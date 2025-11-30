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
      throw Exception('Failed to save business profile: $e');
    }
  }
}

