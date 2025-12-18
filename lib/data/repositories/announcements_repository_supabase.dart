import '../../core/supabase/supabase_client.dart';
import '../models/announcement.dart';
import '../models/announcement_media.dart';

/// Announcements Repository for managing broadcast messages
class AnnouncementsRepositorySupabase {
  /// Get active announcements for current user
  /// Filters by target audience and excludes viewed announcements
  Future<List<Announcement>> getActiveAnnouncements({
    String? subscriptionStatus, // 'trial', 'active', 'expired', 'grace'
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // Determine target audience based on subscription status
    final targetAudiences = ['all'];
    if (subscriptionStatus != null) {
      targetAudiences.add(subscriptionStatus);
    }

    // Get active announcements that match target audience
    final now = DateTime.now().toIso8601String();
    var query = supabase
        .from('announcements')
        .select()
        .eq('is_active', true);
    
    // Filter by target audience - if 'all' is included, show all, otherwise filter
    if (!targetAudiences.contains('all') && targetAudiences.length > 1) {
      // Build OR filter for multiple target audiences
      final orConditions = targetAudiences
          .map((audience) => 'target_audience.eq.$audience')
          .join(',');
      query = query.or(orConditions);
    } else if (!targetAudiences.contains('all') && targetAudiences.length == 1) {
      // Single target audience
      query = query.eq('target_audience', targetAudiences.first);
    }
    // If 'all' is included, no filter needed
    
    final response = await query
        .or('show_until.is.null,show_until.gt.$now')
        .order('created_at', ascending: false);

    final data = (response as List).cast<Map<String, dynamic>>();
    
    // Get all viewed announcement IDs for this user
    final viewsResponse = await supabase
        .from('announcement_views')
        .select('announcement_id')
        .eq('user_id', userId);
    
    final viewedIds = (viewsResponse as List)
        .map((v) => v['announcement_id'] as String)
        .toSet();
    
    // Filter out viewed announcements and map to model
    return data
        .where((json) => !viewedIds.contains(json['id'] as String))
        .map((json) {
          final announcementJson = Map<String, dynamic>.from(json);
          announcementJson['is_viewed'] = false;
          return Announcement.fromJson(announcementJson);
        })
        .toList();
  }

  /// Get all announcements (admin only)
  Future<List<Announcement>> getAllAnnouncements({
    bool? isActive,
    String? type,
  }) async {
    var query = supabase.from('announcements').select();

    if (isActive != null) {
      query = query.eq('is_active', isActive);
    }
    if (type != null) {
      query = query.eq('type', type);
    }

    final response = await query.order('created_at', ascending: false);
    final data = (response as List).cast<Map<String, dynamic>>();
    return data.map(Announcement.fromJson).toList();
  }

  /// Create new announcement (admin only)
  Future<Announcement> createAnnouncement({
    required String title,
    required String message,
    String type = 'info',
    String priority = 'normal',
    String targetAudience = 'all',
    bool isActive = true,
    DateTime? showUntil,
    String? actionUrl,
    String? actionLabel,
    List<AnnouncementMedia>? media,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    final payload = {
      'title': title,
      'message': message,
      'type': type,
      'priority': priority,
      'target_audience': targetAudience,
      'is_active': isActive,
      'created_by': userId,
      if (showUntil != null) 'show_until': showUntil.toIso8601String(),
      if (actionUrl != null) 'action_url': actionUrl,
      if (actionLabel != null) 'action_label': actionLabel,
      'media': media != null
          ? media.map((m) => m.toJson()).toList()
          : [],
    };

    final response = await supabase
        .from('announcements')
        .insert(payload)
        .select()
        .single();

    final announcement = Announcement.fromJson(response as Map<String, dynamic>);

    // Broadcast notification to all target users
    await _broadcastNotification(announcement);

    return announcement;
  }

  /// Update announcement (admin only)
  Future<Announcement> updateAnnouncement({
    required String id,
    String? title,
    String? message,
    String? type,
    String? priority,
    String? targetAudience,
    bool? isActive,
    DateTime? showUntil,
    String? actionUrl,
    String? actionLabel,
    List<AnnouncementMedia>? media,
  }) async {
    final updateData = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (title != null) updateData['title'] = title;
    if (message != null) updateData['message'] = message;
    if (type != null) updateData['type'] = type;
    if (priority != null) updateData['priority'] = priority;
    if (targetAudience != null) updateData['target_audience'] = targetAudience;
    if (isActive != null) updateData['is_active'] = isActive;
    if (showUntil != null) {
      updateData['show_until'] = showUntil.toIso8601String();
    } else if (showUntil == null && updateData.containsKey('show_until')) {
      updateData['show_until'] = null;
    }
    if (actionUrl != null) updateData['action_url'] = actionUrl;
    if (actionLabel != null) updateData['action_label'] = actionLabel;
    if (media != null) {
      updateData['media'] = media.map((m) => m.toJson()).toList();
    }

    final response = await supabase
        .from('announcements')
        .update(updateData)
        .eq('id', id)
        .select()
        .single();

    return Announcement.fromJson(response as Map<String, dynamic>);
  }

  /// Delete announcement (admin only)
  Future<void> deleteAnnouncement(String id) async {
    await supabase.from('announcements').delete().eq('id', id);
  }

  /// Mark announcement as viewed by current user
  Future<void> markAsViewed(String announcementId) async {
    final userId = supabase.auth.currentUser!.id;

    try {
      // Check if already viewed
      final existing = await supabase
          .from('announcement_views')
          .select()
          .eq('announcement_id', announcementId)
          .eq('user_id', userId)
          .maybeSingle();

      // Only insert if not already viewed
      if (existing == null) {
        await supabase.from('announcement_views').insert({
          'announcement_id': announcementId,
          'user_id': userId,
        });
      }
    } catch (e) {
      // Ignore duplicate errors (race condition)
      final errorString = e.toString().toLowerCase();
      if (!errorString.contains('duplicate') &&
          !errorString.contains('unique') &&
          !errorString.contains('23505')) {
        rethrow;
      }
    }
  }

  /// Get viewed announcements history for current user
  Future<List<Announcement>> getViewedAnnouncements({
    String? subscriptionStatus,
    int? limit,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // Determine target audience based on subscription status
    final targetAudiences = ['all'];
    if (subscriptionStatus != null) {
      targetAudiences.add(subscriptionStatus);
    }

    // Get viewed announcement IDs for this user
    var viewsQuery = supabase
        .from('announcement_views')
        .select('announcement_id, viewed_at')
        .eq('user_id', userId)
        .order('viewed_at', ascending: false);
    
    if (limit != null) {
      viewsQuery = viewsQuery.limit(limit);
    }
    
    final viewsResponse = await viewsQuery;
    final views = (viewsResponse as List).cast<Map<String, dynamic>>();
    
    if (views.isEmpty) return [];

    final viewedIds = views.map((v) => v['announcement_id'] as String).toList();
    final viewedAtMap = Map<String, DateTime>.fromEntries(
      views.map((v) => MapEntry(
        v['announcement_id'] as String,
        DateTime.parse(v['viewed_at'] as String),
      )),
    );

    // Get announcements that were viewed
    var query = supabase
        .from('announcements')
        .select()
        .inFilter('id', viewedIds);
    
    // Filter by target audience if needed
    if (!targetAudiences.contains('all') && targetAudiences.length > 1) {
      final orConditions = targetAudiences
          .map((audience) => 'target_audience.eq.$audience')
          .join(',');
      query = query.or(orConditions);
    } else if (!targetAudiences.contains('all') && targetAudiences.length == 1) {
      query = query.eq('target_audience', targetAudiences.first);
    }
    
    final response = await query.order('created_at', ascending: false);
    final data = (response as List).cast<Map<String, dynamic>>();
    
    // Map to model and include viewed status
    return data.map((json) {
      final announcementJson = Map<String, dynamic>.from(json);
      announcementJson['is_viewed'] = true;
      final announcement = Announcement.fromJson(announcementJson);
      return announcement;
    }).toList()
      ..sort((a, b) {
        // Sort by viewed_at date (most recently viewed first)
        final aViewedAt = viewedAtMap[a.id];
        final bViewedAt = viewedAtMap[b.id];
        if (aViewedAt == null || bViewedAt == null) return 0;
        return bViewedAt.compareTo(aViewedAt);
      });
  }

  /// Get unread announcements count for current user
  Future<int> getUnreadCount({String? subscriptionStatus}) async {
    final announcements = await getActiveAnnouncements(
      subscriptionStatus: subscriptionStatus,
    );
    return announcements.length;
  }

  /// Broadcast notification to all target users
  Future<void> _broadcastNotification(Announcement announcement) async {
    try {
      // Get all users matching target audience
      // For now, we'll create notification logs for all users
      // In production, you might want to use a background job or Edge Function
      
      // This is a simplified version - in production, you'd want to:
      // 1. Get all user IDs matching target_audience
      // 2. Create notification_logs entries for each user
      // 3. Or use Supabase Edge Function to handle this asynchronously
      
      // For now, notifications will appear when users check their announcements
      print('Broadcast notification created: ${announcement.title}');
    } catch (e) {
      print('Error broadcasting notification: $e');
    }
  }
}

