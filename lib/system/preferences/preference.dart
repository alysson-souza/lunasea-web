import 'dart:async';

import 'package:lunasea/system/preferences/bios.dart';
import 'package:lunasea/system/preferences/dashboard.dart';
import 'package:lunasea/system/preferences/lidarr.dart';
import 'package:lunasea/system/preferences/lunasea.dart';
import 'package:lunasea/system/preferences/nzbget.dart';
import 'package:lunasea/system/preferences/radarr.dart';
import 'package:lunasea/system/preferences/sabnzbd.dart';
import 'package:lunasea/system/preferences/search.dart';
import 'package:lunasea/system/preferences/sonarr.dart';
import 'package:lunasea/system/preferences/tautulli.dart';
import 'package:lunasea/system/gateway/gateway.dart';

/// Typed preference groups hydrated from, and persisted to, backend-owned state.
enum BackendPreferenceGroup<T extends BackendPreference> {
  bios<BIOSPreferences>('bios', items: BIOSPreferences.values),
  dashboard<DashboardPreferences>('home', items: DashboardPreferences.values),
  lidarr<LidarrPreferences>('lidarr', items: LidarrPreferences.values),
  lunasea<LunaSeaPreferences>('lunasea', items: LunaSeaPreferences.values),
  nzbget<NZBGetPreferences>('nzbget', items: NZBGetPreferences.values),
  radarr<RadarrPreferences>('radarr', items: RadarrPreferences.values),
  sabnzbd<SABnzbdPreferences>('sabnzbd', items: SABnzbdPreferences.values),
  search<SearchPreferences>('search', items: SearchPreferences.values),
  sonarr<SonarrPreferences>('sonarr', items: SonarrPreferences.values),
  tautulli<TautulliPreferences>('tautulli', items: TautulliPreferences.values);

  final String key;
  final List<T> items;

  const BackendPreferenceGroup(
    this.key, {
    required this.items,
  });

  static void hydrate(void Function() load) {
    _BackendPreferenceState.hydrate(load);
  }

  static void clearAll() {
    _BackendPreferenceState.clearAll();
  }

  T? _itemFromKey(String key) {
    for (final item in items) {
      if (item.key == key) return item;
    }
    return null;
  }

  Map<String, dynamic> export() {
    Map<String, dynamic> results = {};

    for (final item in this.items) {
      final value = item.export();
      if (value != null) results[item.key] = value;
    }

    return results;
  }

  void import(Map<String, dynamic>? table) {
    if (table == null || table.isEmpty) return;
    for (final key in table.keys) {
      final db = _itemFromKey(key);
      db?.import(table[key]);
    }
  }
}

mixin BackendPreference<T> on Enum {
  T get fallback;
  BackendPreferenceGroup get table;

  String get key => '${table.key.toUpperCase()}_$name';

  T read() => _BackendPreferenceState.read<T>(table, key, fallback);
  void update(T value) => _BackendPreferenceState.update<T>(table, key, value);

  /// The list of items that are not imported or exported by default.
  List get blockedFromImportExport => [];

  dynamic export() {
    if (blockedFromImportExport.contains(this)) return null;
    return read();
  }

  void import(dynamic value) {
    if (blockedFromImportExport.contains(this) || value == null) return;
    return update(value as T);
  }
}

class _BackendPreferenceState {
  static final Map<BackendPreferenceGroup, Map<String, dynamic>> _items = {};
  static bool _hydrating = false;

  static Map<String, dynamic> _table(BackendPreferenceGroup table) {
    return _items.putIfAbsent(table, () => <String, dynamic>{});
  }

  static void hydrate(void Function() load) {
    _hydrating = true;
    try {
      clearAll();
      load();
    } finally {
      _hydrating = false;
    }
  }

  static void clearAll() {
    _items.clear();
  }

  static T read<T>(BackendPreferenceGroup table, String key, T fallback) {
    return (_table(table)[key] as T?) ?? fallback;
  }

