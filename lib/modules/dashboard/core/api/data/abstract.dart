import 'package:flutter/material.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:lunasea/vendor.dart';

abstract class CalendarData {
  int id;
  String title;
  String sourceInstance;
  LunaServiceInstanceRef sourceRef;
  List<TextSpan> get body;

  String? backgroundUrl(BuildContext context);
  String? posterUrl(BuildContext context);

  Widget trailing(BuildContext context);
  Future<void> enterContent(BuildContext context);
  Future<void> trailingOnPress(BuildContext context);
  Future<void> trailingOnLongPress(BuildContext context);

  CalendarData(this.id, this.title, this.sourceInstance, this.sourceRef);

  LunaServiceInstance? sourceServiceInstance(BuildContext context) {
    final instance = context
        .read<ProfilesStore>()
        .read(sourceRef.profileId)
        ?.instanceByRef(sourceRef);
    if (instance == null || !instance.enabled) return null;
    return instance;
  }
}
