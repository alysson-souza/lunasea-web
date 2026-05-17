import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/extensions/string/string.dart';
import 'package:lunasea/modules/radarr.dart';

class RadarrMovieDetailsFilesFileBlock extends StatefulWidget {
  final RadarrMovieFile file;

  const RadarrMovieDetailsFilesFileBlock({super.key, required this.file});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<RadarrMovieDetailsFilesFileBlock> {
  LunaLoadingState _deleteFileState = LunaLoadingState.INACTIVE;

  @override
  Widget build(BuildContext context) {
    return BackendPreferenceGroupCard(
      content: [
        BackendPreferenceGroupContent(
          title: 'relative path',
          body: widget.file.lunaRelativePath,
        ),
        BackendPreferenceGroupContent(
          title: 'video',
          body: widget.file.mediaInfo?.lunaVideoCodec,
        ),
        BackendPreferenceGroupContent(
          title: 'audio',
          body: [
            widget.file.mediaInfo?.lunaAudioCodec,
            if (widget.file.mediaInfo?.audioChannels != null)
              widget.file.mediaInfo?.audioChannels.toString(),
          ].join(LunaUI.TEXT_BULLET.pad()),
        ),
        BackendPreferenceGroupContent(
          title: 'size',
          body: widget.file.lunaSize,
        ),
        BackendPreferenceGroupContent(
          title: 'languages',
          body: widget.file.lunaLanguage,
        ),
        BackendPreferenceGroupContent(
          title: 'quality',
          body: widget.file.lunaQuality,
        ),
        BackendPreferenceGroupContent(
          title: 'formats',
          body: widget.file.lunaCustomFormats,
        ),
        BackendPreferenceGroupContent(
          title: 'added on',
          body: widget.file.lunaDateAdded,
        ),
      ],
      buttons: [
        if (widget.file.mediaInfo != null)
          LunaButton.text(
            text: 'Media Info',
            icon: Icons.info_outline_rounded,
            onTap: () async => _viewMediaInfo(),
          ),
        LunaButton(
          type: LunaButtonType.TEXT,
          text: 'Delete',
          icon: Icons.delete_rounded,
          onTap: () async => _deleteFile(),
          color: LunaColours.red,
          loadingState: _deleteFileState,
        ),
      ],
    );
  }

  Future<void> _deleteFile() async {
    setState(() => _deleteFileState = LunaLoadingState.ACTIVE);
    bool result = await RadarrDialogs().deleteMovieFile(context);
    if (result) {
      bool execute = await RadarrAPIHelper().deleteMovieFile(
        context: context,
        movieFile: widget.file,
      );
      if (execute) context.read<RadarrMovieDetailsState>().fetchFiles(context);
    }
    setState(() => _deleteFileState = LunaLoadingState.INACTIVE);
  }

  Future<void> _viewMediaInfo() async {
    LunaBottomModalSheet().show(
      builder: (context) => LunaListViewModal(
        children: [
          LunaHeader(text: 'radarr.Video'.tr()),
          BackendPreferenceGroupCard(
            content: [
              BackendPreferenceGroupContent(
                title: 'radarr.BitDepth'.tr(),
                body: widget.file.mediaInfo?.lunaVideoBitDepth,
              ),
              BackendPreferenceGroupContent(
                title: 'radarr.Codec'.tr(),
                body: widget.file.mediaInfo?.lunaVideoCodec,
              ),
              BackendPreferenceGroupContent(
                title: 'radarr.DynamicRange'.tr(),
                body: widget.file.mediaInfo?.lunaVideoDynamicRange,
              ),
              BackendPreferenceGroupContent(
                title: 'radarr.FPS'.tr(),
                body: widget.file.mediaInfo?.lunaVideoFps,
              ),
              BackendPreferenceGroupContent(
                title: 'radarr.Resolution'.tr(),
                body: widget.file.mediaInfo?.lunaVideoResolution,
              ),
            ],
          ),
          LunaHeader(text: 'radarr.Audio'.tr()),
          BackendPreferenceGroupCard(
            content: [
              BackendPreferenceGroupContent(
                title: 'radarr.Channels'.tr(),
                body: widget.file.mediaInfo?.lunaAudioChannels,
              ),
              BackendPreferenceGroupContent(
                title: 'radarr.Codec'.tr(),
                body: widget.file.mediaInfo?.lunaAudioCodec,
              ),
              BackendPreferenceGroupContent(
                title: 'radarr.Languages'.tr(),
                body: widget.file.mediaInfo?.lunaAudioLanguages,
              ),
              BackendPreferenceGroupContent(
                title: 'radarr.Streams'.tr(),
                body: widget.file.mediaInfo?.lunaAudioStreamCount,
              ),
            ],
          ),
          LunaHeader(text: 'radarr.Other'.tr()),
          BackendPreferenceGroupCard(
            content: [
              BackendPreferenceGroupContent(
                title: 'radarr.Runtime'.tr(),
                body: widget.file.mediaInfo?.lunaRunTime,
              ),
              BackendPreferenceGroupContent(
                title: 'radarr.ScanType'.tr(),
                body: widget.file.mediaInfo?.lunaScanType,
              ),
              BackendPreferenceGroupContent(
                title: 'radarr.Subtitles'.tr(),
                body: widget.file.mediaInfo?.lunaSubtitles,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
