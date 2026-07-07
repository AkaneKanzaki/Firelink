import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_theme.dart';
import 'providers/theme_provider.dart';
import 'screens/device_config_screen.dart';
import 'screens/home_screen.dart';
import 'screens/tutorial_selection_screen.dart';
import 'screens/workspace_screen.dart';

/// Root widget for the Firelink application.
class FirelinkApp extends StatelessWidget {
  const FirelinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'Firelink',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme.copyWith(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.android: ZoomPageTransitionsBuilder(),
                TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
              },
            ),
          ),
          darkTheme: AppTheme.darkTheme.copyWith(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.android: ZoomPageTransitionsBuilder(),
                TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
              },
            ),
          ),
          themeMode: themeProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          initialRoute: '/',
          routes: {
            '/': (context) => const HomeScreen(),
            '/tutorial-selection': (context) => const TutorialSelectionScreen(),
            '/workspace': (context) => const WorkspaceScreen(),
          },
          onGenerateRoute: (settings) {
            // Handle parameterized routes.
            if (settings.name == '/device-config') {
              final deviceId = settings.arguments as String;
              return MaterialPageRoute(
                builder: (context) => DeviceConfigScreen(deviceId: deviceId),
              );
            }
            return null;
          },
        );
      },
    );
  }
}
