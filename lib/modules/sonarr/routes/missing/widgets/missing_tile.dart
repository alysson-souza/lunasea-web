import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/extensions/datetime.dart';
import 'package:lunasea/extensions/string/string.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/router/routes/sonarr.dart';

class SonarrMissingTile extends StatefulWidget {
  static final itemExtent = LunaBlock.calculateItemExtent(3);

  final SonarrMissingRecord record;
  final SonarrSeries? series;

  /// When set, navigation uses [goInstance] with this id instead of inheriting
  /// the instanceId from the current URL. Used in consolidated views.
  final String? instanceId;

  /// Optional extra body line for the instance display name in consolidated views.
  /// Callers must use [LunaBlock.calculateItemExtent(4)] as item height.
  final TextSpan? instanceLabel;

  const SonarrMissingTile({
    super.key,
    required this.record,
    this.series,
    this.instanceId,
    this.instanceLabel,
  });

  @override
  State<SonarrMissingTile> createState() => _State();
}

class _State extends State<SonarrMissingTile> {
  @override
  Widget build(BuildContext context) {
    return LunaBlock(
      backgroundUrl: context.read<SonarrState>().getFanartURL(
        widget.record.seriesId,
      ),
      posterUrl: context.read<SonarrState>().getPosterURL(
        widget.record.seriesId,
      ),
      posterHeaders: context.read<SonarrState>().headers,
      posterPlaceholderIcon: LunaIcons.VIDEO_CAM,
      title:
          widget.record.series?.title ??
          widget.series?.title ??
          LunaUI.TEXT_EMDASH,
      body: [
        _subtitle1(),
        _subtitle2(),
        _subtitle3(),
        if (widget.instanceLabel != null) widget.instanceLabel!,
      ],
      disabled: !widget.record.monitored!,
      onTap: _onTap,
      onLongPress: _onLongPress,
      trailing: _trailing(),
    );
  }

  Widget _trailing() {
    return LunaIconButton(
      icon: Icons.search_rounded,
      onPressed: _trailingOnTap,
      onLongPress: _trailingOnLongPress,
    );
  }

  TextSpan _subtitle1() {
    return TextSpan(
      children: [
        TextSpan(
          text: widget.record.seasonNumber == 0
              ? 'Specials'
              : 'Season ${widget.record.seasonNumber}',
        ),
        TextSpan(text: LunaUI.TEXT_BULLET.pad()),
        TextSpan(text: 'Episode ${widget.record.episodeNumber}'),
      ],
    );
  }

  TextSpan _subtitle2() {
    return TextSpan(
      style: const TextStyle(fontStyle: FontStyle.italic),
      text: widget.record.title ?? 'lunasea.Unknown'.tr(),
    );
  }

  TextSpan _subtitle3() {
    return TextSpan(
      style: const TextStyle(
        fontSize: LunaUI.FONT_SIZE_H3,
        color: LunaColours.red,
        fontWeight: LunaUI.FONT_WEIGHT_BOLD,
      ),
      children: [
        TextSpan(
          text: widget.record.airDateUtc == null
              ? 'Aired'
              : 'Aired ${widget.record.airDateUtc!.toLocal().asAge()}',
        ),
      ],
    );
  }

  Future<void> _onTap() async {
    final params = {
      'series': (widget.record.seriesId ?? -1).toString(),
      'season': (widget.record.seasonNumber ?? -1).toString(),
    };
    final instanceId = widget.instanceId;
    if (instanceId != null) {
      SonarrRoutes.SERIES_SEASON.goInstance(
        instanceId: instanceId,
        params: params,
      );
    } else {
      SonarrRoutes.SERIES_SEASON.go(params: params);
    }
  }

  Future<void> _onLongPress() async {
    final params = {'series': widget.record.seriesId!.toString()};
    final instanceId = widget.instanceId;
    if (instanceId != null) {
      SonarrRoutes.SERIES.goInstance(instanceId: instanceId, params: params);
    } else {
      SonarrRoutes.SERIES.go(params: params);
    }
  }

  Future<void> _trailingOnTap() async {
    Provider.of<SonarrState>(context, listen: false).api!.command
        .episodeSearch(episodeIds: [widget.record.id!])
        .then(
          (_) => showLunaSuccessSnackBar(
            title: 'Searching for Episode...',
            message: widget.record.title,
          ),
        )
        .catchError((error, stack) {
          LunaLogger().error(
            'Failed to search for episode: ${widget.record.id}',
            error,
            stack,
          );
          showLunaErrorSnackBar(title: 'Failed to Search', error: error);
        });
  }

  Future<void> _trailingOnLongPress() async {
    final queryParams = {'episode': widget.record.id!.toString()};
    final instanceId = widget.instanceId;
    if (instanceId != null) {
      return SonarrRoutes.RELEASES.goInstance(
        instanceId: instanceId,
        queryParams: queryParams,
      );
    }
    return SonarrRoutes.RELEASES.go(queryParams: queryParams);
  }
}
