import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/vendor.dart';

class LunaProfile {
  static const String DEFAULT_PROFILE = 'default';

  String key;

  @JsonKey()
  List<LunaServiceInstance> serviceInstances;

  @JsonKey()
  bool lidarrEnabled;

  @JsonKey()
  String lidarrHost;

  @JsonKey()
  String lidarrKey;

  @JsonKey()
  Map<String, String> lidarrHeaders;

  @JsonKey()
  String lidarrConnectionMode;

  @JsonKey()
  String lidarrGatewayProfile;

  @JsonKey()
  bool radarrEnabled;

  @JsonKey()
  String radarrHost;

  @JsonKey()
  String radarrKey;

  @JsonKey()
  Map<String, String> radarrHeaders;

  @JsonKey()
  String radarrConnectionMode;

  @JsonKey()
  String radarrGatewayProfile;

  @JsonKey()
  bool sonarrEnabled;

  @JsonKey()
  String sonarrHost;

  @JsonKey()
  String sonarrKey;

  @JsonKey()
  Map<String, String> sonarrHeaders;

  @JsonKey()
  String sonarrConnectionMode;

  @JsonKey()
  String sonarrGatewayProfile;

  @JsonKey()
  bool sabnzbdEnabled;

  @JsonKey()
  String sabnzbdHost;

  @JsonKey()
  String sabnzbdKey;

  @JsonKey()
  Map<String, String> sabnzbdHeaders;

  @JsonKey()
  String sabnzbdConnectionMode;

  @JsonKey()
  String sabnzbdGatewayProfile;

  @JsonKey()
  bool nzbgetEnabled;

  @JsonKey()
  String nzbgetHost;

  @JsonKey()
  String nzbgetUser;

  @JsonKey()
  String nzbgetPass;

  @JsonKey()
  Map<String, String> nzbgetHeaders;

  @JsonKey()
  String nzbgetConnectionMode;

  @JsonKey()
  String nzbgetGatewayProfile;

  @JsonKey()
  bool wakeOnLANEnabled;

  @JsonKey()
  String wakeOnLANBroadcastAddress;

  @JsonKey()
  String wakeOnLANMACAddress;

  @JsonKey()
  bool tautulliEnabled;

  @JsonKey()
  String tautulliHost;

  @JsonKey()
  String tautulliKey;

  @JsonKey()
  Map<String, String> tautulliHeaders;

  @JsonKey()
  String tautulliConnectionMode;

  @JsonKey()
  String tautulliGatewayProfile;

  @JsonKey()
  bool overseerrEnabled;

  @JsonKey()
  String overseerrHost;

  @JsonKey()
  String overseerrKey;

  @JsonKey()
  Map<String, String> overseerrHeaders;

  LunaProfile._internal({
    required this.key,
    required this.serviceInstances,
    //Lidarr
    required this.lidarrEnabled,
    required this.lidarrHost,
    required this.lidarrKey,
    required this.lidarrHeaders,
    required this.lidarrConnectionMode,
    required this.lidarrGatewayProfile,
    //Radarr
    required this.radarrEnabled,
    required this.radarrHost,
    required this.radarrKey,
    required this.radarrHeaders,
    required this.radarrConnectionMode,
    required this.radarrGatewayProfile,
    //Sonarr
    required this.sonarrEnabled,
    required this.sonarrHost,
    required this.sonarrKey,
    required this.sonarrHeaders,
    required this.sonarrConnectionMode,
    required this.sonarrGatewayProfile,
    //SABnzbd
    required this.sabnzbdEnabled,
    required this.sabnzbdHost,
    required this.sabnzbdKey,
    required this.sabnzbdHeaders,
    required this.sabnzbdConnectionMode,
    required this.sabnzbdGatewayProfile,
    //NZBGet
    required this.nzbgetEnabled,
    required this.nzbgetHost,
    required this.nzbgetUser,
    required this.nzbgetPass,
    required this.nzbgetHeaders,
    required this.nzbgetConnectionMode,
    required this.nzbgetGatewayProfile,
    //Wake On LAN
    required this.wakeOnLANEnabled,
    required this.wakeOnLANBroadcastAddress,
    required this.wakeOnLANMACAddress,
    //Tautulli
    required this.tautulliEnabled,
    required this.tautulliHost,
    required this.tautulliKey,
    required this.tautulliHeaders,
    required this.tautulliConnectionMode,
    required this.tautulliGatewayProfile,
    //Overseerr
    required this.overseerrEnabled,
    required this.overseerrHost,
    required this.overseerrKey,
    required this.overseerrHeaders,
  });

