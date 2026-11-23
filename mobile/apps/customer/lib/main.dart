import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:near_me_core/near_me_core.dart';
import 'app_state.dart';
import 'screens/auth_screen.dart';
import 'ads.dart';
import 'pin_lock.dart';
import 'screens/shell.dart';

/// Backend URL is injected at build time: flutter build ... --dart-define=API_BASE_URL=https://your-app.vercel.app
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(ApiClient(baseUrl: apiBaseUrl));
  await state.init();
  AdService.instance.init((state.remoteConfig['ads'] as List<dynamic>?) ?? const []); // runs after UMP consent; ignored until Owner enables placements
  runApp(NearMeApp(state: state));
}

class NearMeApp extends StatelessWidget {
  const NearMeApp({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final theme = resolveTheme(manualId: state.themeId.isNotEmpty ? state.themeId : (state.builder.themeId ?? ''), schedule: state.schedule, now: DateTime.now(), country: state.country);
          return MaterialApp(
            title: 'NEAR ME',
            debugShowCheckedModeBanner: false,
            locale: Locale(state.language),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            theme: theme.build(Brightness.light),
            darkTheme: theme.build(Brightness.dark),
            themeMode: state.themeMode,
            home: state.signedIn ? PinLockGate(store: PinStore(), timeoutSec: state.pinTimeoutSec, child: Shell(state: state)) : AuthScreen(state: state),
          );
        },
      );
}
