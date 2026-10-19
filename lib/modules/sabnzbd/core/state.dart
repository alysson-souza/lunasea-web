import 'package:flutter/widgets.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sabnzbd/core/api.dart';

class SABnzbdState extends LunaModuleState {
  final LunaServiceInstance? instance;

  final SABnzbdAPI? _injectedClient;
  final Duration pollInterval;
  final Duration requestTimeout;
  SABnzbdAPI? _cachedClient;

  SABnzbdState({
    this.instance,
    SABnzbdAPI? apiClient,
    this.pollInterval = const Duration(seconds: 2),
    this.requestTimeout = const Duration(seconds: 10),
  }) : _injectedClient = apiClient;

  SABnzbdAPI get _client {
    if (_injectedClient != null) return _injectedClient;
    final owner = instance;
    if (owner == null) {
      throw StateError('No SABnzbd service instance is configured.');
    }
    return _cachedClient ??= SABnzbdAPI.fromInstance(owner);
  }

  SABnzbdStatusData? _status;
  SABnzbdStatusData? get status => _status;
  List<SABnzbdQueueData> _queue = [];
  List<SABnzbdQueueData> get queue => _queue;
  List<SABnzbdHistoryData> _history = [];
  List<SABnzbdHistoryData> get history => _history;
  int _queueTotal = 0;
  int get queueTotal => _queueTotal;
  int _historyTotal = 0;
  int get historyTotal => _historyTotal;
  bool _queueLoading = false;
  bool get queueLoading => _queueLoading;
  bool _historyLoading = false;
  bool get historyLoading => _historyLoading;
  Object? _queueError;
  Object? get queueError => _queueError;
  Object? _historyError;
  Object? get historyError => _historyError;
  DateTime? _queueUpdatedAt;
  DateTime? get queueUpdatedAt => _queueUpdatedAt;
  DateTime? _historyUpdatedAt;
  DateTime? get historyUpdatedAt => _historyUpdatedAt;
  bool get queueStale => _queueError != null;
  bool get historyStale => _historyError != null;
  bool get hasMoreQueue => _queue.length < _queueTotal;
  bool get hasMoreHistory => _history.length < _historyTotal;
  bool _disposed = false;
  bool get isDisposed => _disposed;

  int _generation = 0;
  int _queueLimit = 100;
  int _historyLimit = 200;
  int _queueConsumers = 0;
  Timer? _queueTimer;
  Future<void>? _queueRequest;
  Future<void>? _queueMoreRequest;
  Future<void>? _historyRequest;
  Future<void>? _historyMoreRequest;

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  @override
  void reset() {
    if (_disposed) return;
    final generation = ++_generation;
    _queueTimer?.cancel();
    _queueTimer = null;
    _queueRequest = null;
    _queueMoreRequest = null;
    _historyRequest = null;
    _historyMoreRequest = null;
    _status = null;
    _queue = [];
    _history = [];
    _queueTotal = 0;
    _historyTotal = 0;
    _queueLoading = false;
    _historyLoading = false;
    _queueError = null;
    _historyError = null;
    _queueUpdatedAt = null;
    _historyUpdatedAt = null;
    _queueLimit = 100;
    _historyLimit = 200;
    notifyListeners();
    if (_queueConsumers > 0) {
      scheduleMicrotask(() {
        if (_isCurrent(generation) && _queueConsumers > 0) refreshQueue();
      });
    }
  }

  /// Forced refreshes must start after the caller's completed mutation.
  Future<void> refreshQueue({bool force = false}) {
    if (_disposed) return Future.value();
    final running = _queueRequest;
    if (running != null) {
      return force ? _refreshQueueAfterRequest(running, _generation) : running;
    }
    _queueTimer?.cancel();
    _queueTimer = null;
    final generation = _generation;
    final completion = Completer<void>();
    _queueRequest = completion.future;
    _queueLoading = true;
    notifyListeners();
    _fetchQueue(generation).then((_) => completion.complete());
    return completion.future;
  }

  Future<void> _refreshQueueAfterRequest(
    Future<void> running,
    int generation,
  ) async {
    await running;
    if (_isCurrent(generation)) await refreshQueue();
  }