  factory LunaProfile({
    String? key,
    List<LunaServiceInstance>? serviceInstances,
    //Lidarr
    bool? lidarrEnabled,
    String? lidarrHost,
    String? lidarrKey,
    Map<String, String>? lidarrHeaders,
    String? lidarrConnectionMode,
    String? lidarrGatewayProfile,
    //Radarr
    bool? radarrEnabled,
    String? radarrHost,
    String? radarrKey,
    Map<String, String>? radarrHeaders,
    String? radarrConnectionMode,
    String? radarrGatewayProfile,
    //Sonarr
    bool? sonarrEnabled,
    String? sonarrHost,
    String? sonarrKey,
    Map<String, String>? sonarrHeaders,
    String? sonarrConnectionMode,
    String? sonarrGatewayProfile,
    //SABnzbd
    bool? sabnzbdEnabled,
    String? sabnzbdHost,
    String? sabnzbdKey,
    Map<String, String>? sabnzbdHeaders,
    String? sabnzbdConnectionMode,
    String? sabnzbdGatewayProfile,
    //NZBGet
    bool? nzbgetEnabled,
    String? nzbgetHost,
    String? nzbgetUser,
    String? nzbgetPass,
    Map<String, String>? nzbgetHeaders,
    String? nzbgetConnectionMode,
    String? nzbgetGatewayProfile,
    //Wake On LAN
    bool? wakeOnLANEnabled,
    String? wakeOnLANBroadcastAddress,
    String? wakeOnLANMACAddress,
    //Tautulli
    bool? tautulliEnabled,
    String? tautulliHost,
    String? tautulliKey,
    Map<String, String>? tautulliHeaders,
    String? tautulliConnectionMode,
    String? tautulliGatewayProfile,
    //Overseerr
    bool? overseerrEnabled,
    String? overseerrHost,
    String? overseerrKey,
    Map<String, String>? overseerrHeaders,
  }) {
    return LunaProfile._internal(
      key: key ?? DEFAULT_PROFILE,
      serviceInstances: _copyServiceInstances(serviceInstances),
      // Lidarr
      lidarrEnabled: lidarrEnabled ?? false,
      lidarrHost: lidarrHost ?? '',
      lidarrKey: lidarrKey ?? '',
      lidarrHeaders: lidarrHeaders ?? {},
      lidarrConnectionMode: lidarrConnectionMode ?? '',
      lidarrGatewayProfile: lidarrGatewayProfile ?? '',
      // Radarr
      radarrEnabled: radarrEnabled ?? false,
      radarrHost: radarrHost ?? '',
      radarrKey: radarrKey ?? '',
      radarrHeaders: radarrHeaders ?? {},
      radarrConnectionMode: radarrConnectionMode ?? '',
      radarrGatewayProfile: radarrGatewayProfile ?? '',
      // Sonarr
      sonarrEnabled: sonarrEnabled ?? false,
      sonarrHost: sonarrHost ?? '',
      sonarrKey: sonarrKey ?? '',
      sonarrHeaders: sonarrHeaders ?? {},
      sonarrConnectionMode: sonarrConnectionMode ?? '',
      sonarrGatewayProfile: sonarrGatewayProfile ?? '',
      // SABnzbd
      sabnzbdEnabled: sabnzbdEnabled ?? false,
      sabnzbdHost: sabnzbdHost ?? '',
      sabnzbdKey: sabnzbdKey ?? '',
      sabnzbdHeaders: sabnzbdHeaders ?? {},
      sabnzbdConnectionMode: sabnzbdConnectionMode ?? '',
      sabnzbdGatewayProfile: sabnzbdGatewayProfile ?? '',
      // NZBGet
      nzbgetEnabled: nzbgetEnabled ?? false,
      nzbgetHost: nzbgetHost ?? '',
      nzbgetUser: nzbgetUser ?? '',
      nzbgetPass: nzbgetPass ?? '',
      nzbgetHeaders: nzbgetHeaders ?? {},
      nzbgetConnectionMode: nzbgetConnectionMode ?? '',
      nzbgetGatewayProfile: nzbgetGatewayProfile ?? '',
      // Wake On LAN
      wakeOnLANEnabled: wakeOnLANEnabled ?? false,
      wakeOnLANBroadcastAddress: wakeOnLANBroadcastAddress ?? '',
      wakeOnLANMACAddress: wakeOnLANMACAddress ?? '',
      // Tautulli
      tautulliEnabled: tautulliEnabled ?? false,
      tautulliHost: tautulliHost ?? '',
      tautulliKey: tautulliKey ?? '',
      tautulliHeaders: tautulliHeaders ?? {},
      tautulliConnectionMode: tautulliConnectionMode ?? '',
      tautulliGatewayProfile: tautulliGatewayProfile ?? '',
      // Overseerr
      overseerrEnabled: overseerrEnabled ?? false,
      overseerrHost: overseerrHost ?? '',
      overseerrKey: overseerrKey ?? '',
      overseerrHeaders: overseerrHeaders ?? {},
    );
  }

