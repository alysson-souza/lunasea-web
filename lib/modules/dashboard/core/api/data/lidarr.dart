import 'package:flutter/material.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/router/routes/lidarr.dart';
import 'package:lunasea/system/gateway/service_endpoint.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
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
    required this.albumTitle,
    required this.artistId,
    required this.hasAllFiles,
    required this.totalTrackCount,
  }) : super(id, title);

  @override
  List<TextSpan> get body {
    return [
      TextSpan(
        text: albumTitle,
        style: const TextStyle(
          fontStyle: FontStyle.italic,
        ),
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
        )
    ];
  }

  @override
  Future<void> enterContent(BuildContext context) async {
    LidarrRoutes.ARTIST.go(params: {
      'artist': artistId.toString(),
    });
  }

  @override
  Widget trailing(BuildContext context) => LunaIconButton(
        icon: Icons.search_rounded,
        onPressed: () async => trailingOnPress(context),
        onLongPress: () async => trailingOnLongPress(context),
      );

  @override
  Future<void> trailingOnPress(BuildContext context) async {
    await LidarrAPI.from(context.read<ProfilesStore>().active)
        .searchAlbums([id])
        .then((_) =>
            showLunaSuccessSnackBar(title: 'Searching...', message: albumTitle))
        .catchError((error) =>
            showLunaErrorSnackBar(title: 'Failed to Search', error: error));
  }

  @override
  Future<void> trailingOnLongPress(BuildContext context) async {
    LidarrRoutes.ARTIST_ALBUM_RELEASES.go(params: {
      'artist': artistId.toString(),
      'album': id.toString(),
    });
  }

  @override
  String backgroundUrl(BuildContext context) {
    final profile = context.read<ProfilesStore>().active;
    final endpoint =
        LunaServiceEndpoint.fromProfile(profile, LunaModule.LIDARR);
    if (profile.lidarrEnabled) {
      final url =
          '${endpoint.mediaCoverBase('api/v1', 'MediaCover/Artist')}/$artistId/fanart-360.jpg';
      return endpoint.authenticatedUrl(url, profile.lidarrKey);
    }
    return '';
  }

  @override
  String posterUrl(BuildContext context) {
    final profile = context.read<ProfilesStore>().active;
    final endpoint =
        LunaServiceEndpoint.fromProfile(profile, LunaModule.LIDARR);
    if (profile.lidarrEnabled) {
      final url =
          '${endpoint.mediaCoverBase('api/v1', 'MediaCover/Artist')}/$artistId/poster-500.jpg';
      return endpoint.authenticatedUrl(url, profile.lidarrKey);
    }
    return '';
  }
}
