import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules/dashboard/core/state.dart';
import 'package:lunasea/modules/lidarr/core/state.dart';
import 'package:lunasea/modules/radarr/core/state.dart';
import 'package:lunasea/modules/search/core/state.dart';
import 'package:lunasea/modules/settings/core/state.dart';
import 'package:lunasea/modules/sonarr/core/state.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';
import 'package:lunasea/modules/nzbget/core/state.dart';
import 'package:lunasea/modules/tautulli/core/state.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/router/router.dart';
import 'package:lunasea/system/stores/backend_stores.dart';

class LunaState {
  LunaState._();

  static BuildContext get context => LunaRouter.navigator.currentContext!;

  /// Calls `.reset()` on all states which extend [LunaModuleState].
  static void reset([BuildContext? context]) {
    final ctx = context ?? LunaState.context;
    LunaModule.values.forEach((module) => module.state(ctx)?.reset());
  }

  static MultiProvider providers({required Widget child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfilesStore()),
        ChangeNotifierProvider(create: (_) => SettingsStore()),
        ChangeNotifierProvider(create: (_) => IndexersStore()),
        ChangeNotifierProvider(create: (_) => ExternalModulesStore()),
        ChangeNotifierProvider(create: (_) => DismissedBannersStore()),
        ChangeNotifierProvider(create: (_) => LogsStore()),
        ChangeNotifierProvider(create: (_) => DashboardState()),
        ChangeNotifierProvider(create: (_) => SettingsState()),
        ChangeNotifierProvider(create: (_) => SearchState()),
        ChangeNotifierProvider(
          create: (_) => LunaModuleStateRegistry<LidarrState>(
            create: (instance) => LidarrState(instance: instance),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LunaModuleStateRegistry<RadarrState>(
            create: (instance) => RadarrState(instance: instance),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LunaModuleStateRegistry<SonarrState>(
            create: (instance) => SonarrState(instance: instance),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LunaModuleStateRegistry<NZBGetState>(
            create: (instance) => NZBGetState(instance: instance),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LunaModuleStateRegistry<SABnzbdState>(
            create: (instance) => SABnzbdState(instance: instance),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LunaModuleStateRegistry<TautulliState>(
            create: (instance) => TautulliState(instance: instance),
          ),
        ),
        ChangeNotifierProvider(create: (_) => LidarrState()),
        ChangeNotifierProvider(create: (_) => RadarrState()),
        ChangeNotifierProvider(create: (_) => SonarrState()),
        ChangeNotifierProvider(create: (_) => NZBGetState()),
        ChangeNotifierProvider(create: (_) => SABnzbdState()),
        ChangeNotifierProvider(create: (_) => TautulliState()),
      ],
      child: child,
    );
  }
}

abstract class LunaModuleState extends ChangeNotifier {
  /// Reset the state back to the default
  void reset();
}

class LunaModuleStateRegistry<T extends LunaModuleState>
    extends ChangeNotifier {
  final T Function(LunaServiceInstance instance) create;
  final Map<String, _LunaModuleStateEntry<T>> _states = {};

  LunaModuleStateRegistry({required this.create});

  T get(LunaServiceInstance instance) {
    final key = instance.ref.key;
    final signature = _instanceSignature(instance);
    final current = _states[key];
    if (current != null && current.signature == signature) {
      return current.state;
    }

    current?.state.dispose();
    final state = create(instance);
    _states[key] = _LunaModuleStateEntry(state: state, signature: signature);
    return state;
  }

  void remove(LunaServiceInstanceRef ref) {
    final removed = _states.remove(ref.key);
    if (removed == null) return;
    removed.state.dispose();
    notifyListeners();
  }

  void retainOnly(Iterable<LunaServiceInstanceRef> refs) {
    final keys = refs.map((ref) => ref.key).toSet();
    var changed = false;
    for (final key in _states.keys.toList()) {
      if (keys.contains(key)) continue;
      _states.remove(key)?.state.dispose();
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void sync(Iterable<LunaServiceInstance> instances) {
    final instancesByKey = {
      for (final instance in instances) instance.ref.key: instance,
    };
    var changed = false;
    for (final key in _states.keys.toList()) {
      final instance = instancesByKey[key];
      if (instance == null) {
        _states.remove(key)?.state.dispose();
        changed = true;
        continue;
      }

      final signature = _instanceSignature(instance);
      final current = _states[key]!;
      if (current.signature == signature) continue;

      current.state.dispose();
      _states[key] = _LunaModuleStateEntry(
        state: create(instance),
        signature: signature,
      );
      changed = true;
    }
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    for (final entry in _states.values) {
      entry.state.dispose();
    }
    super.dispose();
  }

  static String _instanceSignature(LunaServiceInstance instance) {
    return jsonEncode(instance.toJson());
  }
}

class _LunaModuleStateEntry<T extends LunaModuleState> {
  final T state;
  final String signature;

  const _LunaModuleStateEntry({required this.state, required this.signature});
}
