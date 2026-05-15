import 'package:dio/dio.dart';
import 'package:lunasea/database/models/external_module.dart';
import 'package:lunasea/database/models/indexer.dart';
import 'package:lunasea/database/models/log.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/system/gateway/connection_mode.dart';
import 'package:lunasea/vendor.dart';

class LunaBackendClient {
  final Dio dio;

  LunaBackendClient({
    Dio? dio,
  }) : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: '/_lunasea/api/',
                connectTimeout: const Duration(seconds: 2),
                receiveTimeout: const Duration(seconds: 10),
                responseType: ResponseType.json,
                contentType: Headers.jsonContentType,
              ),
            );

  Future<Map<String, dynamic>> fetchState() async {
    final response = await dio.get('state');
    return Map<String, dynamic>.from(response.data as Map);
  }

  String indexerBasePath(int id) => '/_lunasea/api/indexers/$id/';
}

class LunaGateway {
  LunaGateway._();

  static final LunaBackendClient _client = LunaBackendClient();
  static Dio get _dio => _client.dio;

  static bool _available = false;
  static bool get available => _available;

  static Map<String, dynamic> _state = {};
  static Map<String, dynamic> get state => _state;

  static Future<void> initialize() async {
    try {
      _state = await _client.fetchState();
      _available = _state['gateway'] == true;
    } catch (_) {
      _state = {};
      _available = false;
    }
  }

