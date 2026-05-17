import 'package:lunasea/database/models/external_module.dart';
import 'package:lunasea/database/models/indexer.dart';
import 'package:lunasea/database/models/log.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/system/preferences/preference.dart';
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
import 'package:lunasea/modules.dart';
import 'package:lunasea/system/gateway/connection_mode.dart';
import 'package:lunasea/types/log_type.dart';

class LunaBackendState {
  LunaBackendState._();

  static final Map<String, LunaProfile> profiles = {};
  static final Map<int, LunaIndexer> indexers = {};
  static final Map<int, LunaExternalModule> externalModules = {};
  static final Set<String> dismissedBanners = {};
  static final Map<int, LunaLog> logs = {};

  static void clear() {
    profiles.clear();
    indexers.clear();
    externalModules.clear();
    dismissedBanners.clear();
    logs.clear();
    BackendPreferenceGroup.clearAll();
  }

  static Future<void> hydrate(Map<String, dynamic> state) async {
    profiles.clear();
    indexers.clear();
    externalModules.clear();
    dismissedBanners.clear();
    logs.clear();

    BackendPreferenceGroup.hydrate(() {
      _hydratePreferences(state);
    });
    _hydrateProfiles(state);
    _hydrateIndexers(state);
    _hydrateExternalModules(state);
    _hydrateDismissedBanners(state);
    _hydrateLogs(state);
  }

  static void _hydrateProfiles(Map<String, dynamic> state) {
    final hasServiceInstances = state.containsKey('serviceInstances');
    final records = _recordList(state['profiles']);
    final instances = _recordList(state['serviceInstances']);
    final connections = _recordList(state['serviceConnections']);

    final profileIds = records
        .map(
          (record) => record['id']?.toString() ?? LunaProfile.DEFAULT_PROFILE,
        )
        .toList();
    if (profileIds.isEmpty) {
      profileIds.addAll(
        instances.map(
          (record) =>
              record['profile']?.toString() ?? LunaProfile.DEFAULT_PROFILE,
        ),
      );
    }
    if (profileIds.isEmpty) {
      profileIds.addAll(
        connections.map(
          (record) =>
              record['profile']?.toString() ?? LunaProfile.DEFAULT_PROFILE,
        ),
      );
    }
    if (profileIds.isEmpty) {
      profileIds.add(LunaProfile.DEFAULT_PROFILE);
    }

    for (final id in profileIds.toSet()) {
      final profile = LunaProfile(key: id);
      _attachServiceInstances(profile, instances);
      if (!hasServiceInstances) {
        _attachLegacyServiceConnections(profile, connections);
      }
      profiles[id] = profile;
    }
  }

  static void _attachServiceInstances(
    LunaProfile profile,
    List<Map<String, dynamic>> records,
  ) {
    for (final record in records) {
      try {
        final instance = LunaServiceInstance.fromJson(record);
        if (instance.profileId != profile.key) continue;
        profile.serviceInstances.add(instance);
        if (instance.enabled) {
          _markGatewayConnection(profile, instance.module, profile.key);
        }
      } on Object {
        continue;
      }
    }
  }

  static void _attachLegacyServiceConnections(
    LunaProfile profile,
    List<Map<String, dynamic>> records,
  ) {
    for (final connection in records) {
      if (connection['profile']?.toString() != profile.key) continue;
      final module = LunaModule.fromKey(connection['service']?.toString());
      if (module == null) continue;
      final instance = LunaServiceInstance(
        id: connection['id']?.toString() ?? LunaProfile.DEFAULT_PROFILE,
        profileId: profile.key,
        module: module,
        displayName: connection['displayName']?.toString() ?? module.title,
        enabled: connection['enabled'] != false,
        connectionMode: LunaConnectionMode.gateway.key,
        host: connection['upstreamUrl']?.toString() ?? '',
        apiKey: connection['apiKey']?.toString() ?? '',
        username: connection['username']?.toString() ?? '',
        password: connection['password']?.toString() ?? '',
        headers: _stringMap(connection['headers']),
      );
      profile.serviceInstances.add(instance);
      if (instance.enabled)
        _markGatewayConnection(profile, module, profile.key);
    }
  }

