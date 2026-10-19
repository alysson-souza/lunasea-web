import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sabnzbd.dart';
import 'package:lunasea/modules/sabnzbd/core/action_target.dart';

class SABnzbdQueueTile extends StatefulWidget {
  final int index;
  final SABnzbdQueueData data;
  final SABnzbdState? state;
  final bool enabled;
  final String? sourceLabel;
  final bool reorderable;

  const SABnzbdQueueTile({
    required this.data,
    required this.index,
    this.state,
    this.enabled = true,
    this.sourceLabel,
    this.reorderable = true,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<SABnzbdQueueTile> {
  @override
  Widget build(BuildContext context) {
    return LunaBlock(
      title: widget.data.name,
      body: [
        if (widget.sourceLabel != null) TextSpan(text: widget.sourceLabel),
        TextSpan(text: widget.data.subtitle),
      ],
      bottomHeight: LunaLinearPercentIndicator.height,
      bottom: LunaLinearPercentIndicator(
        percent: min(1.0, max(0, widget.data.percentageDone / 100)),
      ),
      trailing: widget.reorderable && widget.enabled
          ? LunaReorderableListViewDragger(index: widget.index)
          : null,
      onTap: widget.enabled ? _handlePopup : null,
    );
  }

  Future<void> _handlePopup() async {
    if (!widget.enabled) return;
    final data = widget.data;
    final owner = widget.state ?? context.read<SABnzbdState>();
    final sourceName =
        owner.instance?.displayName ?? widget.sourceLabel ?? 'SABnzbd';
    final jobName = data.name;
    try {
      final target = SABnzbdActionTarget.capture(context, state: owner);
      final helper = _Helper(
        context,
        data,
        target,
        () => mounted && widget.enabled,
      );
      final values = await SABnzbdDialogs.queueSettings(
        context,
        jobName,
        data.isPaused,
      );
      if (values[0]) await helper.perform(values[1]);
    } catch (error) {
      showLunaErrorSnackBar(
        title: 'Failed to Update Job ($sourceName: $jobName)',
        error: error,
      );
    }
  }
}

class _Helper {
  final BuildContext context;
  final SABnzbdQueueData data;
  final SABnzbdActionTarget target;
  final bool Function() isEnabled;

  _Helper(this.context, this.data, this.target, this.isEnabled);

  void _validate() {
    if (!isEnabled()) {
      throw StateError('The SABnzbd job is no longer available.');
    }
    target.validate(context);
  }

  Future<void> perform(String action) async {
    _validate();
    switch (action) {
      case 'status':
        await _run(
          (api) => data.isPaused
              ? api.resumeSingleJob(data.nzoId)
              : api.pauseSingleJob(data.nzoId),
          data.isPaused ? 'Job Resumed' : 'Job Paused',
        );
        break;
      case 'category':
        await _category();
        break;
      case 'priority':
        await _priority();
        break;
      case 'password':
        await _password();
        break;
      case 'rename':
        await _rename();
        break;
      case 'delete':
        await _delete();
        break;
      default:
        LunaLogger().warning('Unknown Case: $action');
    }
  }

  Future<void> _run(
    Future<bool> Function(SABnzbdAPI) operation,
    String title, {
    String? message,
  }) async {
    _validate();
    await target.run(context, operation);
    showLunaSuccessSnackBar(title: title, message: message ?? data.name);
  }

  Future<void> _category() async {
    final categories = await target.state.api(context).getCategories();
    _validate();
    final values = await SABnzbdDialogs.changeCategory(context, categories);
    if (values[0]) {
      await _run(
        (api) => api.setCategory(data.nzoId, values[1]),
        values[1] == ''
            ? 'Category Set (No Category)'
            : 'Category Set (${values[1]})',
      );
    }
  }

  Future<void> _priority() async {
    final values = await SABnzbdDialogs.changePriority(context);
    if (values[0]) {
      await _run(
        (api) => api.setJobPriority(data.nzoId, values[1]),
        'Priority Set (${values[2]})',
      );
    }
  }

  Future<void> _rename() async {
    final values = await SABnzbdDialogs.renameJob(context, data.name);
    if (values[0]) {
      await _run(
        (api) => api.renameJob(data.nzoId, values[1]),
        'Job Renamed',
        message: values[1],
      );
    }
  }

  Future<void> _delete() async {
    final values = await SABnzbdDialogs.deleteJob(context);
    if (values[0]) {
      await _run((api) => api.deleteJob(data.nzoId), 'Job Deleted');
    }
  }

  Future<void> _password() async {
    final values = await SABnzbdDialogs.setPassword(context);
    if (values[0]) {
      await _run(
        (api) => api.setJobPassword(data.nzoId, data.name, values[1]),
        'Job Password Set',
      );
    }
  }
}
