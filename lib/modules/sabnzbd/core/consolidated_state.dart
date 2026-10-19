import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules/sabnzbd/core/api/data/history.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';
import 'package:lunasea/system/consolidated/consolidated_item.dart';
import 'package:lunasea/system/state.dart';

/// Borrows registry-owned sources without owning their fetching or polling.
class SABnzbdConsolidatedState extends LunaModuleState {
  final List<LunaServiceInstance> instances;
  final List<SABnzbdState> instanceStates;

  SABnzbdConsolidatedState({
    required List<LunaServiceInstance> instances,
    required List<SABnzbdState> instanceStates,
  }) : assert(instances.length == instanceStates.length),
       instances = List.unmodifiable(instances),
       instanceStates = List.unmodifiable(instanceStates) {
    for (final state in this.instanceStates) {
      state.addListener(_onInstanceStateChanged);
    }
  }

  bool _disposed = false;
  bool _historyDirty = true;
  List<LunaConsolidatedItem<SABnzbdHistoryData>> _history = const [];

  String _historySearchFilter = '';
  String get historySearchFilter => _historySearchFilter;
  set historySearchFilter(String value) {
    if (_historySearchFilter == value) return;
    _historySearchFilter = value;
    _onInstanceStateChanged();
  }

  bool _historyFailedOnly = false;
  bool get historyFailedOnly => _historyFailedOnly;
  set historyFailedOnly(bool value) {
    if (_historyFailedOnly == value) return;
    _historyFailedOnly = value;
    _onInstanceStateChanged();
  }

  List<LunaConsolidatedItem<SABnzbdHistoryData>> get history {
    if (!_historyDirty) return _history;
    final search = _historySearchFilter.toLowerCase();
    final merged = <LunaConsolidatedItem<SABnzbdHistoryData>>[];
    for (var i = 0; i < instanceStates.length; i++) {
      for (final item in instanceStates[i].history) {
        if (_historyFailedOnly && !item.failed) continue;
        if (search.isNotEmpty && !item.name.toLowerCase().contains(search)) {
          continue;
        }
        merged.add(LunaConsolidatedItem(instance: instances[i], item: item));
      }
    }
    merged.sort((a, b) {
      final timestamp = b.item.timestamp.compareTo(a.item.timestamp);
      if (timestamp != 0) return timestamp;
      final owner = a.instance.ref.key.compareTo(b.instance.ref.key);
      if (owner != 0) return owner;
      return a.item.nzoId.compareTo(b.item.nzoId);
    });
    _history = List.unmodifiable(merged);
    _historyDirty = false;
    return _history;
  }

  Future<void> refreshQueue() async {
    if (_disposed) return;
    await Future.wait(instanceStates.map((state) => state.refreshQueue()));
  }

  Future<void> refreshHistory() async {
    if (_disposed) return;
    await Future.wait(instanceStates.map((state) => state.refreshHistory()));
  }

  void _onInstanceStateChanged() {
    if (_disposed) return;
    _historyDirty = true;
    notifyListeners();
  }

  @override
  void reset() {
    if (_disposed) return;
    _historySearchFilter = '';
    _historyFailedOnly = false;
    _onInstanceStateChanged();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final state in instanceStates) {
      state.removeListener(_onInstanceStateChanged);
    }
    super.dispose();
  }
}
