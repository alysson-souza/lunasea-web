import 'package:flutter/material.dart';

import 'package:lunasea/database/database.dart';
import 'package:lunasea/router/router.dart';
import 'package:lunasea/system/cache/image/image_cache.dart';
import 'package:lunasea/system/cache/memory/memory_store.dart';
import 'package:lunasea/system/gateway/gateway.dart';
import 'package:lunasea/system/logger.dart';
import 'package:lunasea/system/network/network.dart';
import 'package:lunasea/system/window_manager/window_manager.dart';
import 'package:lunasea/widgets/ui/theme.dart';

enum AppBootstrapStatus { loading, ready, error }

class AppBootstrapController extends ChangeNotifier {
  AppBootstrapStatus _status = AppBootstrapStatus.loading;
  Object? _error;
  Future<void>? _activeBootstrap;

  AppBootstrapStatus get status => _status;
  Object? get error => _error;

  Future<void> start() {
    return _activeBootstrap ??= _run();
  }

  Future<void> retry() {
    _activeBootstrap = null;
    _status = AppBootstrapStatus.loading;
    _error = null;
    notifyListeners();
    return start();
  }

  Future<void> _run() async {
    try {
      await bootstrapBackendState();
      _status = AppBootstrapStatus.ready;
      _error = null;
    } catch (error) {
      _status = AppBootstrapStatus.error;
      _error = error;
    }
    notifyListeners();
  }
}

Future<void> bootstrapBackendState() async {
  await LunaGateway.initialize();
  if (!LunaGateway.available) {
    throw StateError('LunaSea backend is unavailable');
  }
  await LunaDatabase().initialize();
  LunaLogger().initialize();
  LunaTheme().initialize();
  if (LunaWindowManager.isSupported) await LunaWindowManager().initialize();
  if (LunaNetwork.isSupported) LunaNetwork().initialize();
  if (LunaImageCache.isSupported) LunaImageCache().initialize();
  LunaRouter().initialize();
  await LunaMemoryStore().initialize();
}
