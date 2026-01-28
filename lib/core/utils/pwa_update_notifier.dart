import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// PWA Silent Update System - Navigation-Based
///
/// Update system yang apply update HANYA bila user navigate.
/// User tak akan perasan update berlaku.
///
/// How it works:
/// 1. Detect new service worker (update available)
/// 2. Set flag "_pwaUpdateReady" dalam JavaScript
/// 3. Bila user navigate ke page lain, check flag dan reload
///
/// Benefits:
/// - Zero interruptions - user tak kena reload tiba-tiba
/// - Update apply secara natural masa navigation
/// - Smooth user experience
class PWAUpdateNotifier {
  static bool _isInitialized = false;
  static Timer? _periodicCheckTimer;

  /// Initialize PWA update system
  ///
  /// Call this on app start (e.g., in main.dart after app initialization)
  static Future<void> initialize(BuildContext context) async {
    if (!kIsWeb) return;
    if (_isInitialized) return;

    _isInitialized = true;

    // Check for updates periodically (every 5 minutes)
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _triggerUpdateCheck();
    });

    // Initial check
    _triggerUpdateCheck();

    debugPrint('🔄 PWA Update: Initialized (navigation-based reload)');
  }

  /// Trigger service worker update check
  static void _triggerUpdateCheck() {
    if (!kIsWeb) return;

    try {
      html.window.navigator.serviceWorker?.ready.then((registration) {
        registration.update().catchError((e) {
          // Silently fail
        });
      }).catchError((e) {
        // Silently fail
      });
    } catch (e) {
      // Silently fail
    }
  }

  /// Check if PWA update is ready to be applied
  ///
  /// Returns true if a new version is waiting to be applied
  static bool isUpdateReady() {
    if (!kIsWeb) return false;

    try {
      final result = js.context.callMethod('pwaIsUpdateReady', []);
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Apply pending update by reloading the page
  ///
  /// Call this when user navigates to apply the update seamlessly.
  /// Returns true if reload was triggered, false if no update pending.
  static bool applyUpdateIfReady() {
    if (!kIsWeb) return false;

    try {
      final result = js.context.callMethod('pwaReloadIfReady', []);
      if (result == true) {
        debugPrint('🔄 PWA Update: Reloading to apply update...');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('PWA Update: Error applying update: $e');
      return false;
    }
  }

  /// Call this on EVERY navigation in the app
  ///
  /// This will reload the page if an update is pending,
  /// making the update seamless for the user.
  ///
  /// Example usage in navigation:
  /// ```dart
  /// Navigator.push(context, ...).then((_) {
  ///   PWAUpdateNotifier.onNavigation();
  /// });
  /// ```
  ///
  /// Or use the NavigatorObserver:
  /// ```dart
  /// MaterialApp(
  ///   navigatorObservers: [PWAUpdateNavigatorObserver()],
  /// )
  /// ```
  static void onNavigation() {
    if (!kIsWeb) return;

    // Small delay to let the navigation complete visually first
    Future.delayed(const Duration(milliseconds: 100), () {
      applyUpdateIfReady();
    });
  }

  /// Force check and apply update immediately (for settings page)
  static Future<void> forceUpdate(BuildContext context) async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Update hanya tersedia untuk versi web.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // Trigger update check
      final registration = await html.window.navigator.serviceWorker!.ready;
      await registration.update();

      // Wait a moment for service worker to process
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if update is ready
      if (isUpdateReady()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Update ditemui! Memuat semula...'),
              duration: Duration(seconds: 1),
            ),
          );
        }
        // Force reload
        await Future.delayed(const Duration(milliseconds: 500));
        html.window.location.reload();
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
            content: Text('Ralat: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Clean up resources
  static void dispose() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
    _isInitialized = false;
  }

  /// Legacy methods for compatibility
  static Future<void> checkForUpdate(BuildContext context) async {
    _triggerUpdateCheck();
  }

  static Future<void> manualCheckForUpdate(BuildContext context) async {
    await forceUpdate(context);
  }
}

/// Navigator observer that automatically applies PWA updates on navigation
///
/// Add this to your MaterialApp:
/// ```dart
/// MaterialApp(
///   navigatorObservers: [PWAUpdateNavigatorObserver()],
/// )
/// ```
class PWAUpdateNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    // Apply update when navigating to a new page
    PWAUpdateNotifier.onNavigation();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // Apply update when going back
    PWAUpdateNotifier.onNavigation();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    // Apply update when replacing route
    PWAUpdateNotifier.onNavigation();
  }
}
