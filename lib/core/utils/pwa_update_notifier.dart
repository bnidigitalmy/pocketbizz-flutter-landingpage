import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// PWA Update Notifier
/// 
/// Smart notification system untuk inform user bila ada update baru.
/// Non-intrusive: SnackBar yang user boleh ignore atau reload.
/// 
/// Features:
/// - Check for updates on app start
/// - Show notification sekali sahaja per update version
/// - Auto-dismiss dalam 5 seconds
/// - Optional reload button
class PWAUpdateNotifier {
  static String? _lastUpdateVersion;
  static bool _isChecking = false;

  /// Check for PWA updates and show notification if available
  /// 
  /// Call this on app start (e.g., in main.dart after app initialization)
  static Future<void> checkForUpdate(BuildContext context) async {
    // Only check on web platform
    if (!kIsWeb) return;

    // Prevent multiple simultaneous checks
    if (_isChecking) return;
    _isChecking = true;

    try {
      // Check if service worker is supported
      if (html.window.navigator.serviceWorker == null) {
        print('PWA Update: Service Worker not supported');
        return;
      }

      // Get service worker registration
      final registration = await html.window.navigator.serviceWorker!.ready;

      // Check for updates
      await registration.update();

      // Check if there's a waiting service worker (new update available)
      // This means a new version has been downloaded and is waiting to be activated
      if (registration.waiting != null && context.mounted) {
        // Generate unique version ID based on current time
        final newVersion = DateTime.now().millisecondsSinceEpoch.toString();
        
        // Only show notification if this is a new update (not shown before)
        if (_lastUpdateVersion != newVersion) {
          _lastUpdateVersion = newVersion;
          _showUpdateNotification(context);
        }
      }
      
      // Also check for installing service worker (update in progress)
      if (registration.installing != null && context.mounted) {
        // Wait a bit for installation to complete, then check again
        await Future.delayed(const Duration(seconds: 2));
        
        // Re-check after delay
        final updatedRegistration = await html.window.navigator.serviceWorker!.ready;
        if (updatedRegistration.waiting != null && context.mounted) {
          final newVersion = DateTime.now().millisecondsSinceEpoch.toString();
          if (_lastUpdateVersion != newVersion) {
            _lastUpdateVersion = newVersion;
            _showUpdateNotification(context);
          }
        }
      }
    } catch (e) {
      print('PWA Update: Error checking for updates: $e');
      // Silently fail - don't interrupt user experience
    } finally {
      _isChecking = false;
    }
  }

  /// Show non-intrusive update notification
  static void _showUpdateNotification(BuildContext context) {
    if (!context.mounted) return;

    // Show SnackBar notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.system_update,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Update tersedia!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Reload untuk dapat versi terbaru.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        duration: const Duration(seconds: 5), // Auto-dismiss after 5 seconds
        action: SnackBarAction(
          label: 'Reload',
          textColor: Colors.white,
          onPressed: () {
            // Reload page to get new version
            html.window.location.reload();
          },
        ),
        behavior: SnackBarBehavior.floating, // Non-blocking
        dismissDirection: DismissDirection.horizontal, // User boleh swipe dismiss
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Manual check for updates (can be called from settings page)
  static Future<void> manualCheckForUpdate(BuildContext context) async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Update check hanya tersedia untuk versi web.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      if (html.window.navigator.serviceWorker == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service Worker tidak disokong.'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final registration = await html.window.navigator.serviceWorker!.ready;
      await registration.update();

      // Check if update is available
      if (!context.mounted) return;
      
      if (registration.waiting != null) {
        _showUpdateNotification(context);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anda sedang menggunakan versi terkini.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat semasa menyemak update: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

