import 'package:lunasea/system/preferences/preference.dart';

enum SearchPreferences<T> with BackendPreference<T> {
  HIDE_XXX<bool>(false),
  SHOW_LINKS<bool>(true);

  @override
  BackendPreferenceGroup get table => BackendPreferenceGroup.search;

  @override
  final T fallback;

  const SearchPreferences(this.fallback);
}
