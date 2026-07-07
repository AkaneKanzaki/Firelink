import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'src/app.dart';
import 'src/providers/canvas_provider.dart';
import 'src/providers/simulation_provider.dart';
import 'src/providers/theme_provider.dart';
import 'src/providers/topology_provider.dart';
import 'src/providers/locale_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable full screen (immersive mode)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Force landscape mode for better canvas usage.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final localeProvider = LocaleProvider();
  await localeProvider.loadSavedLocale();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => TopologyProvider()),
        ChangeNotifierProvider(create: (_) => CanvasProvider()),
        ChangeNotifierProvider(create: (_) => SimulationProvider()),
      ],
      child: const FirelinkApp(),
    ),
  );
}
