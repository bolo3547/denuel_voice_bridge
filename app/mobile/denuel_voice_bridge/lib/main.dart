import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/models.dart';
import 'services/services.dart';
import 'theme/themes.dart';
import 'screens/screens.dart';
import 'screens/home_screen_v2.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize services
  final appSettings = AppSettingsService();
  await appSettings.init();

  final sessionService = SessionService();
  await sessionService.init();

  final metricsService = SpeechMetricsService();

  runApp(DenuelVoiceBridgeApp(
    appSettings: appSettings,
    sessionService: sessionService,
    metricsService: metricsService,
  ));
}

class DenuelVoiceBridgeApp extends StatelessWidget {
  final AppSettingsService appSettings;
  final SessionService sessionService;
  final SpeechMetricsService metricsService;

  const DenuelVoiceBridgeApp({
    super.key,
    required this.appSettings,
    required this.sessionService,
    required this.metricsService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appSettings),
        ChangeNotifierProvider.value(value: sessionService),
        Provider.value(value: metricsService),
      ],
      child: Consumer<AppSettingsService>(
        builder: (context, settings, _) {
          // Determine which theme to use based on current mode
          final isAdultMode = settings.currentMode == UserMode.adult;
          final isFirstLaunch = settings.isFirstLaunch;

          return MaterialApp(
            title: 'Denuel Voice Bridge',
            debugShowCheckedModeBanner: false,
            theme: isAdultMode ? AdultTheme.themeData : ChildTheme.themeData,
            home: _buildHomeScreen(settings, isFirstLaunch),
            routes: {
              '/mode-select': (_) => const ModeSelectorScreen(),
              '/adult-hub': (_) => const AdultHubScreen(),
              '/child-hub': (_) => const ChildHubScreen(),
              '/legacy': (_) => const HomeScreenV2(),
            },
          );
        },
      ),
    );
  }

  Widget _buildHomeScreen(AppSettingsService settings, bool isFirstLaunch) {
    // Show mode selector on first launch or if mode not selected
    if (isFirstLaunch || settings.currentMode == null) {
      return const ModeSelectorScreen();
    }

    // Navigate to appropriate mode hub
    if (settings.currentMode == UserMode.adult) {
      return const AdultHubScreen();
    } else {
      return const ChildHubScreen();
    }
  }
}
