import 'package:flutter/material.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/router/routes/lidarr.dart';
import 'package:lunasea/system/gateway/service_endpoint.dart';
import 'package:lunasea/vendor.dart';
import 'package:lunasea/widgets/ui.dart';
import 'package:lunasea/modules/lidarr/core/api/api.dart';
import 'package:lunasea/modules/dashboard/core/api/data/abstract.dart';

class CalendarLidarrData extends CalendarData {
  String albumTitle;
  int artistId;
  int totalTrackCount;
  bool hasAllFiles;

  CalendarLidarrData({
    required int id,
    required String title,
    required String sourceInstance,
    required LunaServiceInstanceRef sourceRef,
    required this.albumTitle,
    required this.artistId,
    required this.hasAllFiles,
    required this.totalTrackCount,
  }) : super(id, title, sourceInstance, sourceRef);

  @override
  List<TextSpan> get body {
    return [
      TextSpan(
        text: albumTitle,
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),
      TextSpan(
        text: totalTrackCount == 1 ? '1 Track' : '$totalTrackCount Tracks',
      ),
      if (!hasAllFiles)
        const TextSpan(
          text: 'Not Downloaded',
          style: TextStyle(
            fontWeight: LunaUI.FONT_WEIGHT_BOLD,
            color: LunaColours.red,
          ),
        ),
      if (hasAllFiles)
        const TextSpan(
          text: 'Downloaded',
          style: TextStyle(
            fontWeight: LunaUI.FONT_WEIGHT_BOLD,
            color: LunaColours.accent,
          ),
        ),
    ];
  }

  @override
  Future<void> enterContent(BuildContext context) async {
    LidarrRoutes.ARTIST.goInstance(
      instanceId: sourceRef.instanceId,
      params: {'artist': artistId.toString()},
    );
  }

  @override
  Widget trailing(BuildContext context) => LunaIconButton(
    icon: Icons.search_rounded,
    onPressed: () async => trailingOnPress(context),
    onLongPress: () async => trailingOnLongPress(context),
  );

  @override
  Future<void> trailingOnPress(BuildContext context) async {
    final instance = sourceServiceInstance(context);
    if (instance == null) {
      showLunaErrorSnackBar(
        title: 'Failed to Search',
        error: 'Source instance unavailable',
      );
      return;
    }

    await LidarrAPI.fromInstance(instance)
        .searchAlbums([id])
        .then(
          (_) => showLunaSuccessSnackBar(
            title: 'Searching...',
            message: albumTitle,
          ),
        )
        .catchError(
          (error) =>
              showLunaErrorSnackBar(title: 'Failed to Search', error: error),
        );
  }

  @override
  Future<void> trailingOnLongPress(BuildContext context) async {
    LidarrRoutes.ARTIST_ALBUM_RELEASES.goInstance(
      instanceId: sourceRef.instanceId,
      params: {'artist': artistId.toString(), 'album': id.toString()},
    );
  }

  @override
  String? backgroundUrl(BuildContext context) {
    final instance = sourceServiceInstance(context);
    if (instance == null) return null;
    final endpoint = LunaServiceEndpoint.fromInstance(instance);
    final url =
        '${endpoint.mediaCoverBase('api/v1', 'MediaCover/Artist')}/$artistId/fanart-360.jpg';
    return endpoint.authenticatedUrl(url, instance.apiKey);
  }

  @override
  String? posterUrl(BuildContext context) {
    final instance = sourceServiceInstance(context);
    if (instance == null) return null;
    final endpoint = LunaServiceEndpoint.fromInstance(instance);
    final url =
        '${endpoint.mediaCoverBase('api/v1', 'MediaCover/Artist')}/$artistId/poster-500.jpg';
    return endpoint.authenticatedUrl(url, instance.apiKey);
  }
}
