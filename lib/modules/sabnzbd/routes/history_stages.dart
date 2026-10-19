import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sabnzbd.dart';
import 'package:lunasea/modules/sabnzbd/core/action_target.dart';
import 'package:lunasea/modules/sabnzbd/core/history_location.dart';
import 'package:lunasea/widgets/pages/invalid_route.dart';

class HistoryStagesRoute extends StatefulWidget {
  final SABnzbdHistoryLocation? location;
  final SABnzbdHistoryData? history;

  const HistoryStagesRoute({super.key, required this.location, this.history});

  @override
  State<HistoryStagesRoute> createState() => _State();
}

class _State extends State<HistoryStagesRoute> with LunaScrollControllerMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Future<SABnzbdHistoryData?>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.location != null) _future = _fetch();
  }

  Future<SABnzbdHistoryData?> _fetch() async {
    final location = widget.location!;
    final target = SABnzbdActionTarget.capture(context);
    if (!location.matches(target.instance, target.instance.profileId))
      return null;
    final history = widget.history;
    if (history != null && history.nzoId == location.nzoId) return history;
    for (final record in target.state.history) {
      if (record.nzoId == location.nzoId) return record;
    }
    final record = await target.state
        .api(context)
        .getHistoryItem(location.nzoId);
    if (!mounted) return null;
    target.validate(context);
    return record?.nzoId == location.nzoId ? record : null;
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.location == null) return _missing();
    return FutureBuilder<SABnzbdHistoryData?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError &&
            snapshot.data == null) {
          return _missing();
        }
        return LunaScaffold(
          scaffoldKey: _scaffoldKey,
          appBar: _appBar(),
          body: snapshot.connectionState != ConnectionState.done
              ? const LunaLoader()
              : snapshot.hasError
              ? LunaMessage.error(onTap: _refresh)
              : _body(snapshot.data!),
        );
      },
    );
  }

  Widget _missing() =>
      InvalidRoutePage(title: 'Stages', message: 'History Record Not Found');

  PreferredSizeWidget _appBar() =>
      LunaAppBar(title: 'Stages', scrollControllers: [scrollController]);

  Widget _body(SABnzbdHistoryData history) {
    final stages = [
      for (final stage in history.stageLog)
        if (stage['actions'] is List && (stage['actions'] as List).isNotEmpty)
          stage,
    ];
    if (stages.isEmpty) return LunaMessage(text: 'No Stage Logs Found');
    return LunaListView(
      controller: scrollController,
      children: [
        for (final stage in stages)
          LunaBlock(
            title: stage['name'],
            body: [
              TextSpan(
                text: (stage['actions'] as List).first.toString().replaceAll(
                  '<br/>',
                  '.\n',
                ),
              ),
            ],
            trailing: const LunaIconButton.arrow(),
            onTap: () => LunaDialogs().textPreview(
              LunaState.context,
              stage['name'],
              (stage['actions'] as List).join(',\n').replaceAll('<br/>', '.\n'),
            ),
          ),
      ],
    );
  }
}