  static void update<T>(BackendPreferenceGroup table, String key, T value) {
    _table(table)[key] = value;
    if (!_hydrating) {
      unawaited(_persistPreference(key, value));
    }
  }

  static Future<void> _persistPreference(String key, dynamic value) async {
    final appField = _appPreferenceFields[key];
    if (appField != null) {
      await LunaGateway.patchAppPreferences({appField: _backendValue(value)});
      return;
    }
    final moduleField = _modulePreferenceFields[key];
    if (moduleField != null) {
      await LunaGateway.patchModulePreferencesKey(moduleField.module, {
        moduleField.field: _backendValue(value),
      });
    }
  }

  static dynamic _backendValue(dynamic value) {
    if (value == null) return null;
    if (value is List) return value.map(_backendValue).toList();
    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(key.toString(), _backendValue(value)),
      );
    }
    try {
      return (value as dynamic).key;
    } catch (_) {
      return value;
    }
  }

  static const Map<String, String> _appPreferenceFields = {
    'BIOS_BOOT_MODULE': 'bootModule',
    'BIOS_FIRST_BOOT': 'firstBoot',
    'LUNASEA_ANDROID_BACK_OPENS_DRAWER': 'androidBackOpensDrawer',
    'LUNASEA_DRAWER_AUTOMATIC_MANAGE': 'drawerAutomaticManage',
    'LUNASEA_DRAWER_MANUAL_ORDER': 'drawerManualOrder',
    'LUNASEA_ENABLED_PROFILE': 'activeProfile',
    'LUNASEA_NETWORKING_TLS_VALIDATION': 'networkingTlsValidation',
    'LUNASEA_THEME_AMOLED': 'themeAmoled',
    'LUNASEA_THEME_AMOLED_BORDER': 'themeAmoledBorder',
    'LUNASEA_THEME_IMAGE_BACKGROUND_OPACITY': 'themeImageBackgroundOpacity',
    'LUNASEA_QUICK_ACTIONS_LIDARR': 'quickActionsLidarr',
    'LUNASEA_QUICK_ACTIONS_RADARR': 'quickActionsRadarr',
    'LUNASEA_QUICK_ACTIONS_SONARR': 'quickActionsSonarr',
    'LUNASEA_QUICK_ACTIONS_NZBGET': 'quickActionsNzbget',
    'LUNASEA_QUICK_ACTIONS_SABNZBD': 'quickActionsSabnzbd',
    'LUNASEA_QUICK_ACTIONS_OVERSEERR': 'quickActionsOverseerr',
    'LUNASEA_QUICK_ACTIONS_TAUTULLI': 'quickActionsTautulli',
    'LUNASEA_QUICK_ACTIONS_SEARCH': 'quickActionsSearch',
    'LUNASEA_USE_24_HOUR_TIME': 'use24HourTime',
    'LUNASEA_ENABLE_IN_APP_NOTIFICATIONS': 'enableInAppNotifications',
    'LUNASEA_CHANGELOG_LAST_BUILD_VERSION': 'changelogLastBuildVersion',
    'SEARCH_HIDE_XXX': 'searchHideXxx',
    'SEARCH_SHOW_LINKS': 'searchShowLinks',
    'HOME_NAVIGATION_INDEX': 'dashboardNavigationIndex',
    'HOME_CALENDAR_STARTING_DAY': 'dashboardCalendarStartingDay',
    'HOME_CALENDAR_STARTING_SIZE': 'dashboardCalendarStartingSize',
    'HOME_CALENDAR_STARTING_TYPE': 'dashboardCalendarStartingType',
    'HOME_CALENDAR_ENABLE_LIDARR': 'dashboardCalendarEnableLidarr',
    'HOME_CALENDAR_ENABLE_RADARR': 'dashboardCalendarEnableRadarr',
    'HOME_CALENDAR_ENABLE_SONARR': 'dashboardCalendarEnableSonarr',
    'HOME_CALENDAR_DAYS_PAST': 'dashboardCalendarDaysPast',
    'HOME_CALENDAR_DAYS_FUTURE': 'dashboardCalendarDaysFuture',
  };

  static const Map<String, ({String module, String field})>
      _modulePreferenceFields = {
    'RADARR_NAVIGATION_INDEX': (module: 'radarr', field: 'navigationIndex'),
    'RADARR_NAVIGATION_INDEX_MOVIE_DETAILS': (
      module: 'radarr',
      field: 'navigationIndexMovieDetails',
    ),
    'RADARR_NAVIGATION_INDEX_ADD_MOVIE': (
      module: 'radarr',
      field: 'navigationIndexAddMovie',
    ),
    'RADARR_NAVIGATION_INDEX_SYSTEM_STATUS': (
      module: 'radarr',
      field: 'navigationIndexSystemStatus',
    ),
    'RADARR_DEFAULT_VIEW_MOVIES': (
      module: 'radarr',
      field: 'defaultViewMovies',
    ),
    'RADARR_DEFAULT_SORTING_MOVIES': (
      module: 'radarr',
      field: 'defaultSortingMovies',
    ),
    'RADARR_DEFAULT_SORTING_MOVIES_ASCENDING': (
      module: 'radarr',
      field: 'defaultSortingMoviesAscending',
    ),
    'RADARR_DEFAULT_FILTERING_MOVIES': (
      module: 'radarr',
      field: 'defaultFilteringMovies',
    ),
    'RADARR_DEFAULT_SORTING_RELEASES': (
      module: 'radarr',
      field: 'defaultSortingReleases',
    ),
    'RADARR_DEFAULT_SORTING_RELEASES_ASCENDING': (
      module: 'radarr',
      field: 'defaultSortingReleasesAscending',
    ),
    'RADARR_DEFAULT_FILTERING_RELEASES': (
      module: 'radarr',
      field: 'defaultFilteringReleases',
    ),
    'RADARR_ADD_MOVIE_DEFAULT_MONITORED_STATE': (
      module: 'radarr',
      field: 'addMovieDefaultMonitoredState',
    ),
    'RADARR_ADD_MOVIE_DEFAULT_ROOT_FOLDER_ID': (
      module: 'radarr',
      field: 'addMovieDefaultRootFolderId',
    ),
    'RADARR_ADD_MOVIE_DEFAULT_QUALITY_PROFILE_ID': (
      module: 'radarr',
      field: 'addMovieDefaultQualityProfileId',
    ),
    'RADARR_ADD_MOVIE_DEFAULT_MINIMUM_AVAILABILITY_ID': (
      module: 'radarr',
      field: 'addMovieDefaultMinimumAvailabilityId',
    ),
    'RADARR_ADD_MOVIE_DEFAULT_TAGS': (
      module: 'radarr',
      field: 'addMovieDefaultTags',
    ),
    'RADARR_ADD_MOVIE_SEARCH_FOR_MISSING': (
      module: 'radarr',
      field: 'addMovieSearchForMissing',
    ),
    'RADARR_ADD_DISCOVER_USE_SUGGESTIONS': (
      module: 'radarr',
      field: 'addDiscoverUseSuggestions',
    ),
    'RADARR_MANUAL_IMPORT_DEFAULT_MODE': (
      module: 'radarr',
      field: 'manualImportDefaultMode',
    ),
    'RADARR_QUEUE_PAGE_SIZE': (module: 'radarr', field: 'queuePageSize'),
    'RADARR_QUEUE_REFRESH_RATE': (module: 'radarr', field: 'queueRefreshRate'),
    'RADARR_QUEUE_BLACKLIST': (module: 'radarr', field: 'queueBlacklist'),
    'RADARR_QUEUE_REMOVE_FROM_CLIENT': (
      module: 'radarr',
      field: 'queueRemoveFromClient',
    ),
    'RADARR_REMOVE_MOVIE_IMPORT_LIST': (
      module: 'radarr',
      field: 'removeMovieImportList',
    ),
    'RADARR_REMOVE_MOVIE_DELETE_FILES': (
      module: 'radarr',
      field: 'removeMovieDeleteFiles',
    ),
    'RADARR_CONTENT_PAGE_SIZE': (module: 'radarr', field: 'contentPageSize'),
    'SONARR_NAVIGATION_INDEX': (module: 'sonarr', field: 'navigationIndex'),
    'SONARR_NAVIGATION_INDEX_SERIES_DETAILS': (
      module: 'sonarr',
      field: 'navigationIndexSeriesDetails',
    ),
    'SONARR_NAVIGATION_INDEX_SEASON_DETAILS': (
      module: 'sonarr',
      field: 'navigationIndexSeasonDetails',
    ),
    'SONARR_ADD_SERIES_SEARCH_FOR_MISSING': (
      module: 'sonarr',
      field: 'addSeriesSearchForMissing',
    ),
    'SONARR_ADD_SERIES_SEARCH_FOR_CUTOFF_UNMET': (
      module: 'sonarr',
      field: 'addSeriesSearchForCutoffUnmet',
    ),
    'SONARR_ADD_SERIES_DEFAULT_MONITORED': (
      module: 'sonarr',
      field: 'addSeriesDefaultMonitored',
    ),
    'SONARR_ADD_SERIES_DEFAULT_USE_SEASON_FOLDERS': (
      module: 'sonarr',
      field: 'addSeriesDefaultUseSeasonFolders',
    ),
    'SONARR_ADD_SERIES_DEFAULT_SERIES_TYPE': (
      module: 'sonarr',
      field: 'addSeriesDefaultSeriesType',
    ),
    'SONARR_ADD_SERIES_DEFAULT_MONITOR_TYPE': (
      module: 'sonarr',
      field: 'addSeriesDefaultMonitorType',
    ),
    'SONARR_ADD_SERIES_DEFAULT_LANGUAGE_PROFILE': (
      module: 'sonarr',
      field: 'addSeriesDefaultLanguageProfile',
    ),
    'SONARR_ADD_SERIES_DEFAULT_QUALITY_PROFILE': (
      module: 'sonarr',
      field: 'addSeriesDefaultQualityProfile',
    ),
    'SONARR_ADD_SERIES_DEFAULT_ROOT_FOLDER': (
      module: 'sonarr',
      field: 'addSeriesDefaultRootFolder',
    ),
    'SONARR_ADD_SERIES_DEFAULT_TAGS': (
      module: 'sonarr',
      field: 'addSeriesDefaultTags',
    ),
    'SONARR_DEFAULT_VIEW_SERIES': (
      module: 'sonarr',
      field: 'defaultViewSeries',
    ),
    'SONARR_DEFAULT_FILTERING_SERIES': (
      module: 'sonarr',
      field: 'defaultFilteringSeries',
    ),
    'SONARR_DEFAULT_FILTERING_RELEASES': (
      module: 'sonarr',
      field: 'defaultFilteringReleases',
    ),
    'SONARR_DEFAULT_SORTING_SERIES': (
      module: 'sonarr',
      field: 'defaultSortingSeries',
    ),
    'SONARR_DEFAULT_SORTING_RELEASES': (
      module: 'sonarr',
      field: 'defaultSortingReleases',
    ),
    'SONARR_DEFAULT_SORTING_SERIES_ASCENDING': (
      module: 'sonarr',
      field: 'defaultSortingSeriesAscending',
    ),
    'SONARR_DEFAULT_SORTING_RELEASES_ASCENDING': (
      module: 'sonarr',
      field: 'defaultSortingReleasesAscending',
    ),
    'SONARR_REMOVE_SERIES_DELETE_FILES': (
      module: 'sonarr',
      field: 'removeSeriesDeleteFiles',
    ),
    'SONARR_REMOVE_SERIES_EXCLUSION_LIST': (
      module: 'sonarr',
      field: 'removeSeriesExclusionList',
    ),
    'SONARR_UPCOMING_FUTURE_DAYS': (
      module: 'sonarr',
      field: 'upcomingFutureDays',
    ),
    'SONARR_QUEUE_PAGE_SIZE': (module: 'sonarr', field: 'queuePageSize'),
    'SONARR_QUEUE_REFRESH_RATE': (module: 'sonarr', field: 'queueRefreshRate'),
    'SONARR_QUEUE_REMOVE_DOWNLOAD_CLIENT': (
      module: 'sonarr',
      field: 'queueRemoveDownloadClient',
    ),
    'SONARR_QUEUE_ADD_BLOCKLIST': (
      module: 'sonarr',
      field: 'queueAddBlocklist',
    ),
    'SONARR_CONTENT_PAGE_SIZE': (module: 'sonarr', field: 'contentPageSize'),
    'LIDARR_NAVIGATION_INDEX': (module: 'lidarr', field: 'navigationIndex'),
    'LIDARR_ADD_MONITORED_STATUS': (
      module: 'lidarr',
      field: 'addMonitoredStatus',
    ),
    'LIDARR_ADD_ARTIST_SEARCH_FOR_MISSING': (
      module: 'lidarr',
      field: 'addArtistSearchForMissing',
    ),
    'LIDARR_ADD_ALBUM_FOLDERS': (module: 'lidarr', field: 'addAlbumFolders'),
    'LIDARR_ADD_QUALITY_PROFILE': (
      module: 'lidarr',
      field: 'addQualityProfile',
    ),
    'LIDARR_ADD_METADATA_PROFILE': (
      module: 'lidarr',
      field: 'addMetadataProfile',
    ),
    'LIDARR_ADD_ROOT_FOLDER': (module: 'lidarr', field: 'addRootFolder'),
    'NZBGET_NAVIGATION_INDEX': (module: 'nzbget', field: 'navigationIndex'),
    'SABNZBD_NAVIGATION_INDEX': (module: 'sabnzbd', field: 'navigationIndex'),
    'TAUTULLI_NAVIGATION_INDEX': (module: 'tautulli', field: 'navigationIndex'),
    'TAUTULLI_NAVIGATION_INDEX_GRAPHS': (
      module: 'tautulli',
      field: 'navigationIndexGraphs',
    ),
    'TAUTULLI_NAVIGATION_INDEX_LIBRARIES_DETAILS': (
      module: 'tautulli',
      field: 'navigationIndexLibrariesDetails',
    ),
    'TAUTULLI_NAVIGATION_INDEX_MEDIA_DETAILS': (
      module: 'tautulli',
      field: 'navigationIndexMediaDetails',
    ),
    'TAUTULLI_NAVIGATION_INDEX_USER_DETAILS': (
      module: 'tautulli',
      field: 'navigationIndexUserDetails',
    ),
    'TAUTULLI_REFRESH_RATE': (module: 'tautulli', field: 'refreshRate'),
    'TAUTULLI_CONTENT_LOAD_LENGTH': (
      module: 'tautulli',
      field: 'contentLoadLength',
    ),
    'TAUTULLI_STATISTICS_STATS_COUNT': (
      module: 'tautulli',
      field: 'statisticsStatsCount',
    ),
    'TAUTULLI_TERMINATION_MESSAGE': (
      module: 'tautulli',
      field: 'terminationMessage',
    ),
    'TAUTULLI_GRAPHS_DAYS': (module: 'tautulli', field: 'graphsDays'),
    'TAUTULLI_GRAPHS_LINECHART_DAYS': (
      module: 'tautulli',
      field: 'graphsLinechartDays',
    ),
    'TAUTULLI_GRAPHS_MONTHS': (module: 'tautulli', field: 'graphsMonths'),
  };
}
