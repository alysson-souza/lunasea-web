import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/extensions/int/duration.dart';
import 'package:lunasea/extensions/string/links.dart';
import 'package:lunasea/modules/sabnzbd/core/action_target.dart';
import 'package:lunasea/modules/sabnzbd/core/dialogs.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';
import 'package:lunasea/router/routes/sabnzbd.dart';
import 'package:lunasea/system/filesystem/file.dart';
import 'package:lunasea/system/filesystem/filesystem.dart';

class SABnzbdServerActions {
  SABnzbdServerActions._();

  static Future<void> show(BuildContext context, SABnzbdState state) =>
      _withTarget(context, state, 'Server Action Failed', (target) async {
        final action = await _menu(context, target);
        if (action == null) return;
        target.validate(context);
        switch (action) {
          case 'web_gui':
            await target.instance.host.openLink();
          case 'add_nzb':
            await _addNzb(context, target);
          case 'pause':
            await _toggle(context, target, wasPaused: false);
          case 'resume':
            await _toggle(context, target, wasPaused: true);
          case 'pause_for':
            await _pauseFor(context, target);
          case 'speed_limit':
            await _speedLimit(context, target);
          case 'sort':
            await _sort(context, target);
          case 'clear_history':
            await _clearHistory(context, target);
          case 'complete_action':
            await _completeAction(context, target);
          case 'server_details':
            SABnzbdRoutes.STATISTICS.goInstance(
              instanceId: target.instance.id,
              buildTree: false,
            );
        }
      });

  static Future<void> toggle(BuildContext context, SABnzbdState state) =>
      _withTarget(
        context,
        state,
        'Failed to Change Queue Status',
        (target) => _toggle(context, target),
      );

  static Future<void> pauseFor(BuildContext context, SABnzbdState state) =>
      _withTarget(
        context,
        state,
        'Failed to Pause Queue',
        (target) => _pauseFor(context, target),
      );

  static Future<void> speedLimit(BuildContext context, SABnzbdState state) =>
      _withTarget(
        context,
        state,
        'Failed to Set Speed Limit',
        (target) => _speedLimit(context, target),
      );

  static Future<void> addNzb(BuildContext context, SABnzbdState state) =>
      _withTarget(
        context,
        state,
        'Failed to Upload NZB',
        (target) => _addNzb(context, target),
      );

  static Future<void> _withTarget(
    BuildContext context,
    SABnzbdState state,
    String failureTitle,
    Future<void> Function(SABnzbdActionTarget) operation,
  ) async {
    SABnzbdActionTarget? target;
    try {
      target = SABnzbdActionTarget.capture(context, state: state);
      target.validate(context);
      await operation(target);
    } catch (error) {
      final name =
          target?.instance.displayName ??
          state.instance?.displayName ??
          'SABnzbd';
      showLunaErrorSnackBar(title: '$failureTitle ($name)', error: error);
    }
  }

  static bool _isAvailable(SABnzbdState state) =>
      !state.isDisposed &&
      !state.error &&
      !state.queueStale &&
      state.status != null;

  static void _validateAvailable(
    BuildContext context,
    SABnzbdActionTarget target,
  ) {
    target.validate(context);
    if (!_isAvailable(target.state)) {
      throw StateError('${target.instance.displayName} is unavailable.');
    }
  }

  static Future<String?> _menu(
    BuildContext context,
    SABnzbdActionTarget target,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final options = <(String, IconData, String)>[
      ('View Web GUI', Icons.language_rounded, 'web_gui'),
      ('Add NZB', Icons.add_rounded, 'add_nzb'),
      (
        target.state.paused ? 'Resume Queue' : 'Pause Queue',
        target.state.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
        target.state.paused ? 'resume' : 'pause',
      ),
      ('Pause Queue For...', Icons.access_time_rounded, 'pause_for'),
      ('Speed Limit', Icons.speed_rounded, 'speed_limit'),
      ('Sort Queue', Icons.sort_rounded, 'sort'),
      ('Clear History', Icons.clear_all_rounded, 'clear_history'),
      ('On Complete Action', Icons.settings_power_rounded, 'complete_action'),
      ('Status & Statistics', Icons.info_outline_rounded, 'server_details'),
    ];
    bool enabled(String action) =>
        _isAvailable(target.state) ||
        action == 'web_gui' ||
        action == 'server_details';
    String? action;
    await LunaDialog.dialog(
      context: context,
      title: target.instance.displayName,
      content: [
        for (var index = 0; index < options.length; index++)
          Opacity(
            opacity: enabled(options[index].$3) ? 1.0 : 0.4,
            child: LunaDialog.tile(
              text: options[index].$1,
              icon: options[index].$2,
              iconColor: LunaColours().byListIndex(index),
              onTap: enabled(options[index].$3)
                  ? () {
                      action = options[index].$3;
                      navigator.pop();
                    }
                  : null,
            ),
          ),
      ],
      contentPadding: LunaDialog.listDialogContentPadding(),
    );
    return action;
  }

