import 'package:lunasea/system/preferences/preference.dart';

enum SABnzbdPreferences<T> with BackendPreference<T> {
  NAVIGATION_INDEX<int>(0);

  @override
  BackendPreferenceGroup get table => BackendPreferenceGroup.sabnzbd;

  @override
  final T fallback;

  const SABnzbdPreferences(this.fallback);
}
