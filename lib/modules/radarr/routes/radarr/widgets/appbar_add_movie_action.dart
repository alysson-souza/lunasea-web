import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/router/routes/radarr.dart';

class RadarrAppBarAddMoviesAction extends StatelessWidget {
  /// Optional override for the tap handler. When null the default behaviour
  /// (navigate to the add-movie route using the current URL's instance) is
  /// used — which is correct for per-instance views.  Consolidated views
  /// should pass a handler that first resolves the target instance.
  final VoidCallback? onPressed;

  const RadarrAppBarAddMoviesAction({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return LunaIconButton(
      icon: Icons.add_rounded,
      iconSize: LunaUI.ICON_SIZE,
      onPressed: onPressed ?? RadarrRoutes.ADD_MOVIE.go,
    );
  }
}