  static Future<void> _toggle(
    BuildContext context,
    SABnzbdActionTarget target, {
    bool? wasPaused,
  }) async {
    _validateAvailable(context, target);
    HapticFeedback.lightImpact();
    final paused = wasPaused ?? target.state.paused;
    await target.run(
      context,
      (api) => paused ? api.resumeQueue() : api.pauseQueue(),
    );
  }

  static Future<void> _pauseFor(
    BuildContext context,
    SABnzbdActionTarget target,
  ) async {
    _validateAvailable(context, target);
    HapticFeedback.heavyImpact();
    var values = await SABnzbdDialogs.pauseFor(context);
    if (values[0] != true) return;
    if (values[1] == -1) {
      _validateAvailable(context, target);
      values = await SABnzbdDialogs.customPauseFor(context);
      if (values[0] != true) return;
    }
    final minutes = values[1] as int;
    _validateAvailable(context, target);
    await target.run(context, (api) => api.pauseQueueFor(minutes));
    showLunaSuccessSnackBar(
      title: 'Pausing Queue',
      message:
          '${target.instance.displayName}: For ${minutes.asWordDuration(multiplier: 60)}',
    );
  }

  static Future<void> _speedLimit(
    BuildContext context,
    SABnzbdActionTarget target,
  ) async {
    _validateAvailable(context, target);
    HapticFeedback.lightImpact();
    var values = await SABnzbdDialogs.speedLimit(
      context,
      target.state.speedLimit,
    );
    if (values[0] != true) return;
    if (values[1] == -1) {
      _validateAvailable(context, target);
      values = await SABnzbdDialogs.customSpeedLimit(context);
      if (values[0] != true) return;
    }
    final limit = values[1] as int;
    _validateAvailable(context, target);
    await target.run(context, (api) => api.setSpeedLimit(limit));
    showLunaSuccessSnackBar(
      title: 'Speed Limit Set',
      message: '${target.instance.displayName}: Set to $limit%',
    );
  }

  static Future<void> _sort(
    BuildContext context,
    SABnzbdActionTarget target,
  ) async {
    _validateAvailable(context, target);
    final values = await SABnzbdDialogs.sortQueue(context);
    if (values[0] != true) return;
    _validateAvailable(context, target);
    await target.run(context, (api) => api.sortQueue(values[1], values[2]));
    showLunaSuccessSnackBar(
      title: 'Sorted Queue',
      message: '${target.instance.displayName}: ${values[3]}',
    );
  }

  static Future<void> _clearHistory(
    BuildContext context,
    SABnzbdActionTarget target,
  ) async {
    _validateAvailable(context, target);
    final values = await SABnzbdDialogs.clearAllHistory(context);
    if (values[0] != true) return;
    _validateAvailable(context, target);
    await target.run(
      context,
      (api) => api.clearHistory(values[1], values[2]),
      refreshHistory: true,
    );
    showLunaSuccessSnackBar(
      title: 'History Cleared',
      message: '${target.instance.displayName}: ${values[3]}',
    );
  }

  static Future<void> _completeAction(
    BuildContext context,
    SABnzbdActionTarget target,
  ) async {
    _validateAvailable(context, target);
    final values = await SABnzbdDialogs.changeOnCompleteAction(context);
    if (values[0] != true) return;
    _validateAvailable(context, target);
    await target.run(context, (api) => api.setOnCompleteAction(values[1]));
    showLunaSuccessSnackBar(
      title: 'On Complete Action Set',
      message: '${target.instance.displayName}: ${values[2]}',
    );
  }

  static Future<void> _addNzb(
    BuildContext context,
    SABnzbdActionTarget target,
  ) async {
    _validateAvailable(context, target);
    final values = await SABnzbdDialogs.addNZB(context);
    if (values[0] != true) return;
    _validateAvailable(context, target);
    switch (values[1]) {
      case 'link':
        final url = await SABnzbdDialogs.addNZBUrl(context);
        if (url[0] != true) return;
        _validateAvailable(context, target);
        await target.run(context, (api) => api.uploadURL(url[1]));
        showLunaSuccessSnackBar(
          title: 'Uploaded NZB (URL)',
          message: '${target.instance.displayName}: ${url[1]}',
        );
      case 'file':
        final LunaFile? file = await LunaFileSystem().read(context, [
          'nzb',
          'zip',
          'rar',
          'gz',
        ]);
        if (file == null) return;
        _validateAvailable(context, target);
        if (file.data.isEmpty) {
          throw StateError('Please select a valid file type.');
        }
        await target.run(
          context,
          (api) => api.uploadFile(file.data, file.name),
        );
        showLunaSuccessSnackBar(
          title: 'Uploaded NZB (File)',
          message: '${target.instance.displayName}: ${file.name}',
        );
    }
  }
}