  static Map<String, dynamic>? serviceConnection({
    required LunaModule module,
    required String profile,
  }) {
    final connections = (_state['serviceConnections'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    for (final connection in connections) {
      if (connection['service'] == module.key &&
          connection['profile'] == profile) {
        return connection;
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchServiceConnection({
    required LunaModule module,
    required String profile,
  }) async {
    final response = await _dio.get('services');
    _cacheServices(
      (response.data['services'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
    return serviceConnection(module: module, profile: profile);
  }

  static Future<Map<String, dynamic>> putService({
    required LunaModule module,
    required String profile,
    String? upstreamUrl,
    String? apiKey,
    String? username,
    String? password,
    Map<String, String>? headers,
  }) async {
    final data = <String, dynamic>{
      if (upstreamUrl != null) 'upstreamUrl': upstreamUrl,
      if (apiKey != null) 'apiKey': apiKey,
      if (username != null) 'username': username,
      if (password != null) 'password': password,
      if (headers != null) 'headers': headers,
    };
    final response = await _dio.put(
      'profiles/$profile/services/${module.key}',
      data: data,
    );
    final service = Map<String, dynamic>.from(response.data);
    _cacheService(service);
    return service;
  }

  static Future<void> testService({
    required LunaModule module,
    required String profile,
  }) async {
    await _dio.post('services/${module.key}/$profile/test');
  }

  static Future<void> deleteService({
    required LunaModule module,
    required String profile,
  }) async {
    await _dio.delete('profiles/$profile/services/${module.key}');
    _removeCachedService(module: module, profile: profile);
  }

  static void _cacheServices(List<Map<String, dynamic>> services) {
    _state = Map<String, dynamic>.from(_state)
      ..['serviceConnections'] = services;
  }

  static void _cacheService(Map<String, dynamic> service) {
    final services = (_state['serviceConnections'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((item) =>
            item['service'] != service['service'] ||
            item['profile'] != service['profile'])
        .toList()
      ..add(service);
    _cacheServices(services);
  }

  static void _removeCachedService({
    required LunaModule module,
    required String profile,
  }) {
    final services = (_state['serviceConnections'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((item) =>
            item['service'] != module.key || item['profile'] != profile)
        .toList();
    _cacheServices(services);
  }

  static Future<void> createProfile(String id) async {
    await _dio.post('profiles', data: {'id': id, 'displayName': id});
  }

  static Future<void> updateProfile(String id, LunaProfile profile) async {
    await _dio.patch('profiles/$id', data: {'displayName': id});
    for (final module in _serviceModules) {
      final draft = _serviceDraft(profile, module);
      if (!draft.enabled) {
        try {
          await deleteService(module: module, profile: id);
        } on DioException catch (error) {
          if (error.response?.statusCode != 503 &&
              error.response?.statusCode != 404) rethrow;
        }
        continue;
      }
      if (draft.host.isEmpty) continue;
      await putService(
        module: module,
        profile: id,
        upstreamUrl: draft.host,
        apiKey: draft.apiKey.isEmpty ? null : draft.apiKey,
        username: draft.username.isEmpty ? null : draft.username,
        password: draft.password.isEmpty ? null : draft.password,
        headers: draft.headers,
      );
      _markGateway(profile, module, id);
    }
  }

  static Future<void> deleteProfile(String id) async {
    await _dio.delete('profiles/$id');
  }

  static Future<void> patchAppPreferences(Map<String, dynamic> patch) async {
    await _dio.patch('preferences/app', data: patch);
  }

  static Future<void> patchModulePreferences(
    LunaModule module,
    Map<String, dynamic> patch,
  ) async {
    await patchModulePreferencesKey(module.key, patch);
  }

  static Future<void> patchModulePreferencesKey(
    String module,
    Map<String, dynamic> patch,
  ) async {
    await _dio.patch('preferences/modules/$module', data: patch);
  }

  static Future<Tuple2<int, LunaIndexer>> createIndexer(
    LunaIndexer indexer,
  ) async {
    final response = await _dio.post('indexers', data: _indexerJson(indexer));
    final data = Map<String, dynamic>.from(response.data as Map);
    indexer.id = (data['id'] as num).toInt();
    _redactIndexerSecrets(indexer);
    return Tuple2(indexer.id, indexer);
  }

  static Future<void> updateIndexer(int id, LunaIndexer indexer) async {
    await _dio.patch('indexers/$id', data: _indexerJson(indexer));
    _redactIndexerSecrets(indexer);
  }

  static Future<void> deleteIndexer(int id) async {
    await _dio.delete('indexers/$id');
  }

  static String indexerBasePath(int id) => _client.indexerBasePath(id);

  static Future<Tuple2<int, LunaExternalModule>> createExternalModule(
    LunaExternalModule module,
  ) async {
    final response = await _dio.post('external-modules', data: module.toJson());
    final data = Map<String, dynamic>.from(response.data as Map);
    module.id = (data['id'] as num).toInt();
    return Tuple2(module.id, module);
  }

  static Future<void> updateExternalModule(
    int id,
    LunaExternalModule module,
  ) async {
    await _dio.patch('external-modules/$id', data: module.toJson());
  }

  static Future<void> deleteExternalModule(int id) async {
    await _dio.delete('external-modules/$id');
  }

  static Future<void> dismissBanner(String key) async {
    await _dio.put('banners/$key');
  }

  static Future<void> undismissBanner(String key) async {
    await _dio.delete('banners/$key');
  }

  static Future<Tuple2<int, LunaLog>> createLog(LunaLog log) async {
    final response = await _dio.post('logs', data: {
      'timestamp': log.timestamp,
      'type': (log.type as dynamic).key,
      'className': log.className ?? '',
      'methodName': log.methodName ?? '',
      'message': log.message,
      'error': log.error ?? '',
      'stackTrace': log.stackTrace?.trim().split('\n') ?? [],
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    return Tuple2((data['id'] as num).toInt(), log);
  }

  static Future<void> clearLogs() async {
    await _dio.delete('logs');
  }

  static Map<String, dynamic> _indexerJson(LunaIndexer indexer) {
    return {
      'displayName': indexer.displayName,
      'host': indexer.host,
      if (indexer.apiKey.isNotEmpty) 'apiKey': indexer.apiKey,
      if (indexer.headers.isNotEmpty) 'headers': indexer.headers,
    };
  }

  static void _redactIndexerSecrets(LunaIndexer indexer) {
    indexer.apiKey = '';
    indexer.headers = {};
  }

  static const List<LunaModule> _serviceModules = [
    LunaModule.LIDARR,
    LunaModule.NZBGET,
    LunaModule.RADARR,
    LunaModule.SABNZBD,
    LunaModule.SONARR,
    LunaModule.TAUTULLI,
  ];

  static _ServiceDraft _serviceDraft(LunaProfile profile, LunaModule module) {
    switch (module) {
      case LunaModule.LIDARR:
        return _ServiceDraft(
          enabled: profile.lidarrEnabled,
          host: profile.lidarrHost,
          apiKey: profile.lidarrKey,
          headers: profile.lidarrHeaders,
        );
      case LunaModule.NZBGET:
        return _ServiceDraft(
          enabled: profile.nzbgetEnabled,
          host: profile.nzbgetHost,
          username: profile.nzbgetUser,
          password: profile.nzbgetPass,
          headers: profile.nzbgetHeaders,
        );
      case LunaModule.RADARR:
        return _ServiceDraft(
          enabled: profile.radarrEnabled,
          host: profile.radarrHost,
          apiKey: profile.radarrKey,
          headers: profile.radarrHeaders,
        );
      case LunaModule.SABNZBD:
        return _ServiceDraft(
          enabled: profile.sabnzbdEnabled,
          host: profile.sabnzbdHost,
          apiKey: profile.sabnzbdKey,
          headers: profile.sabnzbdHeaders,
        );
      case LunaModule.SONARR:
        return _ServiceDraft(
          enabled: profile.sonarrEnabled,
          host: profile.sonarrHost,
          apiKey: profile.sonarrKey,
          headers: profile.sonarrHeaders,
        );
      case LunaModule.TAUTULLI:
        return _ServiceDraft(
          enabled: profile.tautulliEnabled,
          host: profile.tautulliHost,
          apiKey: profile.tautulliKey,
          headers: profile.tautulliHeaders,
        );
      default:
        return const _ServiceDraft(enabled: false);
    }
  }

  static void _markGateway(
    LunaProfile profile,
    LunaModule module,
    String gatewayProfile,
  ) {
    switch (module) {
      case LunaModule.LIDARR:
        profile.lidarrConnectionMode = LunaConnectionMode.gateway.key;
        profile.lidarrGatewayProfile = gatewayProfile;
        profile.lidarrHost = '';
        profile.lidarrKey = '';
        return;
      case LunaModule.NZBGET:
        profile.nzbgetConnectionMode = LunaConnectionMode.gateway.key;
        profile.nzbgetGatewayProfile = gatewayProfile;
        profile.nzbgetHost = '';
        profile.nzbgetUser = '';
        profile.nzbgetPass = '';
        return;
      case LunaModule.RADARR:
        profile.radarrConnectionMode = LunaConnectionMode.gateway.key;
        profile.radarrGatewayProfile = gatewayProfile;
        profile.radarrHost = '';
        profile.radarrKey = '';
        return;
      case LunaModule.SABNZBD:
        profile.sabnzbdConnectionMode = LunaConnectionMode.gateway.key;
        profile.sabnzbdGatewayProfile = gatewayProfile;
        profile.sabnzbdHost = '';
        profile.sabnzbdKey = '';
        return;
      case LunaModule.SONARR:
        profile.sonarrConnectionMode = LunaConnectionMode.gateway.key;
        profile.sonarrGatewayProfile = gatewayProfile;
        profile.sonarrHost = '';
        profile.sonarrKey = '';
        return;
      case LunaModule.TAUTULLI:
        profile.tautulliConnectionMode = LunaConnectionMode.gateway.key;
        profile.tautulliGatewayProfile = gatewayProfile;
        profile.tautulliHost = '';
        profile.tautulliKey = '';
        return;
      default:
        return;
    }
  }
}

class _ServiceDraft {
  final bool enabled;
  final String host;
  final String apiKey;
  final String username;
  final String password;
  final Map<String, String> headers;

  const _ServiceDraft({
    required this.enabled,
    this.host = '',
    this.apiKey = '',
    this.username = '',
    this.password = '',
    this.headers = const {},
  });
}
