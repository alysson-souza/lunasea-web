import 'package:lunasea/modules.dart';
import 'package:lunasea/system/gateway/connection_mode.dart';

class LunaServiceInstanceRef {
  final String profileId;
  final LunaModule module;
  final String instanceId;

  const LunaServiceInstanceRef({
    required this.profileId,
    required this.module,
    required this.instanceId,
  });

  String get key => '$profileId:${module.key}:$instanceId';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LunaServiceInstanceRef &&
            other.profileId == profileId &&
            other.module == module &&
            other.instanceId == instanceId;
  }

  @override
  int get hashCode => Object.hash(profileId, module, instanceId);
}

class LunaServiceInstance {
  final String id;
  final String profileId;
  final LunaModule module;
  final String displayName;
  final bool enabled;
  final int sortOrder;
  final String connectionMode;
  final String host;
  final String apiKey;
  final String username;
  final String password;
  final bool hasApiKey;
  final bool hasUsername;
  final bool hasPassword;
  final Map<String, String> headers;
  final Map<String, dynamic> preferences;

  LunaServiceInstance({
    required this.id,
    this.profileId = 'default',
    required this.module,
    String? displayName,
    this.enabled = false,
    this.sortOrder = 0,
    String? connectionMode,
    this.host = '',
    this.apiKey = '',
    this.username = '',
    this.password = '',
    bool? hasApiKey,
    bool? hasUsername,
    bool? hasPassword,
    Map<String, String> headers = const {},
    Map<String, dynamic> preferences = const {},
  }) : displayName = displayName ?? id,
       connectionMode = connectionMode ?? LunaConnectionMode.direct.key,
       hasApiKey = hasApiKey ?? apiKey.isNotEmpty,
       hasUsername = hasUsername ?? username.isNotEmpty,
       hasPassword = hasPassword ?? password.isNotEmpty,
       headers = Map<String, String>.from(headers),
       preferences = _dynamicMap(preferences);

  LunaServiceInstanceRef get ref => LunaServiceInstanceRef(
    profileId: profileId,
    module: module,
    instanceId: id,
  );

  String get key => ref.key;

  T preference<T>(String key, T fallback) {
    final value = preferences[key];
    return value is T ? value : fallback;
  }

  void setPreference(String key, dynamic value) {
    preferences[key] = _deepCopy(value);
  }

  factory LunaServiceInstance.fromJson(Map<String, dynamic> json) {
    final module = LunaModule.fromKey(json['service']?.toString());
    if (module == null) {
      throw ArgumentError.value(
        json['service'],
        'service',
        'Unsupported service key',
      );
    }

    return LunaServiceInstance(
      id: json['id']?.toString() ?? '',
      profileId: json['profile']?.toString() ?? 'default',
      module: module,
      displayName: json['displayName']?.toString(),
      enabled: json['enabled'] == true,
      sortOrder: _sortOrder(json['sortOrder']),
      connectionMode: json['connectionMode']?.toString(),
      host: json['upstreamUrl']?.toString() ?? '',
      apiKey: json['apiKey']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      hasApiKey:
          json['hasApiKey'] == true ||
          (json['apiKey']?.toString().isNotEmpty ?? false),
      hasUsername:
          json['hasUsername'] == true ||
          (json['username']?.toString().isNotEmpty ?? false),
      hasPassword:
          json['hasPassword'] == true ||
          (json['password']?.toString().isNotEmpty ?? false),
      headers: _stringMap(json['headers']),
      preferences: _dynamicMap(json['preferences']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'profile': profileId,
    'service': module.key,
    'displayName': displayName,
    'enabled': enabled,
    'sortOrder': sortOrder,
    'connectionMode': connectionMode,
    'upstreamUrl': host,
    if (apiKey.isNotEmpty) 'apiKey': apiKey,
    if (username.isNotEmpty) 'username': username,
    if (password.isNotEmpty) 'password': password,
    'hasApiKey': hasApiKey,
    'hasUsername': hasUsername,
    'hasPassword': hasPassword,
    'headers': Map<String, String>.from(headers),
    'preferences': _dynamicMap(preferences),
  };

  static int _sortOrder(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static Map<String, String> _stringMap(dynamic value) {
    if (value is! Map) return {};
    return value.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  static Map<String, dynamic> _dynamicMap(dynamic value) {
    if (value is! Map) return {};
    return value.map(
      (key, value) => MapEntry(key.toString(), _deepCopy(value)),
    );
  }

  static dynamic _deepCopy(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(key.toString(), _deepCopy(value)),
      );
    }
    if (value is List) {
      return value.map(_deepCopy).toList();
    }
    return value;
  }
}