  @override
  String toString() => json.encode(this.toJson());

  Map<String, dynamic> toJson() => {
    'key': key.toString(),
    'serviceInstances': serviceInstances
        .map((instance) => instance.toJson())
        .toList(),
    'lidarrEnabled': lidarrEnabled,
    'lidarrHost': lidarrHost,
    'lidarrKey': lidarrKey,
    'lidarrHeaders': lidarrHeaders,
    'lidarrConnectionMode': lidarrConnectionMode,
    'lidarrGatewayProfile': lidarrGatewayProfile,
    'radarrEnabled': radarrEnabled,
    'radarrHost': radarrHost,
    'radarrKey': radarrKey,
    'radarrHeaders': radarrHeaders,
    'radarrConnectionMode': radarrConnectionMode,
    'radarrGatewayProfile': radarrGatewayProfile,
    'sonarrEnabled': sonarrEnabled,
    'sonarrHost': sonarrHost,
    'sonarrKey': sonarrKey,
    'sonarrHeaders': sonarrHeaders,
    'sonarrConnectionMode': sonarrConnectionMode,
    'sonarrGatewayProfile': sonarrGatewayProfile,
    'sabnzbdEnabled': sabnzbdEnabled,
    'sabnzbdHost': sabnzbdHost,
    'sabnzbdKey': sabnzbdKey,
    'sabnzbdHeaders': sabnzbdHeaders,
    'sabnzbdConnectionMode': sabnzbdConnectionMode,
    'sabnzbdGatewayProfile': sabnzbdGatewayProfile,
    'nzbgetEnabled': nzbgetEnabled,
    'nzbgetHost': nzbgetHost,
    'nzbgetUser': nzbgetUser,
    'nzbgetPass': nzbgetPass,
    'nzbgetHeaders': nzbgetHeaders,
    'nzbgetConnectionMode': nzbgetConnectionMode,
    'nzbgetGatewayProfile': nzbgetGatewayProfile,
    'wakeOnLANEnabled': wakeOnLANEnabled,
    'wakeOnLANBroadcastAddress': wakeOnLANBroadcastAddress,
    'wakeOnLANMACAddress': wakeOnLANMACAddress,
    'tautulliEnabled': tautulliEnabled,
    'tautulliHost': tautulliHost,
    'tautulliKey': tautulliKey,
    'tautulliHeaders': tautulliHeaders,
    'tautulliConnectionMode': tautulliConnectionMode,
    'tautulliGatewayProfile': tautulliGatewayProfile,
    'overseerrEnabled': overseerrEnabled,
    'overseerrHost': overseerrHost,
    'overseerrKey': overseerrKey,
    'overseerrHeaders': overseerrHeaders,
  };

