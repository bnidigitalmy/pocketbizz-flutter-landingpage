import 'dart:async';
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
/// - Periodic check setiap 5 minit untuk real-time updates
/// - Service worker event listeners untuk immediate detection
/// - Show notification sekali sahaja per update version
/// - Auto-dismiss dalam 5 seconds
/// - Optional reload button
class PWAUpdateNotifier {
  static String? _lastUpdateVersion;
  static bool _isChecking = false;
  static Timer? _periodicCheckTimer;
  static BuildContext? _currentContext;

  /// Initialize PWA update checking with periodic checks and event listeners
  /// 
  /// Call this on app start (e.g., in main.dart after app initialization)
  /// This will:
  /// - Check for updates immediately
  /// - Set up periodic checks every 5 minutes (CHECK sahaja, TIDAK reload)
  /// - Listen for service worker update events
  /// 
  /// IMPORTANT: Sistem hanya CHECK untuk update, TIDAK akan auto-reload.
  /// User akan dapat notification dan perlu tekan "Reload" button untuk reload.
  static Future<void> initialize(BuildContext context) async {
    if (!kIsWeb) return;
    
    _currentContext = context;
    
    // Initial check (semak sekali pada app start) with error handling
    checkForUpdate(context).catchError((e) {
      print('PWA Update: Initial check failed: $e');
    });
    
    // Set up periodic checking setiap 5 minit
    // PENTING: Ini hanya CHECK untuk update, TIDAK reload app
    // Kalau ada update, sistem akan show notification kepada user
    // User perlu tekan "Reload" button untuk reload app
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_currentContext != null && _currentContext!.mounted) {
        // Hanya check untuk update, tidak reload
        checkForUpdate(_currentContext!).catchError((e) {
          print('PWA Update: Periodic check failed: $e');
        });
      } else {
        timer.cancel();
      }
    });
    
    // Set up service worker event listeners for immediate detection
    _setupServiceWorkerListeners(context);
  }

  /// Set up service worker event listeners for real-time update detection
  static void _setupServiceWorkerListeners(BuildContext context) {
    if (!kIsWeb || html.window.navigator.serviceWorker == null) return;
    
    try {
      html.window.navigator.serviceWorker!.ready.then((registration) {
        // Listen for updatefound event (new service worker detected)
        registration.addEventListener('updatefound', (event) {
          print('🔄 PWA Update: New service worker detected!');
          
          final newWorker = registration.installing;
          if (newWorker != null) {
            // Listen for state changes
            newWorker.addEventListener('statechange', (event) {
              if (newWorker.state == 'installed' && registration.waiting != null) {
                // New version installed and waiting
                print('🔄 PWA Update: New version installed, waiting for activation');
                if (context.mounted) {
                  _handleUpdateAvailable(context);
                }
              } else if (newWorker.state == 'activated') {
                // New version activated
                print('✅ PWA Update: New version activated');
                if (context.mounted) {
                  _handleUpdateActivated(context);
                }
              }
            });
          }
        });
        
        // Also check for waiting service worker (update already downloaded)
        if (registration.waiting != null && context.mounted) {
          _handleUpdateAvailable(context);
        }
      }).catchError((e) {
        // Handle promise rejection silently - service worker may not be available
        print('PWA Update: Service worker ready promise rejected: $e');
      });
    } catch (e) {
      print('PWA Update: Error setting up listeners: $e');
    }
  }

  /// Handle when update is available
  static void _handleUpdateAvailable(BuildContext context) {
    final newVersion = DateTime.now().millisecondsSinceEpoch.toString();
    if (_lastUpdateVersion != newVersion) {
      _lastUpdateVersion = newVersion;
      _showUpdateNotification(context);
    }
  }

  /// Handle when update is activated (auto-reload option)
  static void _handleUpdateActivated(BuildContext context) {
    // Option 1: Auto-reload (uncomment if you want immediate reload)
    // html.window.location.reload();
    
    // Option 2: Show notification (current behavior - user chooses when to reload)
    final newVersion = DateTime.now().millisecondsSinceEpoch.toString();
    if (_lastUpdateVersion != newVersion) {
      _lastUpdateVersion = newVersion;
      _showUpdateNotification(context);
    }
  }

  /// Check for PWA updates and show notification if available
  /// 
  /// PENTING: Function ini hanya CHECK untuk update, TIDAK reload app.
  /// Kalau ada update, sistem akan show notification kepada user.
  /// User perlu tekan "Reload" button untuk reload app.
  /// 
  /// This can be called manually or automatically via periodic timer
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

      // Get service worker registration with error handling
      final registration = await html.window.navigator.serviceWorker!.ready.catchError((e) {
        print('PWA Update: Service worker ready failed: $e');
        return null;
      });

      if (registration == null) {
        _isChecking = false;
        return;
      }

      // Check for updates with error handling
      await registration.update().catchError((e) {
        print('PWA Update: Update check failed: $e');
        return null;
      });

      // Check if there's a waiting service worker (new update available)
      // This means a new version has been downloaded and is waiting to be activated
      if (registration.waiting != null && context.mounted) {
        _handleUpdateAvailable(context);
      }
      
      // Also check for installing service worker (update in progress)
      if (registration.installing != null && context.mounted) {
        // Wait a bit for installation to complete, then check again
        await Future.delayed(const Duration(seconds: 2));
        
        // Re-check after delay with error handling
        final updatedRegistration = await html.window.navigator.serviceWorker!.ready.catchError((e) {
          print('PWA Update: Re-check failed: $e');
          return null;
        });
        
        if (updatedRegistration != null && updatedRegistration.waiting != null && context.mounted) {
          _handleUpdateAvailable(context);
        }
      }
    } catch (e) {
      print('PWA Update: Error checking for updates: $e');
      // Silently fail - don't interrupt user experience
    } finally {
      _isChecking = false;
    }
  }

  /// Clean up resources (call when app is disposed)
  static void dispose() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
    _currentContext = null;
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

