import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/extensions/string/string.dart';
import 'package:lunasea/modules/sabnzbd.dart';
import 'package:lunasea/modules/sabnzbd/core/action_target.dart';
import 'package:lunasea/modules/sabnzbd/core/history_location.dart';
import 'package:lunasea/router/routes/sabnzbd.dart';

class SABnzbdHistoryTile extends StatefulWidget {
  final SABnzbdHistoryData data;
  final SABnzbdState? state;
  final bool enabled;
  final String? sourceLabel;

  const SABnzbdHistoryTile({
    super.key,
    required this.data,
    this.state,
    this.enabled = true,
    this.sourceLabel,
  });

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<SABnzbdHistoryTile> {
  @override
  Widget build(BuildContext context) {
    return LunaExpandableListTile(
      title: widget.data.name,
      collapsedSubtitles: [
        if (widget.sourceLabel != null) TextSpan(text: widget.sourceLabel),
        _subtitle1(),
        _subtitle2(),
      ],
      expandedTableContent: _expandedTableContent(),
      expandedHighlightedNodes: _expandedHighlightedNodes(),
      expandedTableButtons: _expandedButtons(),
      onLongPress: widget.enabled ? _handlePopup : null,
    );
  }

  TextSpan _subtitle1() {
    return TextSpan(
      children: [
        TextSpan(text: widget.data.completeTimeString),
        TextSpan(text: LunaUI.TEXT_BULLET.pad()),
        TextSpan(text: widget.data.sizeReadable),
        TextSpan(text: LunaUI.TEXT_BULLET.pad()),
        TextSpan(text: widget.data.category),
      ],
    );
  }

  TextSpan _subtitle2() {
    return TextSpan(
      text: widget.data.statusString,
      style: TextStyle(
        color: widget.data.statusColor,
        fontWeight: LunaUI.FONT_WEIGHT_BOLD,
      ),
    );
  }

  List<BackendPreferenceGroupContent> _expandedTableContent() {
    return [
      if (widget.sourceLabel != null)
        BackendPreferenceGroupContent(
          title: 'server',
          body: widget.sourceLabel!,
        ),
      BackendPreferenceGroupContent(
        title: 'age',
        body: widget.data.completeTimeString,
      ),
      BackendPreferenceGroupContent(
        title: 'size',
        body: widget.data.sizeReadable,
      ),
      BackendPreferenceGroupContent(
        title: 'category',
        body: widget.data.category,
      ),
      BackendPreferenceGroupContent(
        title: 'path',
        body: widget.data.storageLocation,
      ),
    ];
  }

  List<LunaHighlightedNode> _expandedHighlightedNodes() {
    return [
      LunaHighlightedNode(
        text: widget.data.status,
        backgroundColor: widget.data.statusColor,
      ),
    ];
  }

  List<LunaButton> _expandedButtons() {
    return [
      LunaButton.text(
        text: 'Stages',
        icon: Icons.subject_rounded,
        onTap: widget.enabled ? _enterStages : null,
      ),
      LunaButton.text(
        text: 'Delete',
        icon: Icons.delete_rounded,
        color: LunaColours.red,
        onTap: widget.enabled ? () => _handleAction('delete') : null,
      ),
    ];
  }

  Future<void> _withTarget(
    Future<void> Function(SABnzbdActionTarget, SABnzbdHistoryData) action,
  ) async {
    if (!widget.enabled) return;
    final owner = widget.state ?? context.read<SABnzbdState>();
    final sourceName =
        owner.instance?.displayName ?? widget.sourceLabel ?? 'SABnzbd';
    final jobName = widget.data.name;
    try {
      final target = SABnzbdActionTarget.capture(context, state: owner);
      await action(target, widget.data);
    } catch (error) {
      showLunaErrorSnackBar(
        title: 'Failed to Update History ($sourceName: $jobName)',
        error: error,
      );
    }
  }

  void _validate(SABnzbdActionTarget target) {
    if (!mounted || !widget.enabled) {
      throw StateError('The SABnzbd history item is no longer available.');
    }
    target.validate(context);
  }

  Future<void> _enterStages() async {
    await _withTarget((target, data) async {
      _validate(target);
      SABnzbdRoutes.HISTORY_STAGES.goInstance(
        instanceId: target.instance.id,
        queryParams: SABnzbdHistoryLocation.forInstance(
          target.instance,
          data.nzoId,
        ).queryParameters,
        extra: data,
        buildTree: false,
      );
    });
  }

  Future<void> _handlePopup() async {
    await _withTarget((target, data) async {
      final values = await SABnzbdDialogs.historySettings(
        context,
        data.name,
        data.failed,
      );
      if (values[0]) await _performAction(target, data, values[1]);
    });
  }

  Future<void> _handleAction(String action) async {
    await _withTarget((target, data) => _performAction(target, data, action));
  }

  Future<void> _performAction(
    SABnzbdActionTarget target,
    SABnzbdHistoryData data,
    String action,
  ) async {
    _validate(target);
    switch (action) {
      case 'delete':
        final deleteValues = await SABnzbdDialogs.deleteHistory(context);
        if (deleteValues[0]) {
          await _run(
            target,
            data,
            (api) => api.deleteHistory(data.nzoId),
            'History Deleted',
          );
        }
        break;
      case 'password':
        final passwordValues = await SABnzbdDialogs.setPassword(context);
        if (passwordValues[0]) {
          await _run(
            target,
            data,
            (api) => api.retryFailedJobPassword(data.nzoId, passwordValues[1]),
            'Password Set / Retrying...',
          );
        }
        break;
      case 'retry':
        await _run(
          target,
          data,
          (api) => api.retryFailedJob(data.nzoId),
          'Retrying Job',
        );
        break;
      default:
        LunaLogger().warning('Unknown Case: $action');
    }
  }

  Future<void> _run(
    SABnzbdActionTarget target,
    SABnzbdHistoryData data,
    Future<bool> Function(SABnzbdAPI) operation,
    String title,
  ) async {
    _validate(target);
    await target.run(context, operation, refreshHistory: true);
    showLunaSuccessSnackBar(title: title, message: data.name);
  }
}
