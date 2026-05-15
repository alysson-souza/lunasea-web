import 'package:lunasea/core.dart';

class LunaIndexer {
  int id;
  String displayName;

  String host;

  String apiKey;

  Map<String, String> headers;

  LunaIndexer._internal({
    required this.id,
    required this.displayName,
    required this.host,
    required this.apiKey,
    required this.headers,
  });

  factory LunaIndexer({
    int? id,
    String? displayName,
    String? host,
    String? apiKey,
    Map<String, String>? headers,
  }) {
    return LunaIndexer._internal(
      id: id ?? -1,
      displayName: displayName ?? '',
      host: host ?? '',
      apiKey: apiKey ?? '',
      headers: headers ?? {},
    );
  }

  @override
  String toString() => json.encode(this.toJson());

  Map<String, dynamic> toJson() => {
        if (id >= 0) 'id': id,
        'displayName': displayName,
        'host': host,
        'key': apiKey,
        'headers': headers,
      };

  factory LunaIndexer.fromJson(Map<String, dynamic> json) {
    return LunaIndexer(
      id: (json['id'] as num?)?.toInt(),
      displayName: json['displayName']?.toString(),
      host: json['host']?.toString(),
      apiKey: (json['key'] ?? json['apiKey'])?.toString(),
      headers: Map<String, String>.from(json['headers'] as Map? ?? const {}),
    );
  }

  factory LunaIndexer.clone(LunaIndexer profile) {
    return LunaIndexer.fromJson(profile.toJson());
  }

  int get key => id;
}
