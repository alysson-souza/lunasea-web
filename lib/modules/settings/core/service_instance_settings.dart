import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/system/gateway/connection_mode.dart';
import 'package:lunasea/system/gateway/gateway.dart';

class SettingsServiceInstanceSettings {
  const SettingsServiceInstanceSettings._();

  static LunaServiceInstance newDraft(
    String profileId,
    LunaModule module,
    List<LunaServiceInstance> existing,
  ) {
    final sortOrder = existing.isEmpty
        ? 0
        : existing
                  .map((instance) => instance.sortOrder)
                  .reduce(
                    (value, element) => value > element ? value : element,
                  ) +
              1;
    return LunaServiceInstance(
      id: '',
      profileId: profileId,
      module: module,
      displayName: module.title,
      enabled: false,
      sortOrder: sortOrder,
      connectionMode: LunaConnectionMode.gateway.key,
    );
  }

  static Future<LunaServiceInstance> create(LunaServiceInstance draft) async {
    final created = await LunaGateway.createServiceInstance(
      profile: draft.profileId,
      module: draft.module,
      displayName: draft.displayName,
      enabled: draft.enabled,
      sortOrder: draft.sortOrder,
      connectionMode: draft.connectionMode,
      upstreamUrl: draft.host,
      apiKey: draft.apiKey,
      username: draft.username,
      password: draft.password,
      headers: draft.headers,
      preferences: draft.preferences,
    );
    return LunaServiceInstance.fromJson(created);
  }

  static Future<LunaServiceInstance> save(LunaServiceInstance instance) async {
    final saved = await LunaGateway.patchServiceInstance(instance: instance);
    return LunaServiceInstance.fromJson(saved);
  }

  static Future<void> delete(LunaServiceInstance instance) async {
    await LunaGateway.deleteServiceInstance(instance.ref);
  }

  static Future<void> test(LunaServiceInstance instance) async {
    await LunaGateway.testServiceInstance(instance.ref);
  }
}
