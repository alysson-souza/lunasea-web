import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/radarr/core/state.dart';
import 'package:lunasea/system/state.dart';

void main() {
  test('RadarrState resolves endpoint from its service instance', () {
    final nas = LunaServiceInstance(
      id: 'nas-films',
      profileId: 'default',
      module: LunaModule.RADARR,
      displayName: 'NAS Films',
      host: 'https://nas.example/radarr',
      apiKey: 'nas-key',
    );
    final seedbox = LunaServiceInstance(
      id: 'seedbox-films',
      profileId: 'default',
      module: LunaModule.RADARR,
      displayName: 'Seedbox Films',
      host: 'https://seedbox.example/radarr',
      apiKey: 'seedbox-key',
    );

    final nasState = RadarrState(instance: nas)..resetProfile();
    final seedboxState = RadarrState(instance: seedbox)..resetProfile();

    expect(nasState.host, 'https://nas.example/radarr');
    expect(seedboxState.host, 'https://seedbox.example/radarr');
    expect(nasState.apiKey, 'nas-key');
    expect(seedboxState.apiKey, 'seedbox-key');
  });

  test('state registry recreates state when instance config changes', () {
    final registry = LunaModuleStateRegistry<_FakeModuleState>(
      create: (instance) => _FakeModuleState(instance),
    );
    addTearDown(registry.dispose);

    final first = registry.get(
      LunaServiceInstance(
        id: 'nas-films',
        profileId: 'default',
        module: LunaModule.RADARR,
        host: 'https://old.example/radarr',
      ),
    );
    final second = registry.get(
      LunaServiceInstance(
        id: 'nas-films',
        profileId: 'default',
        module: LunaModule.RADARR,
        host: 'https://new.example/radarr',
      ),
    );

    expect(identical(first, second), isFalse);
    expect(first.disposed, isTrue);
    expect(second.host, 'https://new.example/radarr');
  });

  test('state registry disposes states for removed refs', () {
    final registry = LunaModuleStateRegistry<_FakeModuleState>(
      create: (instance) => _FakeModuleState(instance),
    );
    addTearDown(registry.dispose);

    final nas = LunaServiceInstance(
      id: 'nas-films',
      profileId: 'default',
      module: LunaModule.RADARR,
    );
    final seedbox = LunaServiceInstance(
      id: 'seedbox-films',
      profileId: 'default',
      module: LunaModule.RADARR,
    );
    final nasState = registry.get(nas);
    final seedboxState = registry.get(seedbox);

    registry.retainOnly([seedbox.ref]);

    expect(nasState.disposed, isTrue);
    expect(identical(registry.get(seedbox), seedboxState), isTrue);
  });

  test('state registry sync does not create uncached states', () {
    var created = 0;
    final registry = LunaModuleStateRegistry<_FakeModuleState>(
      create: (instance) {
        created++;
        return _FakeModuleState(instance);
      },
    );
    addTearDown(registry.dispose);

    final nas = LunaServiceInstance(
      id: 'nas-films',
      profileId: 'default',
      module: LunaModule.RADARR,
      host: 'https://nas.example/radarr',
    );

    registry.sync([nas]);

    expect(created, 0);
  });
}

class _FakeModuleState extends LunaModuleState {
  final String host;
  bool disposed = false;

  _FakeModuleState(LunaServiceInstance instance) : host = instance.host;

  @override
  void reset() {}

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
