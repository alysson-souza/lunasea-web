import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sabnzbd.dart';

class SABnzbdHistory extends StatefulWidget {
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;
  final ScrollController scrollController;

  const SABnzbdHistory({
    super.key,
    required this.refreshIndicatorKey,
    required this.scrollController,
  });

  @override
  State<SABnzbdHistory> createState() => _State();
}

class _State extends State<SABnzbdHistory> with AutomaticKeepAliveClientMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = context.watch<SABnzbdState>();
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      body: LunaRefreshIndicator(
        context: context,
        key: widget.refreshIndicatorKey,
        onRefresh: state.refreshHistory,
        child: _body(state),
      ),
      appBar: LunaAppBar.empty(
        child: SABnzbdHistorySearchBar(
          scrollController: widget.scrollController,
        ),
        height: LunaTextInputBar.defaultAppBarHeight,
      ),
    );
  }

  Widget _body(SABnzbdState state) {
    if (state.historyUpdatedAt == null && state.historyError == null) {
      return const LunaLoader();
    }
    if (state.historyUpdatedAt == null && state.historyError != null) {
      return LunaMessage.error(onTap: state.refreshHistory);
    }
    final search = state.historySearchFilter.toLowerCase();
    final filtered = state.history.where((entry) {
      return (search.isEmpty || entry.name.toLowerCase().contains(search)) &&
          (!state.historyHideFailed || entry.failed);
    }).toList();
    final enabled = !state.historyStale && !state.queueStale;
    final showFooter =
        state.historyStale || state.queueStale || state.hasMoreHistory;
    return LunaListViewBuilder(
      controller: widget.scrollController,
      itemCount: filtered.length + (filtered.isEmpty || showFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == filtered.length) {
          return Column(
            children: [
              if (filtered.isEmpty)
                LunaMessage.inList(text: 'No History Found'),
              if (showFooter) _pagination(state),
            ],
          );
        }
        final job = filtered[index];
        return SABnzbdHistoryTile(
          key: ValueKey('${state.instance!.ref.key}:${job.nzoId}'),
          data: job,
          state: state,
          enabled: enabled,
        );
      },
    );
  }

  Widget _pagination(SABnzbdState state) {
    return Padding(
      padding: LunaUI.MARGIN_H_DEFAULT_V_HALF,
      child: Column(
        children: [
          if (state.historyStale) ...[
            const Text('History unavailable. Showing last successful update.'),
            Text(
              state.historyError.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: state.historyLoading ? null : state.refreshHistory,
              child: const Text('Retry'),
            ),
          ],
          if (state.queueStale)
            const Text('Queue unavailable. History actions are disabled.'),
          if (state.hasMoreHistory) ...[
            Text(
              '${state.history.length} of ${state.historyTotal} records loaded',
            ),
            TextButton(
              onPressed: state.historyLoading || state.historyStale
                  ? null
                  : state.loadMoreHistory,
              child: const Text('Load More'),
            ),
          ],
        ],
      ),
    );
  }
}
