import 'package:flutter/material.dart';
import 'package:lunasea/router/routes/sonarr.dart';
import 'package:lunasea/widgets/ui.dart';

class SonarrAppBarAddSeriesAction extends StatelessWidget {
  /// Optional override for the tap handler. When null the default behaviour
  /// (navigate to the add-series route using the current URL's instance) is
  /// used — which is correct for per-instance views.  Consolidated views
  /// should pass a handler that first resolves the target instance.
  final VoidCallback? onPressed;

  const SonarrAppBarAddSeriesAction({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return LunaIconButton(
      icon: Icons.add_rounded,
      onPressed: onPressed ?? SonarrRoutes.ADD_SERIES.go,
    );
  }
}
