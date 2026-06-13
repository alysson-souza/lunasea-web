import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/extensions/datetime.dart';
import 'package:lunasea/extensions/string/string.dart';
import 'package:lunasea/modules/radarr.dart';
import 'package:lunasea/router/routes/radarr.dart';

class RadarrUpcomingTile extends StatefulWidget {
  static final itemExtent = LunaBlock.calculateItemExtent(3);

  final RadarrMovie movie;
  final RadarrQualityProfile? profile;

  /// When set, navigation on tap uses [goInstance] with this id instead of
  /// inheriting the instanceId from the current URL. Used in consolidated views.
  final String? instanceId;

  /// Optional extra body line for the instance display name in consolidated views.
  /// Callers must use [LunaBlock.calculateItemExtent(4)] as item height.
  final TextSpan? instanceLabel;

  const RadarrUpcomingTile({
    super.key,
    required this.movie,
    required this.profile,
    this.instanceId,
    this.instanceLabel,
  });

  @override
  State<RadarrUpcomingTile> createState() => _State();
}

class _State extends State<RadarrUpcomingTile> {
  @override
  Widget build(BuildContext context) {
    return Selector<RadarrState, Future<List<RadarrMovie>>?>(
      selector: (_, state) => state.missing,
      builder: (context, missing, _) {
        return LunaBlock(
          title: widget.movie.title,
          body: [
            _subtitle1(),
            _subtitle2(),
            _subtitle3(),
            if (widget.instanceLabel != null) widget.instanceLabel!,
          ],
          trailing: _trailing(),
          backgroundUrl: context.read<RadarrState>().getFanartURL(
            widget.movie.id,
          ),
          posterHeaders: context.read<RadarrState>().headers,
          posterPlaceholderIcon: LunaIcons.VIDEO_CAM,
          posterIsSquare: false,
          posterUrl: context.read<RadarrState>().getPosterURL(widget.movie.id),
          onTap: _onTap,
          disabled: !widget.movie.monitored!,
        );
      },
    );
  }

  TextSpan _subtitle1() {
    return TextSpan(
      children: [
        TextSpan(text: widget.movie.lunaYear),
        TextSpan(text: LunaUI.TEXT_BULLET.pad()),
        TextSpan(text: widget.movie.lunaRuntime),
        TextSpan(text: LunaUI.TEXT_BULLET.pad()),
        TextSpan(text: widget.movie.lunaStudio),
      ],
    );
  }

  TextSpan _subtitle2() {
    return TextSpan(
      children: [
        TextSpan(text: widget.profile!.lunaName),
        TextSpan(text: LunaUI.TEXT_BULLET.pad()),
        TextSpan(text: widget.movie.lunaMinimumAvailability),
        TextSpan(text: LunaUI.TEXT_BULLET.pad()),
        TextSpan(text: widget.movie.lunaReleaseDate),
      ],
    );
  }

  TextSpan _subtitle3() {
    Color color;
    String? _days;
    String type;
    if (widget.movie.lunaIsInCinemas && !widget.movie.lunaIsReleased) {
      color = LunaColours.blue;
      _days = widget.movie.lunaEarlierReleaseDate?.asDaysDifference();
      type = 'release';
    } else if (!widget.movie.lunaIsInCinemas && !widget.movie.lunaIsReleased) {
      color = LunaColours.orange;
      _days = widget.movie.inCinemas?.asDaysDifference();
      type = 'cinema';
    } else {
      color = LunaColours.grey;
      _days = LunaUI.TEXT_EMDASH;
      type = 'unknown';
    }
    return TextSpan(
      style: TextStyle(fontWeight: LunaUI.FONT_WEIGHT_BOLD, color: color),
      children: [
        if (type == 'release')
          TextSpan(
            text: _days == null
                ? 'radarr.AvailabilityUnknown'.tr()
                : _days == 'Today'
                ? 'radarr.AvailableToday'.tr()
                : 'radarr.AvailableIn'.tr(args: [_days]),
          ),
        if (type == 'cinema')
          TextSpan(
            text: _days == null
                ? 'radarr.CinemaDateUnknown'.tr()
                : _days == 'Today'
                ? 'radarr.InCinemasToday'.tr()
                : 'radarr.InCinemasIn'.tr(args: [_days]),
          ),
        if (type == 'unknown') TextSpan(text: _days),
      ],
    );
  }

  LunaIconButton _trailing() {
    final movieParam = {'movie': widget.movie.id!.toString()};
    final instanceId = widget.instanceId;
    return LunaIconButton(
      icon: Icons.search_rounded,
      onPressed: () async => RadarrAPIHelper().automaticSearch(
        context: context,
        movieId: widget.movie.id!,
        title: widget.movie.title!,
      ),
      onLongPress: () => instanceId != null
          ? RadarrRoutes.MOVIE_RELEASES.goInstance(
              instanceId: instanceId,
              params: movieParam,
            )
          : RadarrRoutes.MOVIE_RELEASES.go(params: movieParam),
    );
  }

  Future<void> _onTap() async {
    final movieParam = {'movie': widget.movie.id!.toString()};
    final instanceId = widget.instanceId;
    if (instanceId != null) {
      RadarrRoutes.MOVIE.goInstance(instanceId: instanceId, params: movieParam);
    } else {
      RadarrRoutes.MOVIE.go(params: movieParam);
    }
  }
}
