import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/dashboard/core/api/data/abstract.dart';
import 'package:lunasea/modules/dashboard/routes/dashboard/widgets/content_block.dart';
import 'package:lunasea/system/backend_state.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:lunasea/widgets/ui.dart';
import 'package:provider/provider.dart';

void main() {
  tearDown(LunaBackendState.clear);

  testWidgets('content block image headers come from source instance', (
    tester,
  ) async {
    final instance = LunaServiceInstance(
      id: 'radarr-nas',
      profileId: 'default',
      module: LunaModule.RADARR,
      displayName: 'NAS Radarr',
      enabled: true,
      headers: {'X-Instance': 'radarr-nas'},
    );
    LunaBackendState.profiles['default'] = LunaProfile(
      serviceInstances: [instance],
      radarrHeaders: {'X-Legacy': 'profile'},
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ProfilesStore(),
        child: MaterialApp(home: ContentBlock(_FakeCalendarData(instance.ref))),
      ),
    );

    final block = tester.widget<LunaBlock>(find.byType(LunaBlock));
    expect(block.posterHeaders, {'X-Instance': 'radarr-nas'});
    expect(block.backgroundHeaders, {'X-Instance': 'radarr-nas'});
  });
}

class _FakeCalendarData extends CalendarData {
  _FakeCalendarData(LunaServiceInstanceRef sourceRef)
    : super(1, 'Title', 'NAS Radarr', sourceRef);

  @override
  List<TextSpan> get body => const [TextSpan(text: 'Body')];

  @override
  String? backgroundUrl(BuildContext context) =>
      'https://example/background.jpg';

  @override
  Future<void> enterContent(BuildContext context) async {}

  @override
  String? posterUrl(BuildContext context) => 'https://example/poster.jpg';

  @override
  Widget trailing(BuildContext context) => const SizedBox.shrink();

  @override
  Future<void> trailingOnLongPress(BuildContext context) async {}

  @override
  Future<void> trailingOnPress(BuildContext context) async {}
}
