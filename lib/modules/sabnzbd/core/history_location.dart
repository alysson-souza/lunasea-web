import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';

class SABnzbdHistoryLocation {
  final String nzoId;
  final String profileId;
  final String configuration;

  const SABnzbdHistoryLocation._({
    required this.nzoId,
    required this.profileId,
    required this.configuration,
  });

  factory SABnzbdHistoryLocation.forInstance(
    LunaServiceInstance instance,
    String nzoId,
  ) => SABnzbdHistoryLocation._(
    nzoId: nzoId,
    profileId: instance.profileId,
    configuration: _fingerprint(instance),
  );

  static SABnzbdHistoryLocation? fromQuery(Map<String, String> query) {
    final nzoId = query['nzoId'];
    final profileId = query['profile'];
    final configuration = query['configuration'];
    if (nzoId == null ||
        nzoId.isEmpty ||
        profileId == null ||
        profileId.isEmpty ||
        configuration == null ||
        configuration.isEmpty) {
      return null;
    }
    return SABnzbdHistoryLocation._(
      nzoId: nzoId,
      profileId: profileId,
      configuration: configuration,
    );
  }

  Map<String, String> get queryParameters => {
    'nzoId': nzoId,
    'profile': profileId,
    'configuration': configuration,
  };

  bool matches(LunaServiceInstance instance, String activeProfile) =>
      profileId == activeProfile &&
      profileId == instance.profileId &&
      instance.module == LunaModule.SABNZBD &&
      instance.enabled &&
      instance.host.trim().isNotEmpty &&
      configuration == _fingerprint(instance);

  static String _fingerprint(LunaServiceInstance instance) => sha256
      .convert(utf8.encode(jsonEncode(_canonical(instance.toJson()))))
      .toString();

  static dynamic _canonical(dynamic value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }
}
