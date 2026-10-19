import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules/sabnzbd/core/consolidated_state.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';
import 'package:lunasea/modules/sabnzbd/widgets/history_tile.dart';

class SABnzbdConsolidatedHistory extends StatefulWidget {
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;
  final ScrollController scrollController;

  const SABnzbdConsolidatedHistory({
    super.key,
    required this.refreshIndicatorKey,
    required this.scrollController,
  });

  @override
  State<SABnzbdConsolidatedHistory> createState() =>
      _SABnzbdConsolidatedHistoryState();
}

class _SABnzbdConsolidatedHistoryState extends State<SABnzbdConsolidatedHistory>
    with AutomaticKeepAliveClientMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final TextEditingController _searchController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<SABnzbdConsolidatedState>().historySearchFilter,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final aggregate = context.watch<SABnzbdConsolidatedState>();
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      body: LunaRefreshIndicator(
        context: context,
        key: widget.refreshIndicatorKey,
        onRefresh: aggregate.refreshHistory,
        child: _body(aggregate),
      ),
      appBar: LunaAppBar.empty(
        height: LunaTextInputBar.defaultAppBarHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(
              child: LunaTextInputBar(
                controller: _searchController,
                scrollController: widget.scrollController,
                autofocus: false,
                labelText: 'Search loaded history',
                onChanged: (value) => aggregate.historySearchFilter = value,
                margin: EdgeInsets.zero,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: FilterChip(
                label: const Text('Failed only'),
                selected: aggregate.historyFailedOnly,
                onSelected: (value) => aggregate.historyFailedOnly = value,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(SABnzbdConsolidatedState aggregate) {
    if (aggregate.instanceStates.isNotEmpty &&
        aggregate.instanceStates.every(
          (state) =>
              state.historyUpdatedAt == null && state.historyError == null,
        )) {
      return const LunaLoader();
    }
    final history = aggregate.history;
    final allSourcesResolved = aggregate.instanceStates.every(
      (state) =>
          state.historyUpdatedAt != null &&
          state.historyError == null &&
          !state.historyStale,
    );
    final hasLoadedHistory = aggregate.instanceStates.any(
      (state) => state.historyUpdatedAt != null,
    );
    final filtered =
        aggregate.historySearchFilter.isNotEmpty || aggregate.historyFailedOnly;
    final sources = <String, SABnzbdState>{
      for (var i = 0; i < aggregate.instances.length; i++)
        aggregate.instances[i].ref.key: aggregate.instanceStates[i],
    };
    return LunaListViewBuilder(
      controller: widget.scrollController,
      itemCount: history.length + 1,
      itemBuilder: (context, index) {
        if (index == history.length) {
          return Column(
            children: [
              if (history.isEmpty &&
                  (allSourcesResolved || (filtered && hasLoadedHistory)))
                LunaMessage.inList(
                  key: ValueKey(
                    filtered
                        ? 'sabnzbd-history-no-matches'
                        : 'sabnzbd-history-empty',
                  ),
                  text: filtered
                      ? 'No matching loaded history'
                      : 'No History Found',
                ),
              for (var i = 0; i < aggregate.instances.length; i++)
                _sourceFooter(
                  aggregate.instances[i],
                  aggregate.instanceStates[i],
                ),
            ],
          );
        }
        final record = history[index];
        final owner = sources[record.instance.ref.key]!;
        final available =
            !owner.isDisposed &&
            owner.historyError == null &&
            !owner.historyStale &&
            owner.queueError == null &&
            !owner.queueStale &&
            owner.status != null;
        return SABnzbdHistoryTile(
          key: ValueKey('${record.instance.ref.key}:${record.item.nzoId}'),
          data: record.item,
          state: owner,
          enabled: available,
          sourceLabel: record.instance.displayName,
        );
      },
    );
  }

  Widget _sourceFooter(LunaServiceInstance instance, SABnzbdState state) {
    final historyUnavailable = state.historyError != null || state.historyStale;
    final queueUnavailable = state.queueError != null || state.queueStale;
    final initial = state.historyUpdatedAt == null && !historyUnavailable;
    if (!initial &&
        !historyUnavailable &&
        !queueUnavailable &&
        !state.hasMoreHistory) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        if (initial) ...[
          LunaMessage.inList(
            key: ValueKey('sabnzbd-history-waiting:${instance.ref.key}'),
            text: 'Loading ${instance.displayName} history...',
          ),
          const LunaLoader(),
        ],
        if (historyUnavailable)
          LunaMessage(
            key: ValueKey('sabnzbd-history-error:${instance.ref.key}'),
            text:
                '${instance.displayName}: '
                '${state.historyUpdatedAt == null ? 'History unavailable.' : 'Showing stale history. Actions are disabled.'}'
                '${state.historyError == null ? '' : '\n${state.historyError}'}',
            textColor: Theme.of(context).colorScheme.error,
            buttonText: 'Retry ${instance.displayName} history',
            onTap: state.historyLoading ? null : state.refreshHistory,
            useSafeArea: false,
          ),
        if (queueUnavailable)
          LunaMessage.inList(
            text:
                '${instance.displayName}: Server queue is unavailable. '
                'Actions are disabled.',
          ),
        if (state.hasMoreHistory)
          Padding(
            padding: LunaUI.MARGIN_H_DEFAULT_V_HALF,
            child: Column(
              children: [
                Text(
                  '${instance.displayName}: ${state.history.length} of ${state.historyTotal} records loaded',
                ),
                TextButton(
                  onPressed:
                      !state.isDisposed &&
                          !state.historyLoading &&
                          !historyUnavailable
                      ? state.loadMoreHistory
                      : null,
                  child: Text('Load more from ${instance.displayName}'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
