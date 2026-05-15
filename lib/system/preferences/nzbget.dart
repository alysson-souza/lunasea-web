import 'package:lunasea/system/preferences/preference.dart';

enum NZBGetPreferences<T> with BackendPreference<T> {
  NAVIGATION_INDEX<int>(0);

  @override
  BackendPreferenceGroup get table => BackendPreferenceGroup.nzbget;

  @override
  final T fallback;

  const NZBGetPreferences(this.fallback);
}
