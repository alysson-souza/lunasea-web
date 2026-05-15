import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/tautulli.dart';

class TautulliActivityDetailsMetadataBlock extends StatelessWidget {
  final TautulliSession session;

  const TautulliActivityDetailsMetadataBlock({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BackendPreferenceGroupCard(
      content: [
        BackendPreferenceGroupContent(
            title: 'tautulli.Title'.tr(), body: session.lunaFullTitle),
        if (session.year != null)
          BackendPreferenceGroupContent(
              title: 'tautulli.Year'.tr(), body: session.lunaYear),
        BackendPreferenceGroupContent(
            title: 'tautulli.Duration'.tr(), body: session.lunaDuration),
        BackendPreferenceGroupContent(
            title: 'tautulli.ETA'.tr(), body: session.lunaETA),
        BackendPreferenceGroupContent(
            title: 'tautulli.Library'.tr(), body: session.lunaLibraryName),
        BackendPreferenceGroupContent(
            title: 'tautulli.User'.tr(), body: session.lunaFriendlyName),
      ],
    );
  }
}
