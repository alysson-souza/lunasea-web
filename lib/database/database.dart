import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/system/preferences/lunasea.dart';
import 'package:lunasea/system/backend_state.dart';
import 'package:lunasea/system/filesystem/filesystem.dart';
import 'package:lunasea/system/gateway/gateway.dart';
import 'package:lunasea/system/platform.dart';
import 'package:lunasea/vendor.dart';

class LunaDatabase {
  static const String _DATABASE_LEGACY_PATH = 'database';
  static const String _DATABASE_PATH = 'LunaSea/database';

  String get path {
    if (LunaPlatform.isWindows || LunaPlatform.isLinux) return _DATABASE_PATH;
    return _DATABASE_LEGACY_PATH;
  }

  Future<void> initialize() async {
    await open();
  }

  Future<void> open() async {
    if (LunaGateway.state.isEmpty) {
      throw StateError('LunaSea backend state is unavailable');
    }
    await LunaBackendState.hydrate(LunaGateway.state);
    if (LunaBackendState.profiles.isEmpty) await bootstrap();
  }

  Future<void> nuke() async {
    LunaBackendState.clear();

    if (LunaFileSystem.isSupported) {
      await LunaFileSystem().nuke();
    }
  }

  Future<void> bootstrap() async {
    const defaultProfile = LunaProfile.DEFAULT_PROFILE;
    await clear();

    LunaBackendState.profiles[defaultProfile] = LunaProfile();
    LunaSeaPreferences.ENABLED_PROFILE.update(defaultProfile);
  }

  Future<void> clear() async {
    LunaBackendState.clear();
  }

  Future<void> deinitialize() async {
    LunaBackendState.clear();
  }
}
