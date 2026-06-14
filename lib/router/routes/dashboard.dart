import 'package:flutter/material.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/dashboard/routes/dashboard/route.dart';
import 'package:lunasea/modules/dashboard/routes/dashboard/widgets/navigation_bar.dart';
import 'package:lunasea/router/routes.dart';
import 'package:lunasea/system/preferences/dashboard.dart';
import 'package:lunasea/vendor.dart';

enum DashboardRoutes with LunaRoutesMixin {
  HOME('/dashboard');

  @override
  final String path;

  const DashboardRoutes(this.path);

  @override
  LunaModule get module => LunaModule.DASHBOARD;

  @override
  bool isModuleEnabled(BuildContext context) => true;

  @override
  GoRoute get routes {
    switch (this) {
      case DashboardRoutes.HOME:
        return route(
          builder: (_, state) => DashboardRoute(
            initialPage: tabIndexFromRoute(
              state,
              HomeNavigationBar.tabKeys,
              fallback: DashboardPreferences.NAVIGATION_INDEX.read(),
            ),
          ),
        );
    }
  }
}
