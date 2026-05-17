import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/extensions/int/bytes.dart';
import 'package:lunasea/modules/sabnzbd.dart';

class StatisticsRoute extends StatefulWidget {
  final LunaServiceInstance? instance;

  const StatisticsRoute({super.key, this.instance});

  @override
  State<StatisticsRoute> createState() => _State();
}

class _State extends State<StatisticsRoute> with LunaScrollControllerMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  Future<SABnzbdStatisticsData>? _future;
  SABnzbdStatisticsData? _data;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) => LunaScaffold(
    scaffoldKey: _scaffoldKey,
    appBar: _appBar as PreferredSizeWidget?,
    body: _body,
  );

  Future<SABnzbdStatisticsData> _fetch() async {
    final instance = widget.instance;
    final api = instance != null
        ? SABnzbdAPI.fromInstance(instance)
        : context.read<SABnzbdState>().api(context);
    return api.getStatistics();
  }

  Future<void> _refresh() async {
    if (mounted)
      setState(() {
        _future = _fetch();
      });
  }

  Widget get _appBar => LunaAppBar(
    title: 'Server Statistics',
    scrollControllers: [scrollController],
  );

  Widget get _body => LunaRefreshIndicator(
    context: context,
    key: _refreshKey,
    onRefresh: _refresh,
    child: FutureBuilder(
      future: _future,
      builder: (context, AsyncSnapshot<SABnzbdStatisticsData> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.done:
            {
              if (snapshot.hasError || snapshot.data == null)
                return LunaMessage.error(onTap: _refresh);
              _data = snapshot.data;
              return _list;
            }
          case ConnectionState.none:
          case ConnectionState.waiting:
          case ConnectionState.active:
            return const LunaLoader();
        }
      },
    ),
  );

  Widget get _list => LunaListView(
    controller: scrollController,
    children: <Widget>[
      const LunaHeader(text: 'Status'),
      _status(),
      const LunaHeader(text: 'Statistics'),
      _statistics(),
      ..._serverStatistics(),
    ],
  );

  Widget _status() {
    return BackendPreferenceGroupCard(
      content: [
        BackendPreferenceGroupContent(title: 'Uptime', body: _data!.uptime),
        BackendPreferenceGroupContent(title: 'Version', body: _data!.version),
        BackendPreferenceGroupContent(
          title: 'Temp. Space',
          body: '${_data!.tempFreespace.toString()} GB',
        ),
        BackendPreferenceGroupContent(
          title: 'Final Space',
          body: '${_data!.finalFreespace.toString()} GB',
        ),
      ],
    );
  }

  Widget _statistics() {
    return BackendPreferenceGroupCard(
      content: [
        BackendPreferenceGroupContent(
          title: 'Daily',
          body: _data!.dailyUsage.asBytes(),
        ),
        BackendPreferenceGroupContent(
          title: 'Weekly',
          body: _data!.weeklyUsage.asBytes(),
        ),
        BackendPreferenceGroupContent(
          title: 'Monthly',
          body: _data!.monthlyUsage.asBytes(),
        ),
        BackendPreferenceGroupContent(
          title: 'Total',
          body: _data!.totalUsage.asBytes(),
        ),
      ],
    );
  }

  List<Widget> _serverStatistics() {
    return _data!.servers
        .map(
          (server) => [
            LunaHeader(text: server.name),
            BackendPreferenceGroupCard(
              content: [
                BackendPreferenceGroupContent(
                  title: 'Daily',
                  body: server.dailyUsage.asBytes(),
                ),
                BackendPreferenceGroupContent(
                  title: 'Weekly',
                  body: server.weeklyUsage.asBytes(),
                ),
                BackendPreferenceGroupContent(
                  title: 'Monthly',
                  body: server.monthlyUsage.asBytes(),
                ),
                BackendPreferenceGroupContent(
                  title: 'Total',
                  body: server.totalUsage.asBytes(),
                ),
              ],
            ),
          ],
        )
        .expand((element) => element)
        .toList();
  }
}
