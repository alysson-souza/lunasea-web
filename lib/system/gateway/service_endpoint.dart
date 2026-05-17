import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/system/gateway/connection_mode.dart';
import 'package:lunasea/system/gateway/gateway.dart';

class LunaServiceEndpoint {
  final LunaModule module;
  final LunaConnectionMode mode;
  final String host;
  final String profileId;
  final String instanceId;

  const LunaServiceEndpoint({
    required this.module,
    required this.mode,
    required this.host,
    String? profileId,
    String? gatewayProfile,
    this.instanceId = '',
  }) : profileId = profileId ?? gatewayProfile ?? LunaProfile.DEFAULT_PROFILE;

  factory LunaServiceEndpoint.fromInstance(LunaServiceInstance instance) {
    return LunaServiceEndpoint(
      module: instance.module,
      mode:
          instance.connectionMode == LunaConnectionMode.gateway.key &&
              LunaGateway.available
          ? LunaConnectionMode.gateway
          : LunaConnectionMode.direct,
      host: instance.host,
      profileId: instance.profileId,
      instanceId: instance.id,
    );
  }

  factory LunaServiceEndpoint.fromProfile(
    LunaProfile profile,
    LunaModule module,
  ) {
    final instances = profile.enabledInstances(module);
    if (instances.isNotEmpty)
      return LunaServiceEndpoint.fromInstance(instances.first);

    final mode = profile.connectionMode(module);
    return LunaServiceEndpoint(
      module: module,
      mode: mode,
      host: profile.host(module),
      profileId: gatewayProfileFor(profile, module),
    );
  }

  bool get isGateway => mode == LunaConnectionMode.gateway;

  String get base {
    if (isGateway) {
      final profile = sanitizeProfile(profileId);
      final instance = instanceId.isEmpty
          ? LunaProfile.DEFAULT_PROFILE
          : sanitizeProfile(instanceId);
      return '/_lunasea/proxy/${module.key}/$profile/$instance';
    }
    return normalizeHost(host);
  }

  String apiBase(String apiRoot) => join(base, apiRoot);

  String mediaCoverBase(String apiRoot, String coverRoot) {
    return join(apiBase(apiRoot), coverRoot);
  }

  String authenticatedUrl(String url, String apiKey) {
    if (isGateway || apiKey.isEmpty) return url;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}apikey=$apiKey';
  }

  String nzbgetJsonRpcBase({
    required String username,
    required String password,
  }) {
    if (isGateway) return join(base, 'jsonrpc');
    final normalized = normalizeHost(host);
    if (username.isNotEmpty && password.isNotEmpty) {
      return join(normalized, '$username:$password/jsonrpc');
    }
    return join(normalized, 'jsonrpc');
  }

  static String join(String left, String right) {
    final a = left.trimRight();
    final b = right.trimLeft();
    if (a.endsWith('/') && b.startsWith('/')) return a + b.substring(1);
    if (!a.endsWith('/') && !b.startsWith('/')) return '$a/$b';
    return a + b;
  }

  static String normalizeHost(String value) {
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  static String sanitizeProfile(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  }

  static String gatewayProfileFor(LunaProfile profile, LunaModule module) {
    final stored = profile.gatewayProfile(module);
    return stored.isEmpty
        ? LunaProfile.DEFAULT_PROFILE
        : sanitizeProfile(stored);
  }

  static bool isValidDirectHost(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }
}

extension LunaProfileConnectionExtension on LunaProfile {
  LunaConnectionMode connectionMode(LunaModule module) {
    final stored = _connectionModeKey(module);
    if (stored == LunaConnectionMode.gateway.key && LunaGateway.available) {
      return LunaConnectionMode.gateway;
    }
    return LunaConnectionMode.direct;
  }

