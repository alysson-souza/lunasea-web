import 'package:lunasea/core.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules/sabnzbd.dart';
import 'package:lunasea/system/gateway/service_endpoint.dart';
import 'package:lunasea/system/network/dio_error_interceptor.dart';

class SABnzbdAPI {
  final Dio _dio;

  SABnzbdAPI._internal(this._dio);

  @visibleForTesting
  BaseOptions get options => _dio.options;

  factory SABnzbdAPI.from(LunaProfile profile) {
    final instances = profile.enabledInstances(LunaModule.SABNZBD);
    if (instances.isEmpty) {
      throw StateError('No enabled SABnzbd service instance is configured.');
    }
    return SABnzbdAPI.fromInstance(instances.first);
  }

  factory SABnzbdAPI.fromInstance(LunaServiceInstance instance) {
    final endpoint = LunaServiceEndpoint.fromInstance(instance);
    Dio _client = Dio(
      BaseOptions(
        baseUrl: endpoint.apiBase('api'),
        queryParameters: {
          if (!endpoint.isGateway && instance.apiKey != '')
            'apikey': instance.apiKey,
          'output': 'json',
        },
        headers: instance.headers,
        followRedirects: true,
        maxRedirects: 5,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );

    _client.interceptors.add(const LunaDioErrorInterceptor());
    return SABnzbdAPI._internal(_client);
  }

  void logError(String text, Object error, StackTrace trace) =>
      LunaLogger().error('SABnzbd: $text', error, trace);

  Future<dynamic> testConnection() async =>
      _dio.get('', queryParameters: {'mode': 'fullstatus'});

  Future<SABnzbdStatisticsData> getStatistics() async {
    try {
      Response status = await _dio.get(
        '',
        queryParameters: {'mode': 'fullstatus', 'skip_dashboard': 1},
      );
      Response statistics = await _dio.get(
        '',
        queryParameters: {'mode': 'server_stats'},
      );
      //Parse individual servers
      List<SABnzbdServerStatisticsData> _servers = [];
      for (var server in statistics.data['servers'].keys) {
        _servers.add(
          SABnzbdServerStatisticsData(
            name: server.toString(),
            dailyUsage: statistics.data['servers'][server]['day'],
            weeklyUsage: statistics.data['servers'][server]['week'],
            monthlyUsage: statistics.data['servers'][server]['month'],
            totalUsage: statistics.data['servers'][server]['total'],
          ),
        );
      }
      //Assemble final stats object
      return SABnzbdStatisticsData(
        servers: _servers,
        uptime: status.data['status']['uptime'] ?? 'Unknown',
        version: status.data['status']['version'] ?? 'Unknown',
        speedlimit: status.data['status']['speedlimit_abs'] == ''
            ? -1
            : double.tryParse(status.data['status']['speedlimit_abs']),
        speedlimitPercentage:
            int.tryParse(status.data['status']['speedlimit']) ?? 100,
        tempFreespace:
            double.tryParse(status.data['status']['diskspace1']) ?? 0.0,
        finalFreespace:
            double.tryParse(status.data['status']['diskspace2']) ?? 0.0,
        dailyUsage: statistics.data['day'] ?? 0,
        weeklyUsage: statistics.data['week'] ?? 0,
        monthlyUsage: statistics.data['month'] ?? 0,
        totalUsage: statistics.data['total'] ?? 0,
      );
    } on DioException catch (error, stack) {
      logError('Failed to fetch statistics', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to fetch statistics', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> pauseQueue() async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {'mode': 'pause'},
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError('Failed to pause queue', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to pause queue', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> pauseQueueFor(int? minutes) async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {
          'mode': 'config',
          'name': 'set_pause',
          'value': minutes,
        },
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError('Failed to pause queue for $minutes minutes', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to pause queue for $minutes minutes', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> resumeQueue() async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {'mode': 'resume'},
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError('Failed to resume queue', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to resume queue', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> pauseSingleJob(String nzoId) async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {'mode': 'queue', 'name': 'pause', 'value': nzoId},
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError('Failed to pause job ($nzoId)', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to pause job ($nzoId)', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> resumeSingleJob(String nzoId) async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {'mode': 'queue', 'name': 'resume', 'value': nzoId},
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError('Failed to resume job ($nzoId)', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to resume job ($nzoId)', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> deleteJob(String nzoId) async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {
          'mode': 'queue',
          'name': 'delete',
          'value': nzoId,
          'del_files': 1,
        },
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError('Failed to delete job ($nzoId)', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to delete job ($nzoId)', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> renameJob(String nzoId, String name) async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {
          'mode': 'queue',
          'name': 'rename',
          'value': nzoId,
          'value2': name,
        },
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError('Failed to rename job ($nzoId, $name)', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to rename job ($nzoId, $name)', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> setJobPassword(
    String nzoId,
    String name,
    String password,
  ) async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {
          'mode': 'queue',
          'name': 'rename',
          'value': nzoId,
          'value2': name,
          'value3': password,
        },
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError('Failed to set job password for job $nzoId', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to set job password for job $nzoId', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> setJobPriority(String nzoId, int priority) async {
    try {
      final response = await _dio.get(
        '',
        queryParameters: {
          'mode': 'queue',
          'name': 'priority',
          'value': nzoId,
          'value2': priority,
        },
      );
      final data = response.data;
      if (data is Map && data.containsKey('status')) {
        return data['status'] == true;
      }
      return data is List;
    } on DioException catch (error, stack) {
      logError('Failed to set job priority ($nzoId, $priority)', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to set job priority ($nzoId, $priority)', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> deleteHistory(String nzoId) async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {
          'mode': 'history',
          'name': 'delete',
          'del_files': 1,
          'value': nzoId,
        },
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError('Failed to delete history entry ($nzoId)', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to delete history entry ($nzoId)', error, stack);
      return Future.error(error);
    }
  }

  static num _number(dynamic value) {
    if (value == null || value == '') return 0;
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw FormatException('Invalid SABnzbd number', value);
  }

  static Map<String, dynamic> _object(dynamic value) {
    if (value is! Map) {
      throw FormatException('Invalid SABnzbd response', value);
    }
    if (value['status'] == false || value['error'] != null) {
      throw StateError(value['error']?.toString() ?? 'SABnzbd request failed.');
    }
    return Map<String, dynamic>.from(value);
  }

  Future<SABnzbdQueueSnapshot> getQueue({
    int start = 0,
    int limit = 100,
  }) async {
    final response = await _dio.get(
      '',
      queryParameters: {'mode': 'queue', 'start': start, 'limit': limit},
    );
    final data = _object(_object(response.data)['queue']);
    final slots = data['slots'] as List;
    return SABnzbdQueueSnapshot(
      status: SABnzbdStatusData(
        paused: data['paused'] == true,
        speed: _number(data['kbpersec']).toDouble(),
        sizeLeft: _number(data['mbleft']).toDouble(),
        timeLeft: data['timeleft']?.toString() ?? '00:00:00',
        speedlimit: _number(data['speedlimit']).toInt(),
      ),
      items: [
        for (final slot in slots)
          SABnzbdQueueData(
            name: slot['filename']?.toString() ?? '',
            nzoId: slot['nzo_id']?.toString() ?? '',
            sizeTotal: _number(slot['mb']).round(),
            sizeLeft: _number(slot['mbleft']).round(),
            status: slot['status']?.toString() ?? 'Unknown Status',
            timeLeft: slot['timeleft']?.toString() ?? 'Unknown Time Left',
            category: slot['cat']?.toString() ?? 'Unknown Category',
          ),
      ],
      total: _number(data['noofslots']).toInt(),
      start: data['start'] == null ? start : _number(data['start']).toInt(),
      limit: data['limit'] == null ? limit : _number(data['limit']).toInt(),
    );
  }

  Future<Map<String, dynamic>> _fetchHistory(
    Map<String, dynamic> queryParameters,
  ) async {
    final response = await _dio.get(
      '',
      queryParameters: {'mode': 'history', ...queryParameters},
    );
    return _object(_object(response.data)['history']);
  }

  static SABnzbdHistoryData _parseHistoryItem(dynamic value) {
    final slot = _object(value);
    return SABnzbdHistoryData(
      nzoId: slot['nzo_id']?.toString() ?? '',
      name: slot['name']?.toString() ?? '',
      size: _number(slot['bytes']).toInt(),
      status: slot['status']?.toString() ?? '',
      failureMessage: slot['fail_message']?.toString() ?? '',
      timestamp: _number(slot['completed']).toInt(),
      actionLine: slot['action_line']?.toString() ?? '',
      category: slot['category'] == '*'
          ? 'Default'
          : slot['category']?.toString(),
      downloadTime: _number(slot['download_time']).toInt(),
      stageLog: slot['stage_log'] as List? ?? [],
      storageLocation: slot['storage']?.toString() ?? '',
    );
  }

  Future<SABnzbdHistoryData?> getHistoryItem(String nzoId) async {
    final data = await _fetchHistory({'nzo_ids': nzoId});
    final slots = data['slots'] as List;
    for (final slot in slots) {
      final item = _parseHistoryItem(slot);
      if (item.nzoId == nzoId) return item;
    }
    return null;
  }

  Future<SABnzbdHistoryPage> getHistoryPage({
    int start = 0,
    int limit = 200,
  }) async {
    final data = await _fetchHistory({'start': start, 'limit': limit});
    final slots = data['slots'] as List;
    return SABnzbdHistoryPage(
      items: [for (final slot in slots) _parseHistoryItem(slot)],
      total: _number(data['noofslots']).toInt(),
      start: data['start'] == null ? start : _number(data['start']).toInt(),
      limit: data['limit'] == null ? limit : _number(data['limit']).toInt(),
    );
  }

  Future<bool> moveQueue(String nzoId, int index) async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {'mode': 'switch', 'value': nzoId, 'value2': index},
      );
      return response.data['status'] != false &&
          response.data['result'] != null &&
          response.data['result']['position'] != null;
    } on DioException catch (error, stack) {
      logError('Failed to move queue entry ($nzoId, $index)', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to move queue entry ($nzoId, $index)', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> sortQueue(String sort, String dir) async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {
          'mode': 'queue',
          'name': 'sort',
          'sort': sort,
          'dir': dir,
        },
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError('Failed to sort queue ($sort, $dir)', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to sort queue ($sort, $dir)', error, stack);
      return Future.error(error);
    }
  }

  Future<List<SABnzbdCategoryData>> getCategories() async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {'mode': 'get_cats'},
      );
      List<SABnzbdCategoryData> entries = [];
      for (var entry in response.data['categories']) {
        entries.add(
          SABnzbdCategoryData(category: entry == '*' ? 'Default' : entry),
        );
      }
      return entries;
    } on DioException catch (error, stack) {
      logError('Failed to fetch categories', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to fetch categories', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> setCategory(String nzoId, String? category) async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {
          'mode': 'change_cat',
          'value': nzoId,
          'value2': category,
        },
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError('Failed to set category ($nzoId, $category)', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to set category ($nzoId, $category)', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> setSpeedLimit(int? limit) async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {
          'mode': 'config',
          'name': 'speedlimit',
          'value': limit,
        },
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError('Failed to set speed limit ($limit)', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to set speed limit ($limit)', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> uploadURL(String url) async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {'mode': 'addurl', 'name': url},
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError('Failed to upload NZB by URL', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to upload NZB by URL', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> uploadFile(List<int> data, String name) async {
    try {
      Response response = await _dio.post(
        '',
        queryParameters: {'mode': 'addfile'},
        data: FormData.fromMap({
          'name': MultipartFile.fromBytes(data, filename: name),
        }),
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError('Failed to upload nzb file ($name)', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to upload nzb file ($name)', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> setOnCompleteAction(String action) async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {
          'mode': 'queue',
          'name': 'change_complete_action',
          'value': action,
        },
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError('Failed to set on-complete action ($action)', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to set on-complete action ($action)', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> clearHistory(String action, bool delete) async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {
          'mode': 'history',
          'name': 'delete',
          'value': action,
          if (delete) 'del_files': 1,
        },
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError('Failed to clear history ($action, $delete)', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to clear history ($action, $delete)', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> retryFailedJob(String nzoId) async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {'mode': 'retry', 'value': nzoId},
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError('Failed to retry job ($nzoId)', error, stack);
      return Future.error(error);
    } catch (error, stack) {
      logError('Failed to retry job ($nzoId)', error, stack);
      return Future.error(error);
    }
  }

  Future<bool> retryFailedJobPassword(String nzoId, String password) async {
    try {
      Response response = await _dio.get(
        '',
        queryParameters: {
          'mode': 'retry',
          'value': nzoId,
          'password': password,
        },
      );
      return response.data['status'] != null && response.data['status'];
    } on DioException catch (error, stack) {
      logError(
        'Failed to retry job with new password for job $nzoId',
        error,
        stack,
      );
      return Future.error(error);
    } catch (error, stack) {
      logError(
        'Failed to retry job with new password for job $nzoId',
        error,
        stack,
      );
      return Future.error(error);
    }
  }
}
