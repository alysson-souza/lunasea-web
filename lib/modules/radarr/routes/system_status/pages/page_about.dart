import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/radarr.dart';

class RadarrSystemStatusAboutPage extends StatefulWidget {
  final ScrollController scrollController;

  const RadarrSystemStatusAboutPage({
    super.key,
    required this.scrollController,
  });

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<RadarrSystemStatusAboutPage>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LunaScaffold(scaffoldKey: _scaffoldKey, body: _body());
  }

  Widget _body() {
    return LunaRefreshIndicator(
      context: context,
      key: _refreshKey,
      onRefresh: () async =>
          context.read<RadarrSystemStatusState>().fetchStatus(context),
      child: FutureBuilder(
        future: context.watch<RadarrSystemStatusState>().status,
        builder: (context, AsyncSnapshot<RadarrSystemStatus> snapshot) {
          if (snapshot.hasError) {
            LunaLogger().error(
              'Unable to fetch Radarr system status',
              snapshot.error,
              snapshot.stackTrace,
            );
            return LunaMessage.error(onTap: _refreshKey.currentState!.show);
          }
          if (snapshot.hasData) return _list(snapshot.data!);
          return const LunaLoader();
        },
      ),
    );
  }

  Widget _list(RadarrSystemStatus status) {
    return LunaListView(
      controller: RadarrSystemStatusNavigationBar.scrollControllers[0],
      children: [
        BackendPreferenceGroupCard(
          content: [
            BackendPreferenceGroupContent(
              title: 'Version',
              body: status.lunaVersion,
            ),
            if (status.lunaIsDocker)
              BackendPreferenceGroupContent(
                title: 'Package',
                body: status.lunaPackageVersion,
              ),
            BackendPreferenceGroupContent(
              title: '.NET Core',
              body: status.lunaNetCore,
            ),
            BackendPreferenceGroupContent(
              title: 'Migration',
              body: status.lunaDBMigration,
            ),
            BackendPreferenceGroupContent(
              title: 'AppData',
              body: status.lunaAppDataDirectory,
            ),
            BackendPreferenceGroupContent(
              title: 'Startup',
              body: status.lunaStartupDirectory,
            ),
            BackendPreferenceGroupContent(title: 'mode', body: status.lunaMode),
            BackendPreferenceGroupContent(
              title: 'uptime',
              body: status.lunaUptime,
            ),
          ],
        ),
      ],
    );
  }
}
