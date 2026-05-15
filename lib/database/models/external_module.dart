import 'package:lunasea/core.dart';

class LunaExternalModule {
  int id;
  String displayName;
  String host;

  LunaExternalModule({
    this.id = -1,
    this.displayName = '',
    this.host = '',
  });

  @override
  String toString() => json.encode(this.toJson());

  Map<String, dynamic> toJson() => {
        if (id >= 0) 'id': id,
        'displayName': displayName,
        'host': host,
      };

  factory LunaExternalModule.fromJson(Map<String, dynamic> json) {
    return LunaExternalModule(
      id: (json['id'] as num?)?.toInt() ?? -1,
      displayName: json['displayName']?.toString() ?? '',
      host: json['host']?.toString() ?? '',
    );
  }

  factory LunaExternalModule.clone(LunaExternalModule profile) {
    return LunaExternalModule.fromJson(profile.toJson());
  }

  int get key => id;
}
