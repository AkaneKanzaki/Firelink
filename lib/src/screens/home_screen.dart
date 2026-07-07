import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/theme_provider.dart';
import '../providers/topology_provider.dart';
import '../providers/locale_provider.dart';
import '../services/file_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Landing screen with options to create a new project or open an existing one.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
          ),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.darkBackground,
                    const Color(0xFF0F1923),
                    const Color(0xFF0D1F2D),
                  ]
                : [
                    AppColors.lightBackground,
                    const Color(0xFFE8F4F8),
                    const Color(0xFFE0F0FF),
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background decorative elements
              _buildBackgroundDecoration(isDark, size),
              // Main content
              _buildContent(context, isDark),
              // Theme and Language toggles in top-right corner
              Positioned(
                top: 16,
                right: 16,
                child: Row(
                  children: [
                    _buildLanguageToggle(context, isDark),
                    const SizedBox(width: 12),
                    _buildThemeToggle(context, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundDecoration(bool isDark, Size size) {
    return CustomPaint(
      size: size,
      painter: _HomeBackgroundPainter(isDark: isDark),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    final loc = context.watch<LocaleProvider>();
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon/Logo
                        _buildAppIcon(isDark),
                        const SizedBox(height: 20),
                        // Title
                        Text(
                          'Firelink',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -1,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Network Simulator & Designer',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                        ),
                        const SizedBox(height: 32),

                        // New Project Button
                        _buildPrimaryButton(
                          context: context,
                          icon: Icons.add_rounded,
                          label: loc.get('home_new_project'),
                          isDark: isDark,
                          onTap: () => _createNewProject(context),
                        ),
                        const SizedBox(height: 12),
                        // Open Project Button
                        _buildSecondaryButton(
                          context: context,
                          icon: Icons.folder_open_rounded,
                          label: loc.get('home_open_project'),
                          isDark: isDark,
                          onTap: () => _openProject(context),
                        ),
                        const SizedBox(height: 12),
                        // Practice / Tutorial Button
                        _buildSecondaryButton(
                          context: context,
                          icon: Icons.school_rounded,
                          label: loc.get('home_tutorial'),
                          isDark: isDark,
                          onTap: () {
                            Navigator.pushNamed(context, '/tutorial-selection');
                          },
                        ),
                        const SizedBox(height: 12),
                        // About Button
                        _buildSecondaryButton(
                          context: context,
                          icon: Icons.info_outline_rounded,
                          label: 'About Firelink',
                          isDark: isDark,
                          onTap: () => _showAboutDialog(context, isDark),
                        ),
                        const SizedBox(height: 32),
                        // Version info
                        FutureBuilder<PackageInfo>(
                          future: PackageInfo.fromPlatform(),
                          builder: (context, snapshot) {
                            final version = snapshot.hasData
                                ? snapshot.data!.version
                                : '1.0.0';
                            return Text(
                              'v$version',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextTertiary
                                        : AppColors.lightTextTertiary,
                                  ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppIcon(bool isDark) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.primaryCyan, AppColors.secondaryViolet]
              : [AppColors.primaryTeal, AppColors.secondaryViolet],
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.primaryCyan : AppColors.primaryTeal)
                .withValues(alpha: 0.3),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(Icons.hub_rounded, size: 48, color: Colors.white),
    );
  }

  Widget _buildPrimaryButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark
              ? AppColors.primaryCyan
              : AppColors.primaryTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => context.read<ThemeProvider>().toggleTheme(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? AppColors.darkSurfaceVariant
              : AppColors.lightSurfaceVariant,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          size: 20,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _buildLanguageToggle(BuildContext context, bool isDark) {
    final loc = context.watch<LocaleProvider>();
    return GestureDetector(
      onTap: () => loc.toggleLocale(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? AppColors.darkSurfaceVariant
              : AppColors.lightSurfaceVariant,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          loc.locale.toUpperCase(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  void _createNewProject(BuildContext context) {
    context.read<TopologyProvider>().clearTopology();
    Navigator.pushNamed(context, '/workspace');
  }

  void _showAboutDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark
              ? AppColors.darkSurface
              : AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.info_rounded,
                color: isDark ? AppColors.primaryCyan : AppColors.primaryTeal,
              ),
              const SizedBox(width: 12),
              Text(
                'About Firelink',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Firelink is a high-performance network topology simulator built with Flutter.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Created by',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '@AkaneKanzaki (Muhammad Rizky Aulia)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '© 2026 AkaneKanzaki. All rights reserved.\nLicensed under the MIT License.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final url = Uri.parse(
                    'https://github.com/AkaneKanzaki/Firelink',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 4.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.code_rounded,
                        size: 20,
                        color: isDark
                            ? AppColors.primaryCyan
                            : AppColors.primaryTeal,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'View on GitHub',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isDark
                              ? AppColors.primaryCyan
                              : AppColors.primaryTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openProject(BuildContext context) async {
    final t = await FileService.loadTopologyFromPicker();
    if (t != null && context.mounted) {
      context.read<TopologyProvider>().loadFromTopology(t);
      Navigator.pushNamed(context, '/workspace');
    }
  }
}

/// Paints subtle decorative circles in the background.
class _HomeBackgroundPainter extends CustomPainter {
  final bool isDark;

  _HomeBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke;

    // Draw subtle concentric circles
    final center = Offset(size.width * 0.8, size.height * 0.2);
    for (int i = 1; i <= 4; i++) {
      paint
        ..color = (isDark ? AppColors.primaryCyan : AppColors.primaryTeal)
            .withValues(alpha: 0.03 + (i * 0.01))
        ..strokeWidth = 1;
      canvas.drawCircle(center, i * 60.0, paint);
    }

    // Draw another set at bottom-left
    final center2 = Offset(size.width * 0.15, size.height * 0.85);
    for (int i = 1; i <= 3; i++) {
      paint
        ..color =
            (isDark ? AppColors.secondaryViolet : AppColors.secondaryViolet)
                .withValues(alpha: 0.03 + (i * 0.01))
        ..strokeWidth = 1;
      canvas.drawCircle(center2, i * 50.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HomeBackgroundPainter oldDelegate) {
    return isDark != oldDelegate.isDark;
  }
}
