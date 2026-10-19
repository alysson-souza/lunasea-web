import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sabnzbd.dart';
import 'package:lunasea/modules/sabnzbd/core/action_target.dart';

class SABnzbdQueue extends StatefulWidget {
  static const ROUTE_NAME = '/sabnzbd/queue';
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;
  final ScrollController scrollController;

  const SABnzbdQueue({
    super.key,
    required this.refreshIndicatorKey,
    required this.scrollController,
  });

  @override
  State<SABnzbdQueue> createState() => _State();
}

class _State extends State<SABnzbdQueue> with AutomaticKeepAliveClientMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _moving = false;

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
        onRefresh: state.refreshQueue,
        child: _body(state),
      ),
      floatingActionButton: state.status == null || state.queueStale
          ? null
          : SABnzbdQueueFAB(scrollController: widget.scrollController),
    );
  }

  Widget _body(SABnzbdState state) {
    if (state.queueUpdatedAt == null) {
      if (state.queueError != null) {
        return LunaMessage.error(onTap: state.refreshQueue);
      }
      return const LunaLoader();
    }
    final queue = state.queue;
    final showFooter = state.queueStale || state.hasMoreQueue;
    if (queue.isEmpty) {
      return LunaListView(
        controller: widget.scrollController,
        children: [
          LunaMessage.inList(text: 'Empty Queue'),
          if (showFooter) _pagination(state),
        ],
      );
    }
    final enabled = !state.queueStale && !_moving;
    return LunaReorderableListViewBuilder(
      controller: widget.scrollController,
      onReorder: (oldIndex, newIndex) {
        if (enabled) _reorder(state, oldIndex, newIndex);
      },
      itemCount: queue.length + (showFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == queue.length) {
          return KeyedSubtree(
            key: const ValueKey('queue-pagination'),
            child: _pagination(state),
          );
        }
        final job = queue[index];
        return SABnzbdQueueTile(
          key: ValueKey('${state.instance!.ref.key}:${job.nzoId}'),
          data: job,
          index: index,
          state: state,
          enabled: enabled,
          reorderable: enabled,
        );
      },
    );
  }

  Widget _pagination(SABnzbdState state) {
    return Padding(
      padding: LunaUI.MARGIN_H_DEFAULT_V_HALF,
      child: Column(
        children: [
          if (state.queueStale) ...[
            const Text('Queue unavailable. Showing last successful update.'),
            Text(
              state.queueError.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: state.queueLoading ? null : state.refreshQueue,
              child: const Text('Retry'),
            ),
          ],
          if (state.hasMoreQueue) ...[
            Text('${state.queue.length} of ${state.queueTotal} jobs loaded'),
            TextButton(
              onPressed: state.queueLoading || state.queueStale
                  ? null
                  : state.loadMoreQueue,
              child: const Text('Load More'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _reorder(SABnzbdState state, int oldIndex, int newIndex) async {
    if (_moving || state.queueStale || oldIndex >= state.queue.length) return;
    if (oldIndex < newIndex) newIndex--;
    newIndex = newIndex.clamp(0, state.queue.length - 1).toInt();
    if (oldIndex == newIndex) return;
    final job = state.queue[oldIndex];
    try {
      final target = SABnzbdActionTarget.capture(context, state: state);
      setState(() => _moving = true);
      await target.run(context, (api) => api.moveQueue(job.nzoId, newIndex));
      showLunaSuccessSnackBar(title: 'Moved Job in Queue', message: job.name);
    } catch (error) {
      showLunaErrorSnackBar(title: 'Failed to Move Job', error: error);
    } finally {
      if (mounted) setState(() => _moving = false);
    }
  }
}
