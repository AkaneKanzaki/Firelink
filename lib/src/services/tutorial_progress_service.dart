import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage tutorial progression state.
class TutorialProgressService {
  static const String _kUnlockedLevelIndex = 'tutorial_unlocked_level_index';

  TutorialProgressService._();

  /// Gets the highest level index the user has unlocked (0-indexed).
  /// Default is 0 (first level is always unlocked).
  static Future<int> getUnlockedLevelIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kUnlockedLevelIndex) ?? 0;
  }

  /// Unlocks a specific level index. If the level is already unlocked or lower
  /// than the currently unlocked level, this does nothing.
  static Future<void> unlockLevel(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_kUnlockedLevelIndex) ?? 0;
    if (index > current) {
      await prefs.setInt(_kUnlockedLevelIndex, index);
    }
  }

  /// Resets progress for testing.
  static Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUnlockedLevelIndex);
  }
}
