import 'package:flutter/material.dart';
import 'package:lunasea/api/sonarr/sonarr.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/system/preferences/lunasea.dart';
import 'package:lunasea/extensions/string/string.dart';
import 'package:lunasea/router/routes/sonarr.dart';

import 'package:lunasea/system/gateway/service_endpoint.dart';
import 'package:lunasea/system/logger.dart';
import 'package:lunasea/widgets/ui.dart';
import 'package:lunasea/vendor.dart';
import 'package:lunasea/modules/dashboard/core/api/data/abstract.dart';

class CalendarSonarrData extends CalendarData {
  String episodeTitle;
  int seasonNumber;
  int episodeNumber;
  int seriesID;
  String airTime;
  bool hasFile;
  String? fileQualityProfile;

  CalendarSonarrData({
    required int id,
    required String title,
    required String sourceInstance,
    required LunaServiceInstanceRef sourceRef,
    required this.episodeTitle,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.seriesID,
    required this.airTime,
    required this.hasFile,
    required this.fileQualityProfile,
  }) : super(id, title, sourceInstance, sourceRef);

  @override
  List<TextSpan> get body {
    final released = hasAired;
    return [
      TextSpan(
        children: [
          TextSpan(
            text: seasonNumber == 0 ? 'Specials' : 'Season $seasonNumber',
          ),
          TextSpan(text: LunaUI.TEXT_BULLET.pad()),
          TextSpan(text: 'Episode $episodeNumber'),
        ],
      ),
      TextSpan(
        style: const TextStyle(fontStyle: FontStyle.italic),
        text: episodeTitle,
      ),
      if (!hasFile)
        TextSpan(
          text: released ? 'sonarr.Missing'.tr() : 'sonarr.Unaired'.tr(),
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

  bool get hasAired {
    if (airTimeObject != null) return DateTime.now().isAfter(airTimeObject!);
    return false;
  }

  @override
  Future<void> enterContent(BuildContext context) async {
    SonarrRoutes.SERIES.goInstance(
      instanceId: sourceRef.instanceId,
      params: {'series': seriesID.toString()},
    );
  }

  @override
  Widget trailing(BuildContext context) => LunaIconButton(
    text: airTimeString,
    onPressed: () async => trailingOnPress(context),
    onLongPress: () => trailingOnLongPress(context),
  );

  DateTime? get airTimeObject {
    return DateTime.tryParse(airTime)?.toLocal();
  }

  String get airTimeString {
    if (airTimeObject != null) {
      return LunaSeaPreferences.USE_24_HOUR_TIME.read()
          ? DateFormat.Hm().format(airTimeObject!)
          : DateFormat('hh:mm\na').format(airTimeObject!);
    }
    return 'Unknown';
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
        .episodeSearch(episodeIds: [id])
        .then(
          (_) => showLunaSuccessSnackBar(
            title: 'Searching for Episode...',
            message: episodeTitle,
          ),
        )
        .catchError((error, stack) {
          LunaLogger().error('Failed to search for episode: $id', error, stack);
          showLunaErrorSnackBar(title: 'Failed to Search', error: error);
        });
  }

  @override
  Future<void> trailingOnLongPress(BuildContext context) async {
    SonarrRoutes.RELEASES.goInstance(
      instanceId: sourceRef.instanceId,
      queryParams: {'episode': id.toString()},
    );
  }

  @override
  String? backgroundUrl(BuildContext context) {
    final instance = sourceServiceInstance(context);
    if (instance == null) return null;
    final endpoint = LunaServiceEndpoint.fromInstance(instance);
    final url =
        '${endpoint.mediaCoverBase('api/v3', 'MediaCover')}/$seriesID/fanart-360.jpg';
    return endpoint.authenticatedUrl(url, instance.apiKey);
  }

  @override
  String? posterUrl(BuildContext context) {
    final instance = sourceServiceInstance(context);
    if (instance == null) return null;
    final endpoint = LunaServiceEndpoint.fromInstance(instance);
    final url =
        '${endpoint.mediaCoverBase('api/v3', 'MediaCover')}/$seriesID/poster-500.jpg';
    return endpoint.authenticatedUrl(url, instance.apiKey);
  }

  SonarrAPI? _api(BuildContext context) {
    final instance = sourceServiceInstance(context);
    if (instance == null) return null;
    final endpoint = LunaServiceEndpoint.fromInstance(instance);
    return SonarrAPI(
      host: endpoint.base,
      apiKey: endpoint.isGateway ? '' : instance.apiKey,
      headers: Map<String, dynamic>.from(instance.headers),
    );
  }
}