  void setConnectionMode(LunaModule module, LunaConnectionMode mode) {
    switch (module) {
      case LunaModule.LIDARR:
        lidarrConnectionMode = mode.key;
        return;
      case LunaModule.NZBGET:
        nzbgetConnectionMode = mode.key;
        return;
      case LunaModule.RADARR:
        radarrConnectionMode = mode.key;
        return;
      case LunaModule.SABNZBD:
        sabnzbdConnectionMode = mode.key;
        return;
      case LunaModule.SONARR:
        sonarrConnectionMode = mode.key;
        return;
      case LunaModule.TAUTULLI:
        tautulliConnectionMode = mode.key;
        return;
      default:
        return;
    }
  }

  String gatewayProfile(LunaModule module) {
    switch (module) {
      case LunaModule.LIDARR:
        return lidarrGatewayProfile;
      case LunaModule.NZBGET:
        return nzbgetGatewayProfile;
      case LunaModule.RADARR:
        return radarrGatewayProfile;
      case LunaModule.SABNZBD:
        return sabnzbdGatewayProfile;
      case LunaModule.SONARR:
        return sonarrGatewayProfile;
      case LunaModule.TAUTULLI:
        return tautulliGatewayProfile;
      default:
        return '';
    }
  }

  void setGatewayProfile(LunaModule module, String profile) {
    final sanitized = LunaServiceEndpoint.sanitizeProfile(profile);
    switch (module) {
      case LunaModule.LIDARR:
        lidarrGatewayProfile = sanitized;
        return;
      case LunaModule.NZBGET:
        nzbgetGatewayProfile = sanitized;
        return;
      case LunaModule.RADARR:
        radarrGatewayProfile = sanitized;
        return;
      case LunaModule.SABNZBD:
        sabnzbdGatewayProfile = sanitized;
        return;
      case LunaModule.SONARR:
        sonarrGatewayProfile = sanitized;
        return;
      case LunaModule.TAUTULLI:
        tautulliGatewayProfile = sanitized;
        return;
      default:
        return;
    }
  }

  String host(LunaModule module) {
    switch (module) {
      case LunaModule.LIDARR:
        return lidarrHost;
      case LunaModule.NZBGET:
        return nzbgetHost;
      case LunaModule.RADARR:
        return radarrHost;
      case LunaModule.SABNZBD:
        return sabnzbdHost;
      case LunaModule.SONARR:
        return sonarrHost;
      case LunaModule.TAUTULLI:
        return tautulliHost;
      default:
        return '';
    }
  }

  void setHost(LunaModule module, String value) {
    switch (module) {
      case LunaModule.LIDARR:
        lidarrHost = value;
        return;
      case LunaModule.NZBGET:
        nzbgetHost = value;
        return;
      case LunaModule.RADARR:
        radarrHost = value;
        return;
      case LunaModule.SABNZBD:
        sabnzbdHost = value;
        return;
      case LunaModule.SONARR:
        sonarrHost = value;
        return;
      case LunaModule.TAUTULLI:
        tautulliHost = value;
        return;
      default:
        return;
    }
  }

  void setEnabled(LunaModule module, bool value) {
    switch (module) {
      case LunaModule.LIDARR:
        lidarrEnabled = value;
        return;
      case LunaModule.NZBGET:
        nzbgetEnabled = value;
        return;
      case LunaModule.RADARR:
        radarrEnabled = value;
        return;
      case LunaModule.SABNZBD:
        sabnzbdEnabled = value;
        return;
      case LunaModule.SONARR:
        sonarrEnabled = value;
        return;
      case LunaModule.TAUTULLI:
        tautulliEnabled = value;
        return;
      default:
        return;
    }
  }

  String _connectionModeKey(LunaModule module) {
    switch (module) {
      case LunaModule.LIDARR:
        return lidarrConnectionMode;
      case LunaModule.NZBGET:
        return nzbgetConnectionMode;
      case LunaModule.RADARR:
        return radarrConnectionMode;
      case LunaModule.SABNZBD:
        return sabnzbdConnectionMode;
      case LunaModule.SONARR:
        return sonarrConnectionMode;
      case LunaModule.TAUTULLI:
        return tautulliConnectionMode;
      default:
        return '';
    }
  }
}
