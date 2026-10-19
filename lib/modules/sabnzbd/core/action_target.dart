import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/sabnzbd/core/api.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:provider/provider.dart';

class SABnzbdActionTarget {
  final LunaServiceInstance instance;
  final SABnzbdState state;
  final String _configuration;

  SABnzbdActionTarget._(this.instance, this.state)
    : _configuration = jsonEncode(instance.toJson());

  factory SABnzbdActionTarget.capture(
    BuildContext context, {
    SABnzbdState? state,
  }) {
    if (!context.mounted) {
      throw StateError('The SABnzbd action is no longer available.');
    }
    final owner = state ?? context.read<SABnzbdState>();
    final instance = owner.instance;
    if (instance == null) {
      throw StateError('No SABnzbd action owner is configured.');
    }
    final target = SABnzbdActionTarget._(instance, owner);
    target.validate(context);
    return target;
  }

  void validate(BuildContext context) {
    if (!context.mounted || state.isDisposed) {
      throw StateError('The SABnzbd action is no longer available.');
    }
    final profiles = context.read<ProfilesStore>();
    if (profiles.activeProfile != instance.profileId ||
        instance.module != LunaModule.SABNZBD) {
      throw StateError('The SABnzbd action owner is no longer active.');
    }
    final matches = profiles
        .enabledInstances(instance.profileId, LunaModule.SABNZBD)
        .where((candidate) => candidate.ref == instance.ref);
    if (matches.isEmpty) {
      throw StateError('The SABnzbd action owner is no longer enabled.');
    }
    final current = matches.first;
    if (current.host.trim().isEmpty ||
        jsonEncode(current.toJson()) != _configuration ||
        jsonEncode(instance.toJson()) != _configuration) {
      throw StateError('The SABnzbd action owner configuration has changed.');
    }
  }

  Future<void> run(
    BuildContext context,
    Future<bool> Function(SABnzbdAPI) operation, {
    bool refreshHistory = false,
  }) async {
    validate(context);
    final result = await operation(state.api(context));
    if (!result) {
      throw StateError('SABnzbd rejected the requested action.');
    }
    await Future.wait([
      state.refreshQueue(force: true),
      if (refreshHistory) state.refreshHistory(force: true),
    ]);
  }
}
