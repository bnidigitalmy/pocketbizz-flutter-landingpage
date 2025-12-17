import '../../core/supabase/supabase_client.dart';
import '../models/community_link.dart';

/// Community Links Repository
class CommunityLinksRepositorySupabase {
  /// Get all active community links
  Future<List<CommunityLink>> getActiveLinks() async {
    final response = await supabase
        .from('community_links')
        .select()
        .eq('is_active', true)
        .order('display_order', ascending: true)
        .order('created_at', ascending: true);

    final data = (response as List).cast<Map<String, dynamic>>();
    return data.map(CommunityLink.fromJson).toList();
  }

  /// Get all community links (admin only)
  Future<List<CommunityLink>> getAllLinks() async {
    final response = await supabase
        .from('community_links')
        .select()
        .order('display_order', ascending: true)
        .order('created_at', ascending: true);

    final data = (response as List).cast<Map<String, dynamic>>();
    return data.map(CommunityLink.fromJson).toList();
  }

  /// Create community link (admin only)
  Future<CommunityLink> createLink({
    required String platform,
    required String name,
    required String url,
    String? description,
    String? icon,
    int displayOrder = 0,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    final payload = {
      'business_owner_id': userId,
      'platform': platform,
      'name': name,
      'url': url,
      'description': description,
      'icon': icon,
      'display_order': displayOrder,
      'is_active': true,
    };

    final response = await supabase
        .from('community_links')
        .insert(payload)
        .select()
        .single();

    return CommunityLink.fromJson(response as Map<String, dynamic>);
  }

  /// Update community link (admin only)
  Future<CommunityLink> updateLink({
    required String id,
    String? platform,
    String? name,
    String? url,
    String? description,
    String? icon,
    int? displayOrder,
    bool? isActive,
  }) async {
    final updateData = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (platform != null) updateData['platform'] = platform;
    if (name != null) updateData['name'] = name;
    if (url != null) updateData['url'] = url;
    if (description != null) updateData['description'] = description;
    if (icon != null) updateData['icon'] = icon;
    if (displayOrder != null) updateData['display_order'] = displayOrder;
    if (isActive != null) updateData['is_active'] = isActive;

    final response = await supabase
        .from('community_links')
        .update(updateData)
        .eq('id', id)
        .select()
        .single();

    return CommunityLink.fromJson(response as Map<String, dynamic>);
  }

  /// Delete community link (admin only)
  Future<void> deleteLink(String id) async {
    await supabase.from('community_links').delete().eq('id', id);
  }
}

