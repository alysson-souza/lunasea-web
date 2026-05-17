import 'package:flutter/material.dart';
import 'package:lunasea/api/radarr/radarr.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/extensions/int/duration.dart';
import 'package:lunasea/extensions/string/string.dart';
import 'package:lunasea/router/routes/radarr.dart';
import 'package:lunasea/system/gateway/service_endpoint.dart';
import 'package:lunasea/system/logger.dart';
import 'package:lunasea/vendor.dart';
import 'package:lunasea/widgets/ui.dart';
import 'package:lunasea/modules/dashboard/core/api/data/abstract.dart';

class CalendarRadarrData extends CalendarData {
  bool hasFile;
  String? fileQualityProfile;
  int year;
  int runtime;
  String studio;
  DateTime releaseDate;

  CalendarRadarrData({
    required int id,
    required String title,
    required String sourceInstance,
    required LunaServiceInstanceRef sourceRef,
    required this.hasFile,
    required this.fileQualityProfile,
    required this.year,
    required this.runtime,
    required this.studio,
    required this.releaseDate,
  }) : super(id, title, sourceInstance, sourceRef);

  bool get hasReleased => DateTime.now().isAfter(releaseDate);

  @override
  List<TextSpan> get body {
    final released = hasReleased;
    return [
      TextSpan(
        children: [
          TextSpan(text: year.toString()),
          TextSpan(text: LunaUI.TEXT_BULLET.pad()),
          TextSpan(text: runtime.asVideoDuration()),
        ],
      ),
      TextSpan(text: studio),
      if (!hasFile)
        TextSpan(
          text: released ? 'radarr.Missing'.tr() : 'radarr.Unreleased'.tr(),
          style: TextStyle(
            fontWeight: LunaUI.FONT_WEIGHT_BOLD,
            color: released ? LunaColours.red : LunaColours.blue,
          ),
        ),
      if (hasFile)
        TextSpan(
          text: 'Downloaded ($fileQualityProfile)',
          style: const TextStyle(
            fontWeight: LunaUI.FONT_WEIGHT_BOLD,
            color: LunaColours.accent,
          ),
        ),
    ];
  }

  @override
  Future<void> enterContent(BuildContext context) async {
    RadarrRoutes.MOVIE.goInstance(
      instanceId: sourceRef.instanceId,
      params: {'movie': id.toString()},
    );
  }

  @override
  Widget trailing(BuildContext context) {
    return LunaIconButton(
      icon: Icons.search_rounded,
      onPressed: () async => trailingOnPress(context),
      onLongPress: () async => trailingOnLongPress(context),
    );
  }

  @override
  Future<void> trailingOnPress(BuildContext context) async {
    final api = _api(context);
    if (api == null) {
      showLunaErrorSnackBar(
        title: 'Failed to Search',
        error: 'Source instance unavailable',
      );
      return;
    }

    await api.command
        .moviesSearch(movieIds: [id])
        .then((_) {
          showLunaSuccessSnackBar(
            title: 'Searching for Movie...',
            message: title,
          );
        })
        .catchError((error, stack) {
          LunaLogger().error('Failed to search for movie: $id', error, stack);
          showLunaErrorSnackBar(title: 'Failed to Search', error: error);
        });
  }

  @override
  Future<void> trailingOnLongPress(BuildContext context) async {
    RadarrRoutes.MOVIE_RELEASES.goInstance(
      instanceId: sourceRef.instanceId,
      params: {'movie': id.toString()},
    );
  }

  @override
  String? backgroundUrl(BuildContext context) {
    final instance = sourceServiceInstance(context);
    if (instance == null) return null;
    final endpoint = LunaServiceEndpoint.fromInstance(instance);
    final url =
        '${endpoint.mediaCoverBase('api/v3', 'MediaCover')}/$id/fanart-360.jpg';
    return endpoint.authenticatedUrl(url, instance.apiKey);
  }

  @override
  String? posterUrl(BuildContext context) {
    final instance = sourceServiceInstance(context);
    if (instance == null) return null;
    final endpoint = LunaServiceEndpoint.fromInstance(instance);
    final url =
        '${endpoint.mediaCoverBase('api/v3', 'MediaCover')}/$id/poster-500.jpg';
    return endpoint.authenticatedUrl(url, instance.apiKey);
  }

  RadarrAPI? _api(BuildContext context) {
    final instance = sourceServiceInstance(context);
    if (instance == null) return null;
    final endpoint = LunaServiceEndpoint.fromInstance(instance);
    return RadarrAPI(
      host: endpoint.base,
      apiKey: endpoint.isGateway ? '' : instance.apiKey,
      headers: Map<String, dynamic>.from(instance.headers),
    );
  }
}
