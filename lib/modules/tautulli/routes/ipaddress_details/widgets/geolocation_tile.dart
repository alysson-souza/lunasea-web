import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/tautulli.dart';

class TautulliIPAddressDetailsGeolocationTile extends StatelessWidget {
  final TautulliGeolocationInfo geolocation;

  const TautulliIPAddressDetailsGeolocationTile({
    super.key,
    required this.geolocation,
  });

  @override
  Widget build(BuildContext context) {
    return BackendPreferenceGroupCard(
      content: [
        BackendPreferenceGroupContent(
          title: 'country',
          body: geolocation.country ?? LunaUI.TEXT_EMDASH,
        ),
        BackendPreferenceGroupContent(
          title: 'region',
          body: geolocation.region ?? LunaUI.TEXT_EMDASH,
        ),
        BackendPreferenceGroupContent(
          title: 'city',
          body: geolocation.city ?? LunaUI.TEXT_EMDASH,
        ),
        BackendPreferenceGroupContent(
          title: 'postal',
          body: geolocation.postalCode ?? LunaUI.TEXT_EMDASH,
        ),
        BackendPreferenceGroupContent(
          title: 'timezone',
          body: geolocation.timezone ?? LunaUI.TEXT_EMDASH,
        ),
        BackendPreferenceGroupContent(
          title: 'latitude',
          body: '${geolocation.latitude ?? LunaUI.TEXT_EMDASH}',
        ),
        BackendPreferenceGroupContent(
          title: 'longitude',
          body: '${geolocation.longitude ?? LunaUI.TEXT_EMDASH}',
        ),
      ],
    );
  }
}
