/// Dashboard Mood Engine
/// Adaptive dashboard based on time of day and business state
/// Implements "tenang bila boleh, tegas bila perlu" philosophy

import 'package:flutter/material.dart';

enum DashboardMode {
  morning,    // 5am - 11am: Tenang, 1 cadangan sahaja
  afternoon,  // 11am - 6pm: Fokus & Action, max 2 cadangan
  evening,    // 6pm - 12am: Refleksi & ringkasan
  urgent,     // Override: Tegas mode bila kritikal
}

enum MoodTone {
  calm,       // Tenang, reassuring
  focused,    // Fokus, action-oriented
  reflective, // Refleksi, review
  urgent,     // Tegas, direct
}

class DashboardMoodEngine {
  /// Get current dashboard mode based on time
  static DashboardMode getCurrentMode() {
    final hour = DateTime.now().hour;
    
    if (hour >= 5 && hour < 11) {
      return DashboardMode.morning;
    } else if (hour >= 11 && hour < 18) {
      return DashboardMode.afternoon;
    } else {
      return DashboardMode.evening;
    }
  }

  /// Get mood tone based on mode and business state
  static MoodTone getMoodTone({
    required DashboardMode mode,
    required bool hasUrgentIssues, // stok = 0, order overdue, batch expired
  }) {
    if (hasUrgentIssues) {
      return MoodTone.urgent;
    }
    
    switch (mode) {
      case DashboardMode.morning:
        return MoodTone.calm;
      case DashboardMode.afternoon:
        return MoodTone.focused;
      case DashboardMode.evening:
        return MoodTone.reflective;
      case DashboardMode.urgent:
        return MoodTone.urgent;
    }
  }

  /// Get max number of suggestions based on mode
  static int getMaxSuggestions(DashboardMode mode) {
    switch (mode) {
      case DashboardMode.morning:
        return 1; // Golden rule: 1 sahaja pagi
      case DashboardMode.afternoon:
        return 2;
      case DashboardMode.evening:
        return 1; // Focus on reflection
      case DashboardMode.urgent:
        return 3; // Show all urgent issues
    }
  }

  /// Get color scheme based on mood
  static Color getPrimaryColor(MoodTone mood) {
    switch (mood) {
      case MoodTone.calm:
        return const Color(0xFF60A5FA); // Soft blue
      case MoodTone.focused:
        return const Color(0xFF3B82F6); // Bright blue
      case MoodTone.reflective:
        return const Color(0xFF8B5CF6); // Soft purple
      case MoodTone.urgent:
        return const Color(0xFFEF4444); // Red
    }
  }

  /// Get greeting message based on mode and mood
  static String getGreeting({
    required DashboardMode mode,
    required MoodTone mood,
    required String userName,
  }) {
    if (mood == MoodTone.urgent) {
      return 'Perhatian Diperlukan';
    }

    switch (mode) {
      case DashboardMode.morning:
        return 'Selamat Pagi 👋';
      case DashboardMode.afternoon:
        return 'Selamat Tengah Hari 👋';
      case DashboardMode.evening:
        return 'Selamat Petang 👋';
      case DashboardMode.urgent:
        return 'Perhatian Diperlukan';
    }
  }

  /// Get reassurance message (coach style, BM santai)
  static String getReassuranceMessage({
    required DashboardMode mode,
    required MoodTone mood,
  }) {
    if (mood == MoodTone.urgent) {
      return 'Ada beberapa perkara perlu tindakan segera.';
    }

    switch (mode) {
      case DashboardMode.morning:
        return 'Bisnes anda dalam keadaan terkawal hari ini.';
      case DashboardMode.afternoon:
        return 'Teruskan momentum hari ini.';
      case DashboardMode.evening:
        return 'Terima kasih atas usaha hari ini.';
      case DashboardMode.urgent:
        return 'Ada beberapa perkara perlu tindakan segera.';
    }
  }
}


