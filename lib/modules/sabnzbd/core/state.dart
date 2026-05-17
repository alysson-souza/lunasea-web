import 'package:flutter/widgets.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sabnzbd/core/api.dart';

class SABnzbdState extends LunaModuleState {
  final LunaServiceInstance? instance;

  SABnzbdState({this.instance}) {
    reset();
  }

  @override
  void reset() {}

  SABnzbdAPI api(BuildContext context) {
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

  bool _error = false;
  bool get error => _error;
  set error(bool error) {
    _error = error;
    notifyListeners();
  }

  bool _paused = true;
  bool get paused => _paused;
  set paused(bool paused) {
    _paused = paused;
    notifyListeners();
  }

  int _navigationIndex = 0;
  int get navigationIndex => _navigationIndex;
  set navigationIndex(int navigationIndex) {
    _navigationIndex = navigationIndex;
    notifyListeners();
  }

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

  String _currentSpeed = '0.0 B/s';
  String get currentSpeed => _currentSpeed;
  set currentSpeed(String currentSpeed) {
    _currentSpeed = currentSpeed;
    notifyListeners();
  }

  String _queueSizeLeft = '0.0 B';
  String get queueSizeLeft => _queueSizeLeft;
  set queueSizeLeft(String queueSizeLeft) {
    _queueSizeLeft = queueSizeLeft;
    notifyListeners();
  }

  String _queueTimeLeft = '0:00:00';
  String get queueTimeLeft => _queueTimeLeft;
  set queueTimeLeft(String queueTimeLeft) {
    _queueTimeLeft = queueTimeLeft;
    notifyListeners();
  }

  int _speedLimit = 0;
  int get speedLimit => _speedLimit;
  set speedLimit(int speedLimit) {
    _speedLimit = speedLimit;
    notifyListeners();
  }
}
