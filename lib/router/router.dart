import 'package:flutter/material.dart';

import 'package:lunasea/system/logger.dart';
import 'package:lunasea/widgets/pages/error_route.dart';
import 'package:lunasea/router/routes.dart';
import 'package:lunasea/vendor.dart';

class LunaRouter {
  static late GoRouter router;
  static GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();

  void initialize({Uri? initialUri}) {
    final browserInitialLocation = initialLocationFromUri(
      initialUri ?? Uri.base,
    );
    router = GoRouter(
      navigatorKey: navigator,
      errorBuilder: (_, state) => ErrorRoutePage(exception: state.error),
      initialLocation: browserInitialLocation ?? LunaRoutes.initialLocation,
      overridePlatformDefaultLocation: browserInitialLocation != null,
      routes: LunaRoutes.values.map((r) => r.root.routes).toList(),
    );
  }

  void popSafely() {
    if (router.canPop()) router.pop();
  }

  void popToRootRoute() {
    if (navigator.currentState == null) {
      LunaLogger().warning('Not observing any navigation navigators, skipping');
      return;
    }
    navigator.currentState!.popUntil((route) => route.isFirst);
  }
}

@visibleForTesting
String? initialLocationFromUri(Uri uri) {
  final fragment = uri.fragment;
  if (fragment.startsWith('/')) return fragment;

  final path = uri.path;
  if (path.isEmpty || path == '/') return null;
  return Uri(path: path, query: uri.query).toString();
}
