import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_helper.dart';

/// Morning Briefing Card
/// Personalized greeting based on time of day
/// Shows motivational message for SME owners
/// Includes real-time clock
class MorningBriefingCard extends StatefulWidget {
  final String userName;

  const MorningBriefingCard({
    super.key,
    required this.userName,
  });

  @override
  State<MorningBriefingCard> createState() => _MorningBriefingCardState();
}

class _MorningBriefingCardState extends State<MorningBriefingCard> {
  late DateTime _currentTime;
  late int _hour;

  @override
  void initState() {
    super.initState();
    _updateTime();
    // Update clock every second
    _startClock();
  }

  void _updateTime() {
    setState(() {
      _currentTime = DateTimeHelper.now();
      _hour = _currentTime.hour;
    });
  }

  void _startClock() {
    // Update every second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _updateTime();
        _startClock();
      }
    });
  }

  String _getGreeting() {
    if (_hour < 12) {
      return 'Selamat Pagi';
    } else if (_hour < 15) {
      return 'Selamat Tengah Hari';
    } else if (_hour < 19) {
      return 'Selamat Petang';
    } else {
      return 'Selamat Malam';
    }
  }

  String _getMotivationalMessage() {
    if (_hour < 12) {
      return 'Mari kita mulakan hari dengan produktif! 💪';
    } else if (_hour < 15) {
      return 'Teruskan momentum hari ini! 🚀';
    } else if (_hour < 19) {
      return 'Hampir selesai, teruskan usaha! 💼';
    } else {
      return 'Terima kasih atas usaha hari ini! 🙏';
    }
  }

  IconData _getTimeIcon() {
    if (_hour < 12) {
      return Icons.wb_sunny;
    } else if (_hour < 19) {
      return Icons.wb_twilight;
    } else {
      return Icons.nightlight_round;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
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
                  widget.userName,
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
                      const Icon(
                        Icons.rocket_launch,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getMotivationalMessage(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Real-time clock widget
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getTimeIcon(),
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('hh:mm:ss', 'ms').format(_currentTime),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  DateFormat('a', 'ms').format(_currentTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

