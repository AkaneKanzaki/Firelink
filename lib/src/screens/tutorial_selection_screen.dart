import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../models/tutorial_level.dart';
import '../providers/theme_provider.dart';
import '../providers/topology_provider.dart';
import '../providers/locale_provider.dart';
import '../services/tutorial_progress_service.dart';

class TutorialSelectionScreen extends StatefulWidget {
  const TutorialSelectionScreen({super.key});

  @override
  State<TutorialSelectionScreen> createState() =>
      _TutorialSelectionScreenState();
}

class _TutorialSelectionScreenState extends State<TutorialSelectionScreen> {
  int _unlockedLevelIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final index = await TutorialProgressService.getUnlockedLevelIndex();
    if (mounted) {
      setState(() {
        _unlockedLevelIndex = index;
        _isLoading = false;
      });
    }
  }

  void _startLevel(TutorialLevel level) {
    // Set the level in TopologyProvider and push to workspace
    final topology = context.read<TopologyProvider>();
    topology.startTutorial(level);
    Navigator.pushNamed(context, '/workspace');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final loc = context.watch<LocaleProvider>();

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.get('Select Tutorial Level'),
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primaryCyan),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.get('Campaign Mode'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loc.get('Complete levels to unlock more advanced scenarios.'),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.2,
                          ),
                      itemCount: TutorialLevel.allLevels.length,
                      itemBuilder: (context, index) {
                        return _buildLevelCard(
                          context,
                          isDark,
                          TutorialLevel.allLevels[index],
                          index,
                          index + 1,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLevelCard(
    BuildContext context,
    bool isDark,
    TutorialLevel level,
    int index,
    int levelNum,
  ) {
    final isUnlocked = index <= _unlockedLevelIndex;
    final loc = context.watch<LocaleProvider>();
    return InkWell(
      onTap: isUnlocked ? () => _startLevel(level) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked
                ? AppColors.primaryCyan.withValues(alpha: 0.5)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isUnlocked ? 2 : 1,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: AppColors.primaryCyan.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? AppColors.primaryCyan.withValues(alpha: 0.1)
                        : AppColors.canvasDarkGrid.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${loc.get('Level')} $levelNum',
                    style: TextStyle(
                      color: isUnlocked
                          ? AppColors.primaryCyan
                          : (isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (!isUnlocked)
                  Icon(
                    Icons.lock_rounded,
                    size: 20,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              loc.get(level.title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isUnlocked
                    ? (isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary)
                    : (isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                loc.get(level.description),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isUnlocked
                      ? (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary)
                      : (isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
