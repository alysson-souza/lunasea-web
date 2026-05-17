import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/database/models/log.dart';
import 'package:lunasea/modules/settings/routes/system_logs/widgets/log_tile.dart';
import 'package:lunasea/types/log_type.dart';

class SystemLogsDetailsRoute extends StatefulWidget {
  final LunaLogType? type;

  const SystemLogsDetailsRoute({super.key, required this.type});

  @override
  State<SystemLogsDetailsRoute> createState() => _State();
}

class _State extends State<SystemLogsDetailsRoute>
    with LunaScrollControllerMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: _appBar(),
      body: _body(),
    );
  }

  PreferredSizeWidget _appBar() {
    return LunaAppBar(
      title: 'settings.Logs'.tr(),
      scrollControllers: [scrollController],
    );
  }

  Widget _body() {
    return Consumer<LogsStore>(
      builder: (context, logsStore, _) {
        List<LunaLog> logs = filter(logsStore);
        if (logs.isEmpty) {
          return LunaMessage.goBack(
            context: context,
            text: 'settings.NoLogsFound'.tr(),
          );
        }
        return LunaListViewBuilder(
          controller: scrollController,
          itemCount: logs.length,
          itemBuilder: (context, index) =>
              SettingsSystemLogTile(log: logs[index]),
        );
      },
    );
  }

  List<LunaLog> filter(LogsStore store) {
    List<LunaLog> logs;

    switch (widget.type) {
      case LunaLogType.WARNING:
        logs = store.logs
            .where((log) => log.type == LunaLogType.WARNING)
            .toList();
        break;
      case LunaLogType.ERROR:
        logs = store.logs
            .where((log) => log.type == LunaLogType.ERROR)
            .toList();
        break;
      case LunaLogType.CRITICAL:
        logs = store.logs
            .where((log) => log.type == LunaLogType.CRITICAL)
            .toList();
        break;
      case LunaLogType.DEBUG:
        logs = store.logs
            .where((log) => log.type == LunaLogType.DEBUG)
            .toList();
        break;
      default:
        logs = store.logs.where((log) => log.type.enabled).toList();
        break;
    }
    logs.sort((a, b) => (b.timestamp).compareTo(a.timestamp));
    return logs;
  }
}