  factory LunaProfile.fromJson(Map<String, dynamic> json) {
    return LunaProfile(
      key: json['key']?.toString(),
      serviceInstances: _serviceInstances(json['serviceInstances']),
      lidarrEnabled: json['lidarrEnabled'] as bool?,
      lidarrHost: json['lidarrHost']?.toString(),
      lidarrKey: json['lidarrKey']?.toString(),
      lidarrHeaders: _stringMap(json['lidarrHeaders']),
      lidarrConnectionMode: json['lidarrConnectionMode']?.toString(),
      lidarrGatewayProfile: json['lidarrGatewayProfile']?.toString(),
      radarrEnabled: json['radarrEnabled'] as bool?,
      radarrHost: json['radarrHost']?.toString(),
      radarrKey: json['radarrKey']?.toString(),
      radarrHeaders: _stringMap(json['radarrHeaders']),
      radarrConnectionMode: json['radarrConnectionMode']?.toString(),
      radarrGatewayProfile: json['radarrGatewayProfile']?.toString(),
      sonarrEnabled: json['sonarrEnabled'] as bool?,
      sonarrHost: json['sonarrHost']?.toString(),
      sonarrKey: json['sonarrKey']?.toString(),
      sonarrHeaders: _stringMap(json['sonarrHeaders']),
      sonarrConnectionMode: json['sonarrConnectionMode']?.toString(),
      sonarrGatewayProfile: json['sonarrGatewayProfile']?.toString(),
      sabnzbdEnabled: json['sabnzbdEnabled'] as bool?,
      sabnzbdHost: json['sabnzbdHost']?.toString(),
      sabnzbdKey: json['sabnzbdKey']?.toString(),
      sabnzbdHeaders: _stringMap(json['sabnzbdHeaders']),
      sabnzbdConnectionMode: json['sabnzbdConnectionMode']?.toString(),
      sabnzbdGatewayProfile: json['sabnzbdGatewayProfile']?.toString(),
      nzbgetEnabled: json['nzbgetEnabled'] as bool?,
      nzbgetHost: json['nzbgetHost']?.toString(),
      nzbgetUser: json['nzbgetUser']?.toString(),
      nzbgetPass: json['nzbgetPass']?.toString(),
      nzbgetHeaders: _stringMap(json['nzbgetHeaders']),
      nzbgetConnectionMode: json['nzbgetConnectionMode']?.toString(),
      nzbgetGatewayProfile: json['nzbgetGatewayProfile']?.toString(),
      wakeOnLANEnabled: json['wakeOnLANEnabled'] as bool?,
      wakeOnLANBroadcastAddress: json['wakeOnLANBroadcastAddress']?.toString(),
      wakeOnLANMACAddress: json['wakeOnLANMACAddress']?.toString(),
      tautulliEnabled: json['tautulliEnabled'] as bool?,
      tautulliHost: json['tautulliHost']?.toString(),
      tautulliKey: json['tautulliKey']?.toString(),
      tautulliHeaders: _stringMap(json['tautulliHeaders']),
      tautulliConnectionMode: json['tautulliConnectionMode']?.toString(),
      tautulliGatewayProfile: json['tautulliGatewayProfile']?.toString(),
      overseerrEnabled: json['overseerrEnabled'] as bool?,
      overseerrHost: json['overseerrHost']?.toString(),
      overseerrKey: json['overseerrKey']?.toString(),
      overseerrHeaders: _stringMap(json['overseerrHeaders']),
    );
  }

  factory LunaProfile.clone(LunaProfile profile) {
    return LunaProfile.fromJson(profile.toJson().cast<String, dynamic>());
  }

  static Map<String, String> _stringMap(dynamic value) {
    if (value is! Map) return {};
    return value.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  static List<LunaServiceInstance> _serviceInstances(dynamic value) {
    if (value is! List) return [];
    final instances = <LunaServiceInstance>[];
    for (final item in value) {
      if (item is! Map) continue;
      try {
        instances.add(
          LunaServiceInstance.fromJson(Map<String, dynamic>.from(item)),
        );
      } on Object {
        continue;
      }
    }
    return instances;
  }

  static List<LunaServiceInstance> _copyServiceInstances(
    List<LunaServiceInstance>? value,
  ) {
    if (value == null) return [];
    return value
        .map((instance) => LunaServiceInstance.fromJson(instance.toJson()))
        .toList();
  }

  List<LunaServiceInstance> instancesFor(LunaModule module) {
    final instances = serviceInstances
        .where((instance) => instance.module == module)
        .toList();
    instances.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      final name = a.displayName.toLowerCase().compareTo(
        b.displayName.toLowerCase(),
      );
      if (name != 0) return name;
      return a.id.compareTo(b.id);
    });
    return instances;
  }

  List<LunaServiceInstance> enabledInstances(LunaModule module) {
    return instancesFor(module).where((instance) => instance.enabled).toList();
  }

  bool isModuleAvailable(LunaModule module) {
    return enabledInstances(module).isNotEmpty;
  }

  LunaServiceInstance? instanceByRef(LunaServiceInstanceRef ref) {
    for (final instance in serviceInstances) {
      if (instance.key == ref.key) return instance;
    }
    return null;
  }
}
