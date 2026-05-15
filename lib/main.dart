import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:device_preview/device_preview.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/router/router.dart';
import 'package:lunasea/system/recovery_mode/main.dart';
import 'package:lunasea/system/platform.dart';

/// LunaSea Entry Point: Bootstrap & Run Application
///
/// Runs app in guarded zone to attempt to capture fatal (crashing) errors
Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(const LunaApp());
    },
    (error, stack) => LunaLogger().critical(error, stack),
  );
}

class LunaApp extends StatefulWidget {
  const LunaApp({
    super.key,
  });

  @override
  State<LunaApp> createState() => _LunaAppState();
}

class _LunaAppState extends State<LunaApp> {
  final AppBootstrapController _controller = AppBootstrapController();

  @override
  void initState() {
    super.initState();
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        switch (_controller.status) {
          case AppBootstrapStatus.ready:
            return const LunaBIOS();
          case AppBootstrapStatus.error:
            return LunaBootstrapFailure(
              error: _controller.error!,
              onRetry: _controller.retry,
            );
          case AppBootstrapStatus.loading:
            return const LunaBootstrapLoading();
        }
      },
    );
  }
}

class LunaBootstrapLoading extends StatelessWidget {
  const LunaBootstrapLoading({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'LunaSea',
      home: Scaffold(
        backgroundColor: Color(0xFF32323E),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class LunaBootstrapFailure extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const LunaBootstrapFailure({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LunaSea',
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF32323E),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 64),
                  const SizedBox(height: 24),
                  const Text(
                    'LunaSea backend is unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LunaBIOS extends StatelessWidget {
  const LunaBIOS({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = LunaTheme();
    final router = LunaRouter.router;

    return LunaState.providers(
      child: DevicePreview(
        enabled: kDebugMode && LunaPlatform.isDesktop,
        builder: (context) => EasyLocalization(
          supportedLocales: [Locale('en')],
          path: 'assets/localization',
          fallbackLocale: Locale('en'),
          startLocale: Locale('en'),
          useFallbackTranslations: true,
          child: Selector<SettingsStore, int>(
            selector: (_, settings) => Object.hash(
              settings.amoledTheme,
              settings.amoledThemeBorder,
            ),
            builder: (context, _, __) {
              return MaterialApp.router(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                builder: DevicePreview.appBuilder,
                darkTheme: theme.activeTheme(),
                theme: theme.activeTheme(),
                title: 'LunaSea',
                routeInformationProvider: router.routeInformationProvider,
                routeInformationParser: router.routeInformationParser,
                routerDelegate: router.routerDelegate,
              );
            },
          ),
        ),
      ),
    );
  }
}
