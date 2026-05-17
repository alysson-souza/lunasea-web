import 'package:flutter/material.dart';

import 'package:lunasea/widgets/ui.dart';
import 'package:lunasea/modules/dashboard/core/api/data/abstract.dart';

class ContentBlock extends StatelessWidget {
  final CalendarData data;
  const ContentBlock(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    final headers = data.sourceServiceInstance(context)?.headers ?? const {};
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
}
