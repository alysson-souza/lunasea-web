import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/tautulli.dart';

class TautulliActivityDetailsStreamBlock extends StatelessWidget {
  final TautulliSession session;

  const TautulliActivityDetailsStreamBlock({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BackendPreferenceGroupCard(
      content: [
        BackendPreferenceGroupContent(
          title: 'tautulli.Bandwidth'.tr(),
          body: session.lunaBandwidth,
        ),
        BackendPreferenceGroupContent(
          title: 'tautulli.Stream'.tr(),
          body: session.formattedStream(),
        ),
        BackendPreferenceGroupContent(
          title: 'tautulli.Container'.tr(),
          body: session.formattedContainer(),
        ),
        if (session.hasVideo())
          BackendPreferenceGroupContent(
            title: 'tautulli.Video'.tr(),
            body: session.formattedVideo(),
          ),
        if (session.hasAudio())
          BackendPreferenceGroupContent(
            title: 'tautulli.Audio'.tr(),
            body: session.formattedAudio(),
          ),
        if (session.hasSubtitles())
          BackendPreferenceGroupContent(
            title: 'tautulli.Subtitle'.tr(),
            body: session.formattedSubtitles(),
          ),
      ],
    );
  }
}