  Future<void> _fetchQueue(int generation) async {
    try {
      final snapshot = await _client
          .getQueue(start: 0, limit: _queueLimit)
          .timeout(requestTimeout);
      if (!_isCurrent(generation)) return;
      _status = snapshot.status;
      _queue = List.unmodifiable(snapshot.items);
      _queueTotal = snapshot.total;
      _queueUpdatedAt = DateTime.now();
      _queueError = null;
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _queueError = error;
    } finally {
      if (_isCurrent(generation)) {
        _queueLoading = false;
        _queueRequest = null;
        _scheduleQueuePoll();
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreQueue() {
    if (_disposed) return Future.value();
    if (_queueMoreRequest != null) return _queueMoreRequest!;
    final generation = _generation;
    final pending = _loadMoreQueue(generation);
    _queueMoreRequest = pending;
    pending.then((_) {
      if (_isCurrent(generation)) _queueMoreRequest = null;
    });
    return pending;
  }

  Future<void> _loadMoreQueue(int generation) async {
    await (_queueRequest ?? Future<void>.value());
    while (_isCurrent(generation) && _queueRequest != null) {
      await _queueRequest;
    }
    if (!_isCurrent(generation) || !hasMoreQueue) return;
    _queueLimit += 100;
    await refreshQueue();
  }

  /// Forced refreshes cannot reuse a read started before the mutation.
  Future<void> refreshHistory({bool force = false}) {
    if (_disposed) return Future.value();
    final running = _historyRequest;
    if (running != null) {
      return force
          ? _refreshHistoryAfterRequest(running, _generation)
          : running;
    }
    final generation = _generation;
    final completion = Completer<void>();
    _historyRequest = completion.future;
    _historyLoading = true;
    notifyListeners();
    _fetchHistory(generation).then((_) => completion.complete());
    return completion.future;
  }

  Future<void> _refreshHistoryAfterRequest(
    Future<void> running,
    int generation,
  ) async {
    await running;
    if (_isCurrent(generation)) await refreshHistory();
  }

  Future<void> _fetchHistory(int generation) async {
    try {
      final page = await _client
          .getHistoryPage(start: 0, limit: _historyLimit)
          .timeout(requestTimeout);
      if (!_isCurrent(generation)) return;
      final records = <String, SABnzbdHistoryData>{
        for (final item in page.items) item.nzoId: item,
      };
      _history = List.unmodifiable(records.values);
      _historyTotal = page.total;
      _historyUpdatedAt = DateTime.now();
      _historyError = null;
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _historyError = error;
    } finally {
      if (_isCurrent(generation)) {
        _historyLoading = false;
        _historyRequest = null;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreHistory() {
    if (_disposed) return Future.value();
    if (_historyMoreRequest != null) return _historyMoreRequest!;
    final generation = _generation;
    final pending = _loadMoreHistory(generation);
    _historyMoreRequest = pending;
    pending.then((_) {
      if (_isCurrent(generation)) _historyMoreRequest = null;
    });
    return pending;
  }

  Future<void> _loadMoreHistory(int generation) async {
    await (_historyRequest ?? Future<void>.value());
    while (_isCurrent(generation) && _historyRequest != null) {
      await _historyRequest;
    }
    if (!_isCurrent(generation) || !hasMoreHistory) return;
    _historyLimit += 200;
    await refreshHistory();
  }

  void acquireQueue() {
    if (_disposed) return;
    _queueConsumers++;
    // A visible owner can change without shared demand ever reaching zero.
    // Refresh on entry; concurrent acquisitions share refreshQueue's request.
    final generation = _generation;
    scheduleMicrotask(() {
      if (_isCurrent(generation) && _queueConsumers > 0) refreshQueue();
    });
  }

  void releaseQueue() {
    if (_queueConsumers == 0) return;
    _queueConsumers--;
    if (_queueConsumers == 0) {
      _queueTimer?.cancel();
      _queueTimer = null;
    }
  }

  void _scheduleQueuePoll() {
    if (_disposed || _queueConsumers == 0) return;
    _queueTimer?.cancel();
    _queueTimer = Timer(pollInterval, refreshQueue);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _queueConsumers = 0;
    _queueTimer?.cancel();
    _queueTimer = null;
    super.dispose();
  }

  SABnzbdAPI api(BuildContext context) {
    if (_injectedClient != null || instance != null) return _client;
    final selected = selectedInstance(context);
    if (selected != null) return SABnzbdAPI.fromInstance(selected);
    throw StateError('No enabled SABnzbd service instance is configured.');
  }

  LunaServiceInstance? selectedInstance(BuildContext context) {
    final selected = instance;
    if (selected != null) return selected;
    final profile = context.read<ProfilesStore>().active;
    final instances = profile.enabledInstances(LunaModule.SABNZBD);
    return instances.isEmpty ? null : instances.first;
  }

  bool get error => queueError != null;
  bool get paused => status?.paused ?? true;

  String _historySearchFilter = '';
  String get historySearchFilter => _historySearchFilter;
  set historySearchFilter(String historySearchFilter) {
    _historySearchFilter = historySearchFilter;
    notifyListeners();
  }

  bool _historyHideFailed = false;
  bool get historyHideFailed => _historyHideFailed;
  set historyHideFailed(bool historyHideFailed) {
    _historyHideFailed = historyHideFailed;
    notifyListeners();
  }

  String get currentSpeed => status?.currentSpeed ?? '0.0 B/s';
  String get queueSizeLeft => status?.remainingSize ?? '0.0 B';
  String get queueTimeLeft => status?.timeLeft ?? '0:00:00';
  int get speedLimit => status?.speedlimit ?? 0;
}
