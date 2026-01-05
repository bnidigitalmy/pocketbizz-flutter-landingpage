import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/dashboard_mood_engine.dart';

/// Morning Briefing Card
/// Adaptive greeting based on time of day and business state
/// Implements "tenang bila boleh, tegas bila perlu" philosophy
class MorningBriefingCard extends StatelessWidget {
  final String userName;
  final bool hasUrgentIssues; // stok = 0, order overdue, batch expired

  const MorningBriefingCard({
    super.key,
    required this.userName,
    this.hasUrgentIssues = false,
  });

  DashboardMode get _mode => DashboardMoodEngine.getCurrentMode();
  
  MoodTone get _mood => DashboardMoodEngine.getMoodTone(
    mode: _mode,
    hasUrgentIssues: hasUrgentIssues,
  );

  String _getGreeting() {
    return DashboardMoodEngine.getGreeting(
      mode: _mode,
      mood: _mood,
      userName: userName,
    );
  }

  String _getReassuranceMessage() {
    return DashboardMoodEngine.getReassuranceMessage(
      mode: _mode,
      mood: _mood,
    );
  }

  IconData _getTimeIcon() {
    switch (_mode) {
      case DashboardMode.morning:
        return Icons.wb_sunny;
      case DashboardMode.afternoon:
        return Icons.wb_twilight;
      case DashboardMode.evening:
        return Icons.nightlight_round;
      case DashboardMode.urgent:
        return Icons.warning_rounded;
    }
  }

  LinearGradient _getGradient() {
    final primaryColor = DashboardMoodEngine.getPrimaryColor(_mood);
    return LinearGradient(
      colors: [
        primaryColor,
        primaryColor.withOpacity(0.8),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: _getGradient(),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: DashboardMoodEngine.getPrimaryColor(_mood).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.95),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _mood == MoodTone.urgent 
                            ? Icons.warning_rounded 
                            : Icons.check_circle_outline_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _getReassuranceMessage(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Time icon (without clock)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getTimeIcon(),
              color: Colors.white,
              size: 48,
            ),
          ),
        ],
      ),
    );
  }
}




