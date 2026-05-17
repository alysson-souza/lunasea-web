import 'package:lunasea/database/models/external_module.dart';
import 'package:lunasea/database/models/indexer.dart';
import 'package:lunasea/database/models/log.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/vendor.dart';

class LunaBackendClient {
  final Dio dio;

  LunaBackendClient({Dio? dio})
    : dio =
          dio ??
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

  static Map<String, dynamic>? serviceInstance(LunaServiceInstanceRef ref) {
    for (final instance in _serviceInstances) {
      if (instance['service'] == ref.module.key &&
          instance['profile'] == ref.profileId &&
          instance['id'] == ref.instanceId) {
        return instance;
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> createServiceInstance({
    required String profile,
    required LunaModule module,
    String? displayName,
    bool enabled = false,
    int? sortOrder,
    String? connectionMode,
    String? upstreamUrl,
    String? apiKey,
    String? username,
    String? password,
    Map<String, String>? headers,
    Map<String, dynamic>? preferences,
  }) async {
    final data = _serviceCreateData(
      displayName: displayName,
      enabled: enabled,
      sortOrder: sortOrder,
      connectionMode: connectionMode,
      upstreamUrl: upstreamUrl,
      apiKey: apiKey,
      username: username,
      password: password,
      headers: headers,
      preferences: preferences,
    );
    final response = await _dio.post(
      _instanceCollectionPath(profile: profile, module: module),
      data: data,
    );
    final service = Map<String, dynamic>.from(response.data as Map);
    _cacheService(service);
    return service;
  }

  static Future<Map<String, dynamic>> patchServiceInstance({
    required LunaServiceInstance instance,
  }) async {
    final response = await _dio.patch(
      _instancePath(instance.ref),
      data: instance.toJson(),
    );
    final service = Map<String, dynamic>.from(response.data as Map);
    _cacheService(service);
    return service;
  }

  static Future<void> testServiceInstance(LunaServiceInstanceRef ref) async {
    await _dio.post(_instanceTestPath(ref));
  }

  static Future<void> deleteServiceInstance(LunaServiceInstanceRef ref) async {
    await _dio.delete(_instancePath(ref));
    _removeCachedService(ref);
  }

  static Future<void> _deleteServiceRef(
    LunaServiceInstanceRef ref, {
    Future<void> Function(LunaServiceInstanceRef ref)? delete,
  }) async {
    try {
      await (delete ?? deleteServiceInstance)(ref);
    } on DioException catch (error) {
      if (!_isMissingServiceInstance(error)) rethrow;
      _removeCachedService(ref);
    }
  }

  static bool _isMissingServiceInstance(DioException error) {
    return error.response?.statusCode == 404 ||
        error.response?.statusCode == 503;
  }

  static List<Map<String, dynamic>> get _serviceInstances {
    return (_state['serviceInstances'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static void _cacheServices(List<Map<String, dynamic>> services) {
    _state = Map<String, dynamic>.from(_state)..['serviceInstances'] = services;
  }

  static void _mergeServices(List<Map<String, dynamic>> services) {
    for (final service in services) {
      _cacheService(service);
    }
  }

  static void _cacheService(Map<String, dynamic> service) {
    final services =
        _serviceInstances
            .where(
              (item) =>
                  item['service'] != service['service'] ||
                  item['profile'] != service['profile'] ||
                  item['id'] != service['id'],
            )
            .toList()
          ..add(service);
    _cacheServices(services);
  }

  static void _removeCachedService(LunaServiceInstanceRef ref) {
    final services = _serviceInstances
        .where(
          (item) =>
              item['service'] != ref.module.key ||
              item['profile'] != ref.profileId ||
              item['id'] != ref.instanceId,
        )
        .toList();
    _cacheServices(services);
  }

  static String _instanceCollectionPath({
    required String profile,
    required LunaModule module,
  }) {
    return ['profiles', profile, 'services', module.key, 'instances'].join('/');
  }

  static String _instancePath(LunaServiceInstanceRef ref) {
    return '${_instanceCollectionPath(profile: ref.profileId, module: ref.module)}/${ref.instanceId}';
  }

  static String _instanceTestPath(LunaServiceInstanceRef ref) {
    return '${_instancePath(ref)}/test';
  }

  static Map<String, dynamic> _serviceCreateData({
    String? displayName,
    bool enabled = true,
    int? sortOrder,
    String? connectionMode,
    String? upstreamUrl,
    String? apiKey,
    String? username,
    String? password,
    Map<String, String>? headers,
    Map<String, dynamic>? preferences,
  }) {
    return <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      'enabled': enabled,
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (connectionMode != null) 'connectionMode': connectionMode,
      if (upstreamUrl != null) 'upstreamUrl': upstreamUrl,
      if (apiKey != null) 'apiKey': apiKey,
      if (username != null) 'username': username,
      if (password != null) 'password': password,
      if (headers != null) 'headers': headers,
      if (preferences != null) 'preferences': preferences,
    };
  }

  @visibleForTesting
  static void mergeServiceInstancesForTest(
    List<Map<String, dynamic>> services,
  ) {
    _mergeServices(services);
  }

  @visibleForTesting
  static Map<String, dynamic> serviceCreateDataForTest({
    String? displayName,
    bool enabled = true,
    int? sortOrder,
    String? connectionMode,
    String? upstreamUrl,
    String? apiKey,
    String? username,
    String? password,
    Map<String, String>? headers,
    Map<String, dynamic>? preferences,
  }) {
    return _serviceCreateData(
      displayName: displayName,
      enabled: enabled,
      sortOrder: sortOrder,
      connectionMode: connectionMode,
      upstreamUrl: upstreamUrl,
      apiKey: apiKey,
      username: username,
      password: password,
      headers: headers,
      preferences: preferences,
    );
  }

  @visibleForTesting
  static String instancePathForTest(LunaServiceInstanceRef ref) {
    return _instancePath(ref);
  }

  @visibleForTesting
  static String instanceTestPathForTest(LunaServiceInstanceRef ref) {
    return _instanceTestPath(ref);
  }

  static void _applyServiceInstanceToProfile(
    LunaProfile profile,
    Map<String, dynamic> service,
  ) {
    final instance = _serviceInstanceFromMap(service);
    if (instance == null) return;
    profile.serviceInstances =
        profile.serviceInstances
            .where((item) => item.key != instance.key)
            .toList()
          ..add(instance);
  }

  static LunaServiceInstance? _serviceInstanceFromMap(
    Map<String, dynamic> service,
  ) {
    try {
      return LunaServiceInstance.fromJson(service);
    } on Object {
      return null;
    }
  }

  @visibleForTesting
  static void applyServiceInstanceToProfileForTest(
    LunaProfile profile,
    Map<String, dynamic> service,
  ) {
    _applyServiceInstanceToProfile(profile, service);
  }

  static void _removeServiceInstanceFromProfile(
    LunaProfile profile,
    LunaServiceInstanceRef ref,
  ) {
    profile.serviceInstances = profile.serviceInstances
        .where((instance) => instance.key != ref.key)
        .toList();
  }

  @visibleForTesting
  static void removeServiceInstanceFromProfileForTest(
    LunaProfile profile,
    LunaServiceInstanceRef ref,
  ) {
    _removeServiceInstanceFromProfile(profile, ref);
  }

  static List<LunaServiceInstanceRef> _profileServiceRefs(
    LunaProfile profile,
    LunaModule module,
  ) {
    return profile
        .instancesFor(module)
        .map((instance) => instance.ref)
        .toList();
  }

  static void _removeProfileServiceRefs(
    LunaProfile profile,
    LunaModule module,
  ) {
    for (final ref in _profileServiceRefs(profile, module)) {
      _removeServiceInstanceFromProfile(profile, ref);
    }
  }

  @visibleForTesting
  static List<LunaServiceInstanceRef> profileServiceRefsForTest(
    LunaProfile profile,
    LunaModule module,
  ) {
    return _profileServiceRefs(profile, module);
  }

  @visibleForTesting
  static void removeProfileServiceRefsForTest(
    LunaProfile profile,
    LunaModule module,
  ) {
    _removeProfileServiceRefs(profile, module);
  }

  static Future<void> _deleteServiceRefFromProfile(
    LunaProfile profile,
    LunaServiceInstanceRef ref, {
    Future<void> Function(LunaServiceInstanceRef ref)? delete,
  }) async {
    await _deleteServiceRef(ref, delete: delete);
    _removeServiceInstanceFromProfile(profile, ref);
  }

  @visibleForTesting
  static Future<void> deleteServiceRefFromProfileForTest(
    LunaProfile profile,
    LunaServiceInstanceRef ref,
    Future<void> Function(LunaServiceInstanceRef ref) delete,
  ) {
    return _deleteServiceRefFromProfile(profile, ref, delete: delete);
  }

  static Future<void> createProfile(String id) async {
    await _dio.post('profiles', data: {'id': id, 'displayName': id});
  }

  static Future<void> updateProfile(String id, LunaProfile profile) async {
    await _dio.patch('profiles/$id', data: {'displayName': id});
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
    final response = await _dio.post(
      'logs',
      data: {
        'timestamp': log.timestamp,
        'type': (log.type as dynamic).key,
        'className': log.className ?? '',
        'methodName': log.methodName ?? '',
        'message': log.message,
        'error': log.error ?? '',
        'stackTrace': log.stackTrace?.trim().split('\n') ?? [],
      },
    );
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
}
