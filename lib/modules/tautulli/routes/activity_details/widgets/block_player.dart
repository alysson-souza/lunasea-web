import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/tautulli.dart';

class TautulliActivityDetailsPlayerBlock extends StatelessWidget {
  final TautulliSession session;

  const TautulliActivityDetailsPlayerBlock({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return BackendPreferenceGroupCard(
      content: [
        BackendPreferenceGroupContent(
          title: 'tautulli.Location'.tr(),
          body: session.lunaIPAddress,
        ),
        BackendPreferenceGroupContent(
          title: 'tautulli.Platform'.tr(),
          body: session.lunaPlatform,
        ),
        BackendPreferenceGroupContent(
          title: 'tautulli.Product'.tr(),
          body: session.lunaProduct,
        ),
        BackendPreferenceGroupContent(
          title: 'tautulli.Player'.tr(),
          body: session.lunaPlayer,
        ),
        BackendPreferenceGroupContent(
          title: 'tautulli.Quality'.tr(),
          body: session.lunaQuality,
        ),
      ],
    );
  }
}