  static List<Map<String, dynamic>> _recordList(dynamic value) {
    if (value is! List) return [];
    final records = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is! Map) continue;
      records.add(item.map((key, value) => MapEntry(key.toString(), value)));
    }
    return records;
  }

  static Map<String, String> _stringMap(dynamic value) {
    if (value is! Map) return {};
    return value.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  static void _markGatewayConnection(
    LunaProfile profile,
    LunaModule module,
    String gatewayProfile,
  ) {
    switch (module) {
      case LunaModule.LIDARR:
        profile.lidarrEnabled = true;
        profile.lidarrConnectionMode = LunaConnectionMode.gateway.key;
        profile.lidarrGatewayProfile = gatewayProfile;
        profile.lidarrHost = '';
        return;
      case LunaModule.NZBGET:
        profile.nzbgetEnabled = true;
        profile.nzbgetConnectionMode = LunaConnectionMode.gateway.key;
        profile.nzbgetGatewayProfile = gatewayProfile;
        profile.nzbgetHost = '';
        return;
      case LunaModule.RADARR:
        profile.radarrEnabled = true;
        profile.radarrConnectionMode = LunaConnectionMode.gateway.key;
        profile.radarrGatewayProfile = gatewayProfile;
        profile.radarrHost = '';
        return;
      case LunaModule.SABNZBD:
        profile.sabnzbdEnabled = true;
        profile.sabnzbdConnectionMode = LunaConnectionMode.gateway.key;
        profile.sabnzbdGatewayProfile = gatewayProfile;
        profile.sabnzbdHost = '';
        return;
      case LunaModule.SONARR:
        profile.sonarrEnabled = true;
        profile.sonarrConnectionMode = LunaConnectionMode.gateway.key;
        profile.sonarrGatewayProfile = gatewayProfile;
        profile.sonarrHost = '';
        return;
      case LunaModule.TAUTULLI:
        profile.tautulliEnabled = true;
        profile.tautulliConnectionMode = LunaConnectionMode.gateway.key;
        profile.tautulliGatewayProfile = gatewayProfile;
        profile.tautulliHost = '';
        return;
      case LunaModule.DASHBOARD:
      case LunaModule.EXTERNAL_MODULES:
      case LunaModule.OVERSEERR:
      case LunaModule.SEARCH:
      case LunaModule.SETTINGS:
      case LunaModule.WAKE_ON_LAN:
        return;
    }
  }

  static void _hydrateIndexers(Map<String, dynamic> state) {
    for (final item in state['indexers'] as List? ?? const []) {
      final map = Map<String, dynamic>.from(item as Map);
      final id = (map['id'] as num?)?.toInt();
      if (id == null) continue;
      indexers[id] = LunaIndexer.fromJson({
        'id': id,
        'displayName': map['displayName'] ?? '',
        'host': map['host'] ?? '',
        'key': map['apiKey'] ?? '',
        'headers': Map<String, String>.from(map['headers'] as Map? ?? const {}),
      });
    }
  }

  static void _hydrateExternalModules(Map<String, dynamic> state) {
    for (final item in state['externalModules'] as List? ?? const []) {
      final map = Map<String, dynamic>.from(item as Map);
      final id = (map['id'] as num?)?.toInt();
      if (id == null) continue;
      externalModules[id] = LunaExternalModule.fromJson({
        'id': id,
        'displayName': map['displayName'] ?? '',
        'host': map['host'] ?? '',
      });
    }
  }

  static void _hydrateDismissedBanners(Map<String, dynamic> state) {
    for (final key in state['dismissedBanners'] as List? ?? const []) {
      dismissedBanners.add(key.toString());
    }
  }

  static void _hydrateLogs(Map<String, dynamic> state) {
    for (final item in state['logs'] as List? ?? const []) {
      final map = Map<String, dynamic>.from(item as Map);
      final id = (map['id'] as num?)?.toInt();
      if (id == null) continue;
      logs[id] = LunaLog(
        timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
        type: LunaLogType.DEBUG,
        message: map['message']?.toString() ?? '',
        error: map['error']?.toString(),
        stackTrace: (map['stackTrace'] as List?)?.join('\n'),
      );
    }
  }

  static void _hydratePreferences(Map<String, dynamic> state) {
    final preferences = Map<String, dynamic>.from(
      state['preferences'] as Map? ?? const {},
    );
    final modules = Map<String, dynamic>.from(
      state['modulePreferences'] as Map? ?? const {},
    );

    BackendPreferenceGroup.bios.import({
      BIOSPreferences.BOOT_MODULE.key: preferences['bootModule'],
      BIOSPreferences.FIRST_BOOT.key: preferences['firstBoot'],
    });
    BackendPreferenceGroup.lunasea.import({
      LunaSeaPreferences.ANDROID_BACK_OPENS_DRAWER.key:
          preferences['androidBackOpensDrawer'],
      LunaSeaPreferences.DRAWER_AUTOMATIC_MANAGE.key:
          preferences['drawerAutomaticManage'],
      LunaSeaPreferences.DRAWER_MANUAL_ORDER.key:
          preferences['drawerManualOrder'],
      LunaSeaPreferences.ENABLED_PROFILE.key:
          state['activeProfile'] ?? preferences['activeProfile'],
      LunaSeaPreferences.NETWORKING_TLS_VALIDATION.key:
          preferences['networkingTlsValidation'],
      LunaSeaPreferences.THEME_AMOLED.key: preferences['themeAmoled'],
      LunaSeaPreferences.THEME_AMOLED_BORDER.key:
          preferences['themeAmoledBorder'],
      LunaSeaPreferences.THEME_IMAGE_BACKGROUND_OPACITY.key:
          preferences['themeImageBackgroundOpacity'],
      LunaSeaPreferences.QUICK_ACTIONS_LIDARR.key:
          preferences['quickActionsLidarr'],
      LunaSeaPreferences.QUICK_ACTIONS_RADARR.key:
          preferences['quickActionsRadarr'],
      LunaSeaPreferences.QUICK_ACTIONS_SONARR.key:
          preferences['quickActionsSonarr'],
      LunaSeaPreferences.QUICK_ACTIONS_NZBGET.key:
          preferences['quickActionsNzbget'],
      LunaSeaPreferences.QUICK_ACTIONS_SABNZBD.key:
          preferences['quickActionsSabnzbd'],
      LunaSeaPreferences.QUICK_ACTIONS_OVERSEERR.key:
          preferences['quickActionsOverseerr'],
      LunaSeaPreferences.QUICK_ACTIONS_TAUTULLI.key:
          preferences['quickActionsTautulli'],
      LunaSeaPreferences.QUICK_ACTIONS_SEARCH.key:
          preferences['quickActionsSearch'],
      LunaSeaPreferences.USE_24_HOUR_TIME.key: preferences['use24HourTime'],
      LunaSeaPreferences.ENABLE_IN_APP_NOTIFICATIONS.key:
          preferences['enableInAppNotifications'],
      LunaSeaPreferences.CHANGELOG_LAST_BUILD_VERSION.key:
          preferences['changelogLastBuildVersion'],
    });
    BackendPreferenceGroup.search.import({
      SearchPreferences.HIDE_XXX.key: preferences['searchHideXxx'],
      SearchPreferences.SHOW_LINKS.key: preferences['searchShowLinks'],
    });
    BackendPreferenceGroup.dashboard.import({
      DashboardPreferences.NAVIGATION_INDEX.key:
          preferences['dashboardNavigationIndex'],
      DashboardPreferences.CALENDAR_STARTING_DAY.key:
          preferences['dashboardCalendarStartingDay'],
      DashboardPreferences.CALENDAR_STARTING_SIZE.key:
          preferences['dashboardCalendarStartingSize'],
      DashboardPreferences.CALENDAR_STARTING_TYPE.key:
          preferences['dashboardCalendarStartingType'],
      DashboardPreferences.CALENDAR_ENABLE_LIDARR.key:
          preferences['dashboardCalendarEnableLidarr'],
      DashboardPreferences.CALENDAR_ENABLE_RADARR.key:
          preferences['dashboardCalendarEnableRadarr'],
      DashboardPreferences.CALENDAR_ENABLE_SONARR.key:
          preferences['dashboardCalendarEnableSonarr'],
      DashboardPreferences.CALENDAR_DAYS_PAST.key:
          preferences['dashboardCalendarDaysPast'],
      DashboardPreferences.CALENDAR_DAYS_FUTURE.key:
          preferences['dashboardCalendarDaysFuture'],
    });
    _hydrateRadarr(
      Map<String, dynamic>.from(
        modules[LunaModule.RADARR.key] as Map? ?? const {},
      ),
    );
    _hydrateSonarr(
      Map<String, dynamic>.from(
        modules[LunaModule.SONARR.key] as Map? ?? const {},
      ),
    );
    _hydrateLidarr(
      Map<String, dynamic>.from(
        modules[LunaModule.LIDARR.key] as Map? ?? const {},
      ),
    );
    BackendPreferenceGroup.nzbget.import({
      NZBGetPreferences.NAVIGATION_INDEX.key:
          (modules[LunaModule.NZBGET.key] as Map?)?['navigationIndex'],
    });
    BackendPreferenceGroup.sabnzbd.import({
      SABnzbdPreferences.NAVIGATION_INDEX.key:
          (modules[LunaModule.SABNZBD.key] as Map?)?['navigationIndex'],
    });
    _hydrateTautulli(
      Map<String, dynamic>.from(
        modules[LunaModule.TAUTULLI.key] as Map? ?? const {},
      ),
    );
  }

  static void _hydrateRadarr(Map<String, dynamic> prefs) {
    BackendPreferenceGroup.radarr.import({
      RadarrPreferences.NAVIGATION_INDEX.key: prefs['navigationIndex'],
      RadarrPreferences.NAVIGATION_INDEX_MOVIE_DETAILS.key:
          prefs['navigationIndexMovieDetails'],
      RadarrPreferences.NAVIGATION_INDEX_ADD_MOVIE.key:
          prefs['navigationIndexAddMovie'],
      RadarrPreferences.NAVIGATION_INDEX_SYSTEM_STATUS.key:
          prefs['navigationIndexSystemStatus'],
      RadarrPreferences.DEFAULT_VIEW_MOVIES.key: prefs['defaultViewMovies'],
      RadarrPreferences.DEFAULT_SORTING_MOVIES.key:
          prefs['defaultSortingMovies'],
      RadarrPreferences.DEFAULT_SORTING_MOVIES_ASCENDING.key:
          prefs['defaultSortingMoviesAscending'],
      RadarrPreferences.DEFAULT_FILTERING_MOVIES.key:
          prefs['defaultFilteringMovies'],
      RadarrPreferences.DEFAULT_SORTING_RELEASES.key:
          prefs['defaultSortingReleases'],
      RadarrPreferences.DEFAULT_SORTING_RELEASES_ASCENDING.key:
          prefs['defaultSortingReleasesAscending'],
      RadarrPreferences.DEFAULT_FILTERING_RELEASES.key:
          prefs['defaultFilteringReleases'],
      RadarrPreferences.ADD_MOVIE_DEFAULT_MONITORED_STATE.key:
          prefs['addMovieDefaultMonitoredState'],
      RadarrPreferences.ADD_MOVIE_DEFAULT_ROOT_FOLDER_ID.key:
          prefs['addMovieDefaultRootFolderId'],
      RadarrPreferences.ADD_MOVIE_DEFAULT_QUALITY_PROFILE_ID.key:
          prefs['addMovieDefaultQualityProfileId'],
      RadarrPreferences.ADD_MOVIE_DEFAULT_MINIMUM_AVAILABILITY_ID.key:
          prefs['addMovieDefaultMinimumAvailabilityId'],
      RadarrPreferences.ADD_MOVIE_DEFAULT_TAGS.key:
          prefs['addMovieDefaultTags'],
      RadarrPreferences.ADD_MOVIE_SEARCH_FOR_MISSING.key:
          prefs['addMovieSearchForMissing'],
      RadarrPreferences.ADD_DISCOVER_USE_SUGGESTIONS.key:
          prefs['addDiscoverUseSuggestions'],
      RadarrPreferences.MANUAL_IMPORT_DEFAULT_MODE.key:
          prefs['manualImportDefaultMode'],
      RadarrPreferences.QUEUE_PAGE_SIZE.key: prefs['queuePageSize'],
      RadarrPreferences.QUEUE_REFRESH_RATE.key: prefs['queueRefreshRate'],
      RadarrPreferences.QUEUE_BLACKLIST.key: prefs['queueBlacklist'],
      RadarrPreferences.QUEUE_REMOVE_FROM_CLIENT.key:
          prefs['queueRemoveFromClient'],
      RadarrPreferences.REMOVE_MOVIE_IMPORT_LIST.key:
          prefs['removeMovieImportList'],
      RadarrPreferences.REMOVE_MOVIE_DELETE_FILES.key:
          prefs['removeMovieDeleteFiles'],
      RadarrPreferences.CONTENT_PAGE_SIZE.key: prefs['contentPageSize'],
    });
  }

  static void _hydrateSonarr(Map<String, dynamic> prefs) {
    BackendPreferenceGroup.sonarr.import({
      SonarrPreferences.NAVIGATION_INDEX.key: prefs['navigationIndex'],
      SonarrPreferences.NAVIGATION_INDEX_SERIES_DETAILS.key:
          prefs['navigationIndexSeriesDetails'],
      SonarrPreferences.NAVIGATION_INDEX_SEASON_DETAILS.key:
          prefs['navigationIndexSeasonDetails'],
      SonarrPreferences.ADD_SERIES_SEARCH_FOR_MISSING.key:
          prefs['addSeriesSearchForMissing'],
      SonarrPreferences.ADD_SERIES_SEARCH_FOR_CUTOFF_UNMET.key:
          prefs['addSeriesSearchForCutoffUnmet'],
      SonarrPreferences.ADD_SERIES_DEFAULT_MONITORED.key:
          prefs['addSeriesDefaultMonitored'],
      SonarrPreferences.ADD_SERIES_DEFAULT_USE_SEASON_FOLDERS.key:
          prefs['addSeriesDefaultUseSeasonFolders'],
      SonarrPreferences.ADD_SERIES_DEFAULT_SERIES_TYPE.key:
          prefs['addSeriesDefaultSeriesType'],
      SonarrPreferences.ADD_SERIES_DEFAULT_MONITOR_TYPE.key:
          prefs['addSeriesDefaultMonitorType'],
      SonarrPreferences.ADD_SERIES_DEFAULT_LANGUAGE_PROFILE.key:
          prefs['addSeriesDefaultLanguageProfile'],
      SonarrPreferences.ADD_SERIES_DEFAULT_QUALITY_PROFILE.key:
          prefs['addSeriesDefaultQualityProfile'],
      SonarrPreferences.ADD_SERIES_DEFAULT_ROOT_FOLDER.key:
          prefs['addSeriesDefaultRootFolder'],
      SonarrPreferences.ADD_SERIES_DEFAULT_TAGS.key:
          prefs['addSeriesDefaultTags'],
      SonarrPreferences.DEFAULT_VIEW_SERIES.key: prefs['defaultViewSeries'],
      SonarrPreferences.DEFAULT_FILTERING_SERIES.key:
          prefs['defaultFilteringSeries'],
      SonarrPreferences.DEFAULT_FILTERING_RELEASES.key:
          prefs['defaultFilteringReleases'],
      SonarrPreferences.DEFAULT_SORTING_SERIES.key:
          prefs['defaultSortingSeries'],
      SonarrPreferences.DEFAULT_SORTING_RELEASES.key:
          prefs['defaultSortingReleases'],
      SonarrPreferences.DEFAULT_SORTING_SERIES_ASCENDING.key:
          prefs['defaultSortingSeriesAscending'],
      SonarrPreferences.DEFAULT_SORTING_RELEASES_ASCENDING.key:
          prefs['defaultSortingReleasesAscending'],
      SonarrPreferences.REMOVE_SERIES_DELETE_FILES.key:
          prefs['removeSeriesDeleteFiles'],
      SonarrPreferences.REMOVE_SERIES_EXCLUSION_LIST.key:
          prefs['removeSeriesExclusionList'],
      SonarrPreferences.UPCOMING_FUTURE_DAYS.key: prefs['upcomingFutureDays'],
      SonarrPreferences.QUEUE_PAGE_SIZE.key: prefs['queuePageSize'],
      SonarrPreferences.QUEUE_REFRESH_RATE.key: prefs['queueRefreshRate'],
      SonarrPreferences.QUEUE_REMOVE_DOWNLOAD_CLIENT.key:
          prefs['queueRemoveDownloadClient'],
      SonarrPreferences.QUEUE_ADD_BLOCKLIST.key: prefs['queueAddBlocklist'],
      SonarrPreferences.CONTENT_PAGE_SIZE.key: prefs['contentPageSize'],
    });
  }

  static void _hydrateLidarr(Map<String, dynamic> prefs) {
    BackendPreferenceGroup.lidarr.import({
      LidarrPreferences.NAVIGATION_INDEX.key: prefs['navigationIndex'],
      LidarrPreferences.ADD_MONITORED_STATUS.key: prefs['addMonitoredStatus'],
      LidarrPreferences.ADD_ARTIST_SEARCH_FOR_MISSING.key:
          prefs['addArtistSearchForMissing'],
      LidarrPreferences.ADD_ALBUM_FOLDERS.key: prefs['addAlbumFolders'],
      LidarrPreferences.ADD_QUALITY_PROFILE.key: prefs['addQualityProfile'],
      LidarrPreferences.ADD_METADATA_PROFILE.key: prefs['addMetadataProfile'],
      LidarrPreferences.ADD_ROOT_FOLDER.key: prefs['addRootFolder'],
    });
  }

  static void _hydrateTautulli(Map<String, dynamic> prefs) {
    BackendPreferenceGroup.tautulli.import({
      TautulliPreferences.NAVIGATION_INDEX.key: prefs['navigationIndex'],
      TautulliPreferences.NAVIGATION_INDEX_GRAPHS.key:
          prefs['navigationIndexGraphs'],
      TautulliPreferences.NAVIGATION_INDEX_LIBRARIES_DETAILS.key:
          prefs['navigationIndexLibrariesDetails'],
      TautulliPreferences.NAVIGATION_INDEX_MEDIA_DETAILS.key:
          prefs['navigationIndexMediaDetails'],
      TautulliPreferences.NAVIGATION_INDEX_USER_DETAILS.key:
          prefs['navigationIndexUserDetails'],
      TautulliPreferences.REFRESH_RATE.key: prefs['refreshRate'],
      TautulliPreferences.CONTENT_LOAD_LENGTH.key: prefs['contentLoadLength'],
      TautulliPreferences.STATISTICS_STATS_COUNT.key:
          prefs['statisticsStatsCount'],
      TautulliPreferences.TERMINATION_MESSAGE.key: prefs['terminationMessage'],
      TautulliPreferences.GRAPHS_DAYS.key: prefs['graphsDays'],
      TautulliPreferences.GRAPHS_LINECHART_DAYS.key:
          prefs['graphsLinechartDays'],
      TautulliPreferences.GRAPHS_MONTHS.key: prefs['graphsMonths'],
    });
  }
}
