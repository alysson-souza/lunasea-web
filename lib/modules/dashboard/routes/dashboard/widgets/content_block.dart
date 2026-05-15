import 'package:flutter/material.dart';

import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:lunasea/vendor.dart';
import 'package:lunasea/widgets/ui.dart';
import 'package:lunasea/modules/dashboard/core/api/data/abstract.dart';
import 'package:lunasea/modules/dashboard/core/api/data/lidarr.dart';
import 'package:lunasea/modules/dashboard/core/api/data/radarr.dart';
import 'package:lunasea/modules/dashboard/core/api/data/sonarr.dart';

class ContentBlock extends StatelessWidget {
  final CalendarData data;
  const ContentBlock(this.data, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final headers = getHeaders(context.watch<ProfilesStore>().active);
    return LunaBlock(
      title: data.title,
      body: data.body,
      posterHeaders: headers,
      backgroundHeaders: headers,
      posterUrl: data.posterUrl(context),
      posterPlaceholderIcon: LunaIcons.VIDEO_CAM,
      backgroundUrl: data.backgroundUrl(context),
      trailing: data.trailing(context),
      onTap: () async => data.enterContent(context),
    );
  }

  Map getHeaders(LunaProfile profile) {
    switch (data.runtimeType) {
      case CalendarLidarrData:
        return profile.lidarrHeaders;
      case CalendarRadarrData:
        return profile.radarrHeaders;
      case CalendarSonarrData:
        return profile.sonarrHeaders;
      default:
        return const {};
    }
  }
}
