import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sonarr.dart';

class SonarrMediaInfoSheet extends LunaBottomModalSheet {
  final SonarrEpisodeFileMediaInfo? mediaInfo;

  SonarrMediaInfoSheet({
    required this.mediaInfo,
  });

  @override
  Widget builder(BuildContext context) {
    return LunaListViewModal(
      children: [
        LunaHeader(text: 'sonarr.Video'.tr()),
        BackendPreferenceGroupCard(
          content: [
            BackendPreferenceGroupContent(
              title: 'sonarr.BitDepth'.tr(),
              body: mediaInfo!.lunaVideoBitDepth,
            ),
            BackendPreferenceGroupContent(
              title: 'sonarr.Bitrate'.tr(),
              body: mediaInfo!.lunaVideoBitrate,
            ),
            BackendPreferenceGroupContent(
              title: 'sonarr.Codec'.tr(),
              body: mediaInfo!.lunaVideoCodec,
            ),
            BackendPreferenceGroupContent(
              title: 'sonarr.FPS'.tr(),
              body: mediaInfo!.lunaVideoFps,
            ),
            BackendPreferenceGroupContent(
              title: 'sonarr.Resolution'.tr(),
              body: mediaInfo!.lunaVideoResolution,
            ),
            BackendPreferenceGroupContent(
              title: 'sonarr.ScanType'.tr(),
              body: mediaInfo!.lunaVideoScanType,
            ),
          ],
        ),
        LunaHeader(text: 'sonarr.Audio'.tr()),
        BackendPreferenceGroupCard(
          content: [
            BackendPreferenceGroupContent(
              title: 'sonarr.Bitrate'.tr(),
              body: mediaInfo!.lunaAudioBitrate,
            ),
            BackendPreferenceGroupContent(
              title: 'sonarr.Channels'.tr(),
              body: mediaInfo!.lunaAudioChannels,
            ),
            BackendPreferenceGroupContent(
              title: 'sonarr.Codec'.tr(),
              body: mediaInfo!.lunaAudioCodec,
            ),
            BackendPreferenceGroupContent(
              title: 'sonarr.Languages'.tr(),
              body: mediaInfo!.lunaAudioLanguages,
            ),
            BackendPreferenceGroupContent(
              title: 'sonarr.Streams'.tr(),
              body: mediaInfo!.lunaAudioStreamCount,
            ),
          ],
        ),
        LunaHeader(text: 'sonarr.Other'.tr()),
        BackendPreferenceGroupCard(
          content: [
            BackendPreferenceGroupContent(
              title: 'sonarr.Runtime'.tr(),
              body: mediaInfo!.lunaRunTime,
            ),
            BackendPreferenceGroupContent(
              title: 'sonarr.Subtitles'.tr(),
              body: mediaInfo!.lunaSubtitles,
            ),
          ],
        ),
      ],
    );
  }
}
