import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sabnzbd/core/consolidated_state.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';
import 'package:lunasea/modules/sabnzbd/widgets/queue_tile.dart';

class SABnzbdConsolidatedQueue extends StatelessWidget {
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;
  final ScrollController scrollController;

  const SABnzbdConsolidatedQueue({
    super.key,
    required this.refreshIndicatorKey,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final aggregate = context.watch<SABnzbdConsolidatedState>();
    var loaded = 0;
    var total = 0;
    var showErrors = false;
    var showLoader = false;
    var hasMore = false;
    var canLoadMore = false;
    for (final state in aggregate.instanceStates) {
      loaded += state.queue.length;
      total += state.queueTotal;
      showErrors = showErrors || _showError(state);
      showLoader =
          showLoader || (state.queueUpdatedAt == null && !_showError(state));
      hasMore = hasMore || state.hasMoreQueue;
      canLoadMore =
          canLoadMore || (state.hasMoreQueue && _queueAvailable(state));
    }
    final showEmpty = loaded == 0 && !showLoader && !showErrors;
    final itemCount =
        loaded +
        (showErrors ? 1 : 0) +
        (showLoader ? 1 : 0) +
        (showEmpty ? 1 : 0) +
        (hasMore ? 1 : 0);
    return LunaRefreshIndicator(
      context: context,
      key: refreshIndicatorKey,
      onRefresh: aggregate.refreshQueue,
      child: LunaListViewBuilder(
        controller: scrollController,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (showErrors) {
            if (index == 0) {
              return Padding(
                key: const ValueKey('queue-errors'),
                padding: LunaUI.MARGIN_H_DEFAULT_V_HALF,
                child: Text(
                  [
                    for (
                      var source = 0;
                      source < aggregate.instances.length;
                      source++
                    )
                      if (_showError(aggregate.instanceStates[source]))
                        '${aggregate.instances[source].displayName}: '
                            '${aggregate.instanceStates[source].queueUpdatedAt == null ? 'Queue unavailable.' : 'Queue is stale. Actions are disabled.'}'
                            '${aggregate.instanceStates[source].queueError == null ? '' : ' ${aggregate.instanceStates[source].queueError}'}',
                  ].join('\n'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
            }
            index--;
          }
          for (var source = 0; source < aggregate.instances.length; source++) {
            final instance = aggregate.instances[source];
            final state = aggregate.instanceStates[source];
            if (index < state.queue.length) {
              return SABnzbdQueueTile(
                key: ValueKey(
                  '${instance.ref.key}:${state.queue[index].nzoId}',
                ),
                data: state.queue[index],
                index: index,
                state: state,
                enabled: _actionsAvailable(state),
                sourceLabel: instance.displayName,
                reorderable: false,
              );
            }
            index -= state.queue.length;
          }
          if (showLoader) {
            if (index == 0) return const LunaLoader();
            index--;
          }
          if (showEmpty) {
            if (index == 0) {
              return LunaMessage.inList(
                key: const ValueKey('queue-empty'),
                text: 'Empty Queue',
              );
            }
            index--;
          }
          return Padding(
            key: const ValueKey('queue-pagination'),
            padding: LunaUI.MARGIN_H_DEFAULT_V_HALF,
            child: Column(
              children: [
                Text('$loaded of $total jobs loaded'),
                TextButton(
                  onPressed: canLoadMore ? () => _loadMore(aggregate) : null,
                  child: const Text('Load More'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _showError(SABnzbdState state) =>
      state.isDisposed || state.queueError != null || state.queueStale;

  bool _queueAvailable(SABnzbdState state) =>
      !_showError(state) && state.queueUpdatedAt != null;

  Future<void> _loadMore(SABnzbdConsolidatedState aggregate) async {
    await Future.wait(
      aggregate.instanceStates
          .where((state) => state.hasMoreQueue && _queueAvailable(state))
          .map((state) => state.loadMoreQueue()),
    );
  }

  bool _actionsAvailable(SABnzbdState state) =>
      _queueAvailable(state) && state.status != null;
}
