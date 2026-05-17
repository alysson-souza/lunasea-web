import 'package:lunasea/types/list_view_option.dart';
import 'package:lunasea/system/preferences/preference.dart';
import 'package:lunasea/modules/radarr/core/types/filter_movies.dart';
import 'package:lunasea/modules/radarr/core/types/filter_releases.dart';
import 'package:lunasea/modules/radarr/core/types/sorting_movies.dart';
import 'package:lunasea/modules/radarr/core/types/sorting_releases.dart';

enum RadarrPreferences<T> with BackendPreference<T> {
  NAVIGATION_INDEX<int>(0),
  NAVIGATION_INDEX_MOVIE_DETAILS<int>(0),
  NAVIGATION_INDEX_ADD_MOVIE<int>(0),
  NAVIGATION_INDEX_SYSTEM_STATUS<int>(0),
  DEFAULT_VIEW_MOVIES<LunaListViewOption>(LunaListViewOption.BLOCK_VIEW),
  DEFAULT_SORTING_MOVIES<RadarrMoviesSorting>(RadarrMoviesSorting.ALPHABETICAL),
  DEFAULT_SORTING_MOVIES_ASCENDING<bool>(true),
  DEFAULT_FILTERING_MOVIES<RadarrMoviesFilter>(RadarrMoviesFilter.ALL),
  DEFAULT_SORTING_RELEASES<RadarrReleasesSorting>(RadarrReleasesSorting.WEIGHT),
  DEFAULT_SORTING_RELEASES_ASCENDING<bool>(true),
  DEFAULT_FILTERING_RELEASES<RadarrReleasesFilter>(RadarrReleasesFilter.ALL),
  ADD_MOVIE_DEFAULT_MONITORED_STATE<bool>(true),
  ADD_MOVIE_DEFAULT_ROOT_FOLDER_ID<int?>(null),
  ADD_MOVIE_DEFAULT_QUALITY_PROFILE_ID<int?>(null),
  ADD_MOVIE_DEFAULT_MINIMUM_AVAILABILITY_ID<String>('announced'),
  ADD_MOVIE_DEFAULT_TAGS<List>([]),
  ADD_MOVIE_SEARCH_FOR_MISSING<bool>(false),
  ADD_DISCOVER_USE_SUGGESTIONS<bool>(true),
  MANUAL_IMPORT_DEFAULT_MODE<String>('copy'),
  QUEUE_PAGE_SIZE<int>(50),
  QUEUE_REFRESH_RATE<int>(60),
  QUEUE_BLACKLIST<bool>(false),
  QUEUE_REMOVE_FROM_CLIENT<bool>(false),
  REMOVE_MOVIE_IMPORT_LIST<bool>(false),
  REMOVE_MOVIE_DELETE_FILES<bool>(false),
  CONTENT_PAGE_SIZE<int>(10);

  @override
  BackendPreferenceGroup get table => BackendPreferenceGroup.radarr;

  @override
  final T fallback;

  const RadarrPreferences(this.fallback);

  @override
  dynamic export() {
    RadarrPreferences db = this;
    switch (db) {
      case RadarrPreferences.DEFAULT_SORTING_MOVIES:
        return RadarrPreferences.DEFAULT_SORTING_MOVIES.read().key;
      case RadarrPreferences.DEFAULT_SORTING_RELEASES:
        return RadarrPreferences.DEFAULT_SORTING_RELEASES.read().key;
      case RadarrPreferences.DEFAULT_FILTERING_MOVIES:
        return RadarrPreferences.DEFAULT_FILTERING_MOVIES.read().key;
      case RadarrPreferences.DEFAULT_FILTERING_RELEASES:
        return RadarrPreferences.DEFAULT_FILTERING_RELEASES.read().key;
      case RadarrPreferences.DEFAULT_VIEW_MOVIES:
        return RadarrPreferences.DEFAULT_VIEW_MOVIES.read().key;
      default:
        return super.export();
    }
  }

  @override
  void import(dynamic value) {
    RadarrPreferences db = this;
    dynamic result;

    switch (db) {
      case RadarrPreferences.DEFAULT_SORTING_MOVIES:
        result = RadarrMoviesSorting.ALPHABETICAL.fromKey(value.toString());
        break;
      case RadarrPreferences.DEFAULT_SORTING_RELEASES:
        result = RadarrReleasesSorting.ALPHABETICAL.fromKey(value.toString());
        break;
      case RadarrPreferences.DEFAULT_FILTERING_MOVIES:
        result = RadarrMoviesFilter.ALL.fromKey(value.toString());
        break;
      case RadarrPreferences.DEFAULT_FILTERING_RELEASES:
        result = RadarrReleasesFilter.ALL.fromKey(value.toString());
        break;
      case RadarrPreferences.DEFAULT_VIEW_MOVIES:
        result = LunaListViewOption.fromKey(value.toString());
        break;
      default:
        result = value;
        break;
    }

    return super.import(result);
  }
}
