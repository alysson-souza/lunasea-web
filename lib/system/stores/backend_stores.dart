import 'package:flutter/foundation.dart';

import 'package:lunasea/database/models/external_module.dart';
import 'package:lunasea/database/models/indexer.dart';
import 'package:lunasea/database/models/log.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/system/preferences/bios.dart';
import 'package:lunasea/system/preferences/dashboard.dart';
import 'package:lunasea/system/preferences/lunasea.dart';
import 'package:lunasea/system/preferences/nzbget.dart';
import 'package:lunasea/system/preferences/sabnzbd.dart';
import 'package:lunasea/system/preferences/search.dart';
import 'package:lunasea/system/preferences/tautulli.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/dashboard/core/adapters/calendar_starting_day.dart';
import 'package:lunasea/modules/dashboard/core/adapters/calendar_starting_size.dart';
import 'package:lunasea/modules/dashboard/core/adapters/calendar_starting_type.dart';
import 'package:lunasea/modules/lidarr.dart';
import 'package:lunasea/modules/radarr.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/system/backend_state.dart';
import 'package:lunasea/system/gateway/gateway.dart';
import 'package:lunasea/types/list_view_option.dart';

abstract class BackendStore extends ChangeNotifier {
  void refresh() => notifyListeners();
}

class ProfilesStore extends BackendStore {
  List<String> get profiles {
    final profiles = LunaBackendState.profiles.keys.toList();
    profiles.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return profiles;
  }

  String get activeProfile => LunaSeaPreferences.ENABLED_PROFILE.read();
  LunaProfile get active =>
      read(activeProfile) ?? LunaProfile(key: activeProfile);
  bool get isEmpty => LunaBackendState.profiles.isEmpty;
  int get size => LunaBackendState.profiles.length;

  LunaProfile? read(String profile) => LunaBackendState.profiles[profile];
  bool contains(String profile) =>
      LunaBackendState.profiles.containsKey(profile);

  List<LunaServiceInstance> instancesFor(String profile, LunaModule module) {
    return read(profile)?.instancesFor(module) ?? const [];
  }

  List<LunaServiceInstance> enabledInstances(
    String profile,
    LunaModule module,
  ) {
    return read(profile)?.enabledInstances(module) ?? const [];
  }

  List<LunaServiceInstanceRef> enabledInstanceRefs(
    String profile,
    LunaModule module,
  ) {
    return enabledInstances(
      profile,
      module,
    ).map((instance) => instance.ref).toList();
  }

  List<String> enabledFor(LunaModule module) {
    return profiles.where((profile) {
      final value = read(profile);
      if (value == null) return false;
      return _isModuleEnabled(value, module);
    }).toList();
  }

  bool isEnabled(LunaModule module) {
    final profile = active;
    switch (module) {
      case LunaModule.DASHBOARD:
      case LunaModule.SETTINGS:
        return true;
      case LunaModule.LIDARR:
      case LunaModule.NZBGET:
      case LunaModule.RADARR:
      case LunaModule.SABNZBD:
      case LunaModule.SONARR:
      case LunaModule.TAUTULLI:
        return _isModuleEnabled(profile, module);
      case LunaModule.OVERSEERR:
        return profile.overseerrEnabled;
      case LunaModule.SEARCH:
        return LunaBackendState.indexers.isNotEmpty;
      case LunaModule.WAKE_ON_LAN:
        return false;
      case LunaModule.EXTERNAL_MODULES:
        return LunaBackendState.externalModules.isNotEmpty;
    }
  }

  bool _isModuleEnabled(LunaProfile profile, LunaModule module) {
    switch (module) {
      case LunaModule.LIDARR:
      case LunaModule.RADARR:
      case LunaModule.SONARR:
      case LunaModule.SABNZBD:
      case LunaModule.NZBGET:
      case LunaModule.TAUTULLI:
        return profile.isModuleAvailable(module);
      case LunaModule.DASHBOARD:
      case LunaModule.EXTERNAL_MODULES:
      case LunaModule.OVERSEERR:
      case LunaModule.SEARCH:
      case LunaModule.SETTINGS:
      case LunaModule.WAKE_ON_LAN:
        return false;
    }
  }

  Future<void> changeTo(String profile) async {
    LunaSeaPreferences.ENABLED_PROFILE.update(profile);
    notifyListeners();
  }

  Future<void> updateActive(void Function(LunaProfile profile) change) async {
    final profile = LunaProfile.clone(active);
    change(profile);
    await update(activeProfile, profile);
  }

  Future<void> persistActive() async {
    await update(activeProfile, active);
  }

  Future<void> create(String profile) async {
    final value = LunaProfile(key: profile);
    await LunaGateway.createProfile(profile);
    await LunaGateway.updateProfile(profile, value);
    LunaBackendState.profiles[profile] = value;
    notifyListeners();
  }

  Future<void> rename(String oldProfile, String newProfile) async {
    final newDb = LunaProfile.clone(LunaBackendState.profiles[oldProfile]!);
    newDb.key = newProfile;

    await LunaGateway.createProfile(newProfile);
    await LunaGateway.updateProfile(newProfile, newDb);
    if (activeProfile == oldProfile)
      LunaSeaPreferences.ENABLED_PROFILE.update(newProfile);
    await LunaGateway.deleteProfile(oldProfile);
    LunaBackendState.profiles.remove(oldProfile);
    LunaBackendState.profiles[newProfile] = newDb;
    notifyListeners();
  }

  Future<void> update(String profile, LunaProfile value) async {
    await LunaGateway.updateProfile(profile, value);
    LunaBackendState.profiles[profile] = value;
    notifyListeners();
  }

  Future<void> delete(String profile) async {
    await LunaGateway.deleteProfile(profile);
    LunaBackendState.profiles.remove(profile);
    notifyListeners();
  }
}

class SettingsStore extends BackendStore {
  bool get androidBackOpensDrawer =>
      LunaSeaPreferences.ANDROID_BACK_OPENS_DRAWER.read();
  bool get amoledTheme => LunaSeaPreferences.THEME_AMOLED.read();
  bool get amoledThemeBorder => LunaSeaPreferences.THEME_AMOLED_BORDER.read();
  int get imageBackgroundOpacity =>
      LunaSeaPreferences.THEME_IMAGE_BACKGROUND_OPACITY.read();
  bool get tlsValidation => LunaSeaPreferences.NETWORKING_TLS_VALIDATION.read();
  bool get use24HourTime => LunaSeaPreferences.USE_24_HOUR_TIME.read();
  LunaModule get bootModule => BIOSPreferences.BOOT_MODULE.read();
  bool get drawerAutomaticManage =>
      LunaSeaPreferences.DRAWER_AUTOMATIC_MANAGE.read();
  List<LunaModule> get drawerManualOrder =>
      LunaSeaPreferences.DRAWER_MANUAL_ORDER.read().cast<LunaModule>();
  int get dashboardCalendarLayoutVersion => Object.hash(
    DashboardPreferences.CALENDAR_STARTING_DAY.read(),
    DashboardPreferences.CALENDAR_STARTING_SIZE.read(),
  );
  int get dashboardDefaultPage => DashboardPreferences.NAVIGATION_INDEX.read();
  int get dashboardCalendarPastDays =>
      DashboardPreferences.CALENDAR_DAYS_PAST.read();
  int get dashboardCalendarFutureDays =>
      DashboardPreferences.CALENDAR_DAYS_FUTURE.read();
  bool get dashboardCalendarLidarrEnabled =>
      DashboardPreferences.CALENDAR_ENABLE_LIDARR.read();
  bool get dashboardCalendarRadarrEnabled =>
      DashboardPreferences.CALENDAR_ENABLE_RADARR.read();
  bool get dashboardCalendarSonarrEnabled =>
      DashboardPreferences.CALENDAR_ENABLE_SONARR.read();
  CalendarStartingType get dashboardCalendarStartingType =>
      DashboardPreferences.CALENDAR_STARTING_TYPE.read();
  CalendarStartingDay get dashboardCalendarStartingDay =>
      DashboardPreferences.CALENDAR_STARTING_DAY.read();
  CalendarStartingSize get dashboardCalendarStartingSize =>
      DashboardPreferences.CALENDAR_STARTING_SIZE.read();
  bool get searchHideAdultCategories => SearchPreferences.HIDE_XXX.read();
  bool get searchShowLinks => SearchPreferences.SHOW_LINKS.read();
  int get lidarrDefaultPage => LidarrPreferences.NAVIGATION_INDEX.read();
  LidarrRootFolder? get lidarrAddRootFolder =>
      LidarrPreferences.ADD_ROOT_FOLDER.read();
  String get lidarrAddMonitoredStatus =>
      LidarrPreferences.ADD_MONITORED_STATUS.read();
  LidarrQualityProfile? get lidarrAddQualityProfile =>
      LidarrPreferences.ADD_QUALITY_PROFILE.read();
  LidarrMetadataProfile? get lidarrAddMetadataProfile =>
      LidarrPreferences.ADD_METADATA_PROFILE.read();
  bool get lidarrAddArtistSearchForMissing =>
      LidarrPreferences.ADD_ARTIST_SEARCH_FOR_MISSING.read();
  int get nzbgetDefaultPage => NZBGetPreferences.NAVIGATION_INDEX.read();
  int get sabnzbdDefaultPage => SABnzbdPreferences.NAVIGATION_INDEX.read();
  int get radarrDefaultPage => RadarrPreferences.NAVIGATION_INDEX.read();
  int get radarrMovieDetailsDefaultPage =>
      RadarrPreferences.NAVIGATION_INDEX_MOVIE_DETAILS.read();
  int get radarrAddMovieDefaultPage =>
      RadarrPreferences.NAVIGATION_INDEX_ADD_MOVIE.read();
  int get radarrSystemStatusDefaultPage =>
      RadarrPreferences.NAVIGATION_INDEX_SYSTEM_STATUS.read();
  int get sonarrDefaultPage => SonarrPreferences.NAVIGATION_INDEX.read();
  int get sonarrSeriesDetailsDefaultPage =>
      SonarrPreferences.NAVIGATION_INDEX_SERIES_DETAILS.read();
  int get sonarrSeasonDetailsDefaultPage =>
      SonarrPreferences.NAVIGATION_INDEX_SEASON_DETAILS.read();
  int get tautulliDefaultPage => TautulliPreferences.NAVIGATION_INDEX.read();
  int get tautulliGraphsDefaultPage =>
      TautulliPreferences.NAVIGATION_INDEX_GRAPHS.read();
  int get tautulliLibraryDetailsDefaultPage =>
      TautulliPreferences.NAVIGATION_INDEX_LIBRARIES_DETAILS.read();
  int get tautulliMediaDetailsDefaultPage =>
      TautulliPreferences.NAVIGATION_INDEX_MEDIA_DETAILS.read();
  int get tautulliUserDetailsDefaultPage =>
      TautulliPreferences.NAVIGATION_INDEX_USER_DETAILS.read();
  LunaListViewOption get radarrMoviesDefaultView =>
      RadarrPreferences.DEFAULT_VIEW_MOVIES.read();
  RadarrMoviesSorting get radarrMoviesDefaultSorting =>
      RadarrPreferences.DEFAULT_SORTING_MOVIES.read();
  bool get radarrMoviesDefaultSortingAscending =>
      RadarrPreferences.DEFAULT_SORTING_MOVIES_ASCENDING.read();
  RadarrMoviesFilter get radarrMoviesDefaultFilter =>
      RadarrPreferences.DEFAULT_FILTERING_MOVIES.read();
  RadarrReleasesSorting get radarrReleasesDefaultSorting =>
      RadarrPreferences.DEFAULT_SORTING_RELEASES.read();
  bool get radarrReleasesDefaultSortingAscending =>
      RadarrPreferences.DEFAULT_SORTING_RELEASES_ASCENDING.read();
  RadarrReleasesFilter get radarrReleasesDefaultFilter =>
      RadarrPreferences.DEFAULT_FILTERING_RELEASES.read();
  bool get radarrDiscoverUseSuggestions =>
      RadarrPreferences.ADD_DISCOVER_USE_SUGGESTIONS.read();
  int get radarrQueuePageSize => RadarrPreferences.QUEUE_PAGE_SIZE.read();
  bool get radarrQueueRemoveFromClient =>
      RadarrPreferences.QUEUE_REMOVE_FROM_CLIENT.read();
  bool get radarrQueueBlacklist => RadarrPreferences.QUEUE_BLACKLIST.read();
  bool get radarrRemoveMovieImportList =>
      RadarrPreferences.REMOVE_MOVIE_IMPORT_LIST.read();
  bool get radarrRemoveMovieDeleteFiles =>
      RadarrPreferences.REMOVE_MOVIE_DELETE_FILES.read();
  bool get radarrAddMovieSearchForMissing =>
      RadarrPreferences.ADD_MOVIE_SEARCH_FOR_MISSING.read();
  String get radarrManualImportDefaultMode =>
      RadarrPreferences.MANUAL_IMPORT_DEFAULT_MODE.read();
  LunaListViewOption get sonarrSeriesDefaultView =>
      SonarrPreferences.DEFAULT_VIEW_SERIES.read();
  SonarrSeriesSorting get sonarrSeriesDefaultSorting =>
      SonarrPreferences.DEFAULT_SORTING_SERIES.read();
  bool get sonarrSeriesDefaultSortingAscending =>
      SonarrPreferences.DEFAULT_SORTING_SERIES_ASCENDING.read();
  SonarrSeriesFilter get sonarrSeriesDefaultFilter =>
      SonarrPreferences.DEFAULT_FILTERING_SERIES.read();
  SonarrReleasesSorting get sonarrReleasesDefaultSorting =>
      SonarrPreferences.DEFAULT_SORTING_RELEASES.read();
  bool get sonarrReleasesDefaultSortingAscending =>
      SonarrPreferences.DEFAULT_SORTING_RELEASES_ASCENDING.read();
  SonarrReleasesFilter get sonarrReleasesDefaultFilter =>
      SonarrPreferences.DEFAULT_FILTERING_RELEASES.read();
  int get sonarrQueuePageSize => SonarrPreferences.QUEUE_PAGE_SIZE.read();
  bool get sonarrRemoveSeriesExclusionList =>
      SonarrPreferences.REMOVE_SERIES_EXCLUSION_LIST.read();
  bool get sonarrRemoveSeriesDeleteFiles =>
      SonarrPreferences.REMOVE_SERIES_DELETE_FILES.read();
  bool get sonarrAddSeriesSearchForMissing =>
      SonarrPreferences.ADD_SERIES_SEARCH_FOR_MISSING.read();
  bool get sonarrAddSeriesSearchForCutoffUnmet =>
      SonarrPreferences.ADD_SERIES_SEARCH_FOR_CUTOFF_UNMET.read();
  bool get sonarrQueueRemoveDownloadClient =>
      SonarrPreferences.QUEUE_REMOVE_DOWNLOAD_CLIENT.read();
  bool get sonarrQueueAddBlocklist =>
      SonarrPreferences.QUEUE_ADD_BLOCKLIST.read();
  String get tautulliTerminationMessage =>
      TautulliPreferences.TERMINATION_MESSAGE.read();
  int get tautulliRefreshRate => TautulliPreferences.REFRESH_RATE.read();
  int get tautulliStatisticsItemCount =>
      TautulliPreferences.STATISTICS_STATS_COUNT.read();

  bool quickActionEnabled(LunaModule module) => _quickActionFor(module).read();

  Future<void> setAndroidBackOpensDrawer(bool value) async {
    LunaSeaPreferences.ANDROID_BACK_OPENS_DRAWER.update(value);
    notifyListeners();
  }

  Future<void> setAmoledTheme(bool value) async {
    LunaSeaPreferences.THEME_AMOLED.update(value);
    notifyListeners();
  }

  Future<void> setAmoledThemeBorder(bool value) async {
    LunaSeaPreferences.THEME_AMOLED_BORDER.update(value);
    notifyListeners();
  }

  Future<void> setImageBackgroundOpacity(int value) async {
    LunaSeaPreferences.THEME_IMAGE_BACKGROUND_OPACITY.update(value);
    notifyListeners();
  }

  Future<void> setTlsValidation(bool value) async {
    LunaSeaPreferences.NETWORKING_TLS_VALIDATION.update(value);
    notifyListeners();
  }

  Future<void> setUse24HourTime(bool value) async {
    LunaSeaPreferences.USE_24_HOUR_TIME.update(value);
    notifyListeners();
  }

  Future<void> setBootModule(LunaModule value) async {
    BIOSPreferences.BOOT_MODULE.update(value);
    notifyListeners();
  }

  Future<void> setDashboardDefaultPage(int value) async {
    DashboardPreferences.NAVIGATION_INDEX.update(value);
    notifyListeners();
  }

  Future<void> setDashboardCalendarPastDays(int value) async {
    DashboardPreferences.CALENDAR_DAYS_PAST.update(value);
    notifyListeners();
  }

  Future<void> setDashboardCalendarFutureDays(int value) async {
    DashboardPreferences.CALENDAR_DAYS_FUTURE.update(value);
    notifyListeners();
  }

  Future<void> setDashboardCalendarLidarrEnabled(bool value) async {
    DashboardPreferences.CALENDAR_ENABLE_LIDARR.update(value);
    notifyListeners();
  }

  Future<void> setDashboardCalendarRadarrEnabled(bool value) async {
    DashboardPreferences.CALENDAR_ENABLE_RADARR.update(value);
    notifyListeners();
  }

  Future<void> setDashboardCalendarSonarrEnabled(bool value) async {
    DashboardPreferences.CALENDAR_ENABLE_SONARR.update(value);
    notifyListeners();
  }

  Future<void> setDashboardCalendarStartingType(
    CalendarStartingType value,
  ) async {
    DashboardPreferences.CALENDAR_STARTING_TYPE.update(value);
    notifyListeners();
  }

  Future<void> setDashboardCalendarStartingDay(
    CalendarStartingDay value,
  ) async {
    DashboardPreferences.CALENDAR_STARTING_DAY.update(value);
    notifyListeners();
  }

  Future<void> setDashboardCalendarStartingSize(
    CalendarStartingSize value,
  ) async {
    DashboardPreferences.CALENDAR_STARTING_SIZE.update(value);
    notifyListeners();
  }

  Future<void> setSearchHideAdultCategories(bool value) async {
    SearchPreferences.HIDE_XXX.update(value);
    notifyListeners();
  }

  Future<void> setSearchShowLinks(bool value) async {
    SearchPreferences.SHOW_LINKS.update(value);
    notifyListeners();
  }

  Future<void> setLidarrDefaultPage(int value) async {
    LidarrPreferences.NAVIGATION_INDEX.update(value);
    notifyListeners();
  }

  Future<void> setLidarrAddRootFolder(LidarrRootFolder value) async {
    LidarrPreferences.ADD_ROOT_FOLDER.update(value);
    notifyListeners();
  }

  Future<void> setLidarrAddMonitoredStatus(String value) async {
    LidarrPreferences.ADD_MONITORED_STATUS.update(value);
    notifyListeners();
  }

  Future<void> setLidarrAddQualityProfile(LidarrQualityProfile value) async {
    LidarrPreferences.ADD_QUALITY_PROFILE.update(value);
    notifyListeners();
  }

  Future<void> setLidarrAddMetadataProfile(LidarrMetadataProfile value) async {
    LidarrPreferences.ADD_METADATA_PROFILE.update(value);
    notifyListeners();
  }

  Future<void> setLidarrAddArtistSearchForMissing(bool value) async {
    LidarrPreferences.ADD_ARTIST_SEARCH_FOR_MISSING.update(value);
    notifyListeners();
  }

  Future<void> setNzbgetDefaultPage(int value) async {
    NZBGetPreferences.NAVIGATION_INDEX.update(value);
    notifyListeners();
  }

  Future<void> setSabnzbdDefaultPage(int value) async {
    SABnzbdPreferences.NAVIGATION_INDEX.update(value);
    notifyListeners();
  }

  Future<void> setRadarrDefaultPage(int value) async {
    RadarrPreferences.NAVIGATION_INDEX.update(value);
    notifyListeners();
  }

  Future<void> setRadarrMovieDetailsDefaultPage(int value) async {
    RadarrPreferences.NAVIGATION_INDEX_MOVIE_DETAILS.update(value);
    notifyListeners();
  }

  Future<void> setRadarrAddMovieDefaultPage(int value) async {
    RadarrPreferences.NAVIGATION_INDEX_ADD_MOVIE.update(value);
    notifyListeners();
  }

  Future<void> setRadarrSystemStatusDefaultPage(int value) async {
    RadarrPreferences.NAVIGATION_INDEX_SYSTEM_STATUS.update(value);
    notifyListeners();
  }

  Future<void> setSonarrDefaultPage(int value) async {
    SonarrPreferences.NAVIGATION_INDEX.update(value);
    notifyListeners();
  }

  Future<void> setSonarrSeriesDetailsDefaultPage(int value) async {
    SonarrPreferences.NAVIGATION_INDEX_SERIES_DETAILS.update(value);
    notifyListeners();
  }

  Future<void> setSonarrSeasonDetailsDefaultPage(int value) async {
    SonarrPreferences.NAVIGATION_INDEX_SEASON_DETAILS.update(value);
    notifyListeners();
  }

  Future<void> setTautulliDefaultPage(int value) async {
    TautulliPreferences.NAVIGATION_INDEX.update(value);
    notifyListeners();
  }

  Future<void> setTautulliGraphsDefaultPage(int value) async {
    TautulliPreferences.NAVIGATION_INDEX_GRAPHS.update(value);
    notifyListeners();
  }

  Future<void> setTautulliLibraryDetailsDefaultPage(int value) async {
    TautulliPreferences.NAVIGATION_INDEX_LIBRARIES_DETAILS.update(value);
    notifyListeners();
  }

  Future<void> setTautulliMediaDetailsDefaultPage(int value) async {
    TautulliPreferences.NAVIGATION_INDEX_MEDIA_DETAILS.update(value);
    notifyListeners();
  }

  Future<void> setTautulliUserDetailsDefaultPage(int value) async {
    TautulliPreferences.NAVIGATION_INDEX_USER_DETAILS.update(value);
    notifyListeners();
  }

  Future<void> setRadarrMoviesDefaultView(LunaListViewOption value) async {
    RadarrPreferences.DEFAULT_VIEW_MOVIES.update(value);
    notifyListeners();
  }

  Future<void> setRadarrMoviesDefaultSorting(RadarrMoviesSorting value) async {
    RadarrPreferences.DEFAULT_SORTING_MOVIES.update(value);
    notifyListeners();
  }

  Future<void> setRadarrMoviesDefaultSortingAscending(bool value) async {
    RadarrPreferences.DEFAULT_SORTING_MOVIES_ASCENDING.update(value);
    notifyListeners();
  }

  Future<void> setRadarrMoviesDefaultFilter(RadarrMoviesFilter value) async {
    RadarrPreferences.DEFAULT_FILTERING_MOVIES.update(value);
    notifyListeners();
  }

  Future<void> setRadarrReleasesDefaultSorting(
    RadarrReleasesSorting value,
  ) async {
    RadarrPreferences.DEFAULT_SORTING_RELEASES.update(value);
    notifyListeners();
  }

  Future<void> setRadarrReleasesDefaultSortingAscending(bool value) async {
    RadarrPreferences.DEFAULT_SORTING_RELEASES_ASCENDING.update(value);
    notifyListeners();
  }

  Future<void> setRadarrReleasesDefaultFilter(
    RadarrReleasesFilter value,
  ) async {
    RadarrPreferences.DEFAULT_FILTERING_RELEASES.update(value);
    notifyListeners();
  }

  Future<void> setRadarrDiscoverUseSuggestions(bool value) async {
    RadarrPreferences.ADD_DISCOVER_USE_SUGGESTIONS.update(value);
    notifyListeners();
  }

  Future<void> setRadarrQueuePageSize(int value) async {
    RadarrPreferences.QUEUE_PAGE_SIZE.update(value);
    notifyListeners();
  }

  Future<void> setRadarrQueueRemoveFromClient(bool value) async {
    RadarrPreferences.QUEUE_REMOVE_FROM_CLIENT.update(value);
    notifyListeners();
  }

  Future<void> setRadarrQueueBlacklist(bool value) async {
    RadarrPreferences.QUEUE_BLACKLIST.update(value);
    notifyListeners();
  }

  Future<void> setRadarrRemoveMovieImportList(bool value) async {
    RadarrPreferences.REMOVE_MOVIE_IMPORT_LIST.update(value);
    notifyListeners();
  }

  Future<void> setRadarrRemoveMovieDeleteFiles(bool value) async {
    RadarrPreferences.REMOVE_MOVIE_DELETE_FILES.update(value);
    notifyListeners();
  }

  Future<void> setRadarrAddMovieSearchForMissing(bool value) async {
    RadarrPreferences.ADD_MOVIE_SEARCH_FOR_MISSING.update(value);
    notifyListeners();
  }

  Future<void> setRadarrManualImportDefaultMode(String value) async {
    RadarrPreferences.MANUAL_IMPORT_DEFAULT_MODE.update(value);
    notifyListeners();
  }

  Future<void> setSonarrSeriesDefaultView(LunaListViewOption value) async {
    SonarrPreferences.DEFAULT_VIEW_SERIES.update(value);
    notifyListeners();
  }

  Future<void> setSonarrSeriesDefaultSorting(SonarrSeriesSorting value) async {
    SonarrPreferences.DEFAULT_SORTING_SERIES.update(value);
    notifyListeners();
  }

  Future<void> setSonarrSeriesDefaultSortingAscending(bool value) async {
    SonarrPreferences.DEFAULT_SORTING_SERIES_ASCENDING.update(value);
    notifyListeners();
  }

  Future<void> setSonarrSeriesDefaultFilter(SonarrSeriesFilter value) async {
    SonarrPreferences.DEFAULT_FILTERING_SERIES.update(value);
    notifyListeners();
  }

  Future<void> setSonarrReleasesDefaultSorting(
    SonarrReleasesSorting value,
  ) async {
    SonarrPreferences.DEFAULT_SORTING_RELEASES.update(value);
    notifyListeners();
  }

  Future<void> setSonarrReleasesDefaultSortingAscending(bool value) async {
    SonarrPreferences.DEFAULT_SORTING_RELEASES_ASCENDING.update(value);
    notifyListeners();
  }

  Future<void> setSonarrReleasesDefaultFilter(
    SonarrReleasesFilter value,
  ) async {
    SonarrPreferences.DEFAULT_FILTERING_RELEASES.update(value);
    notifyListeners();
  }

  Future<void> setSonarrQueuePageSize(int value) async {
    SonarrPreferences.QUEUE_PAGE_SIZE.update(value);
    notifyListeners();
  }

  Future<void> setSonarrRemoveSeriesExclusionList(bool value) async {
    SonarrPreferences.REMOVE_SERIES_EXCLUSION_LIST.update(value);
    notifyListeners();
  }

  Future<void> setSonarrRemoveSeriesDeleteFiles(bool value) async {
    SonarrPreferences.REMOVE_SERIES_DELETE_FILES.update(value);
    notifyListeners();
  }

  Future<void> setSonarrAddSeriesSearchForMissing(bool value) async {
    SonarrPreferences.ADD_SERIES_SEARCH_FOR_MISSING.update(value);
    notifyListeners();
  }

  Future<void> setSonarrAddSeriesSearchForCutoffUnmet(bool value) async {
    SonarrPreferences.ADD_SERIES_SEARCH_FOR_CUTOFF_UNMET.update(value);
    notifyListeners();
  }

  Future<void> setSonarrQueueRemoveDownloadClient(bool value) async {
    SonarrPreferences.QUEUE_REMOVE_DOWNLOAD_CLIENT.update(value);
    notifyListeners();
  }

  Future<void> setSonarrQueueAddBlocklist(bool value) async {
    SonarrPreferences.QUEUE_ADD_BLOCKLIST.update(value);
    notifyListeners();
  }

  Future<void> setTautulliTerminationMessage(String value) async {
    TautulliPreferences.TERMINATION_MESSAGE.update(value);
    notifyListeners();
  }

  Future<void> setTautulliRefreshRate(int value) async {
    TautulliPreferences.REFRESH_RATE.update(value);
    notifyListeners();
  }

  Future<void> setTautulliStatisticsItemCount(int value) async {
    TautulliPreferences.STATISTICS_STATS_COUNT.update(value);
    notifyListeners();
  }

  Future<void> setDrawerAutomaticManage(bool value) async {
    LunaSeaPreferences.DRAWER_AUTOMATIC_MANAGE.update(value);
    notifyListeners();
  }

  Future<void> setDrawerManualOrder(List<LunaModule> value) async {
    LunaSeaPreferences.DRAWER_MANUAL_ORDER.update(value);
    notifyListeners();
  }

  Future<void> setQuickActionEnabled(LunaModule module, bool value) async {
    _quickActionFor(module).update(value);
    notifyListeners();
  }

  LunaSeaPreferences<bool> _quickActionFor(LunaModule module) {
    switch (module) {
      case LunaModule.LIDARR:
        return LunaSeaPreferences.QUICK_ACTIONS_LIDARR;
      case LunaModule.NZBGET:
        return LunaSeaPreferences.QUICK_ACTIONS_NZBGET;
      case LunaModule.OVERSEERR:
        return LunaSeaPreferences.QUICK_ACTIONS_OVERSEERR;
      case LunaModule.RADARR:
        return LunaSeaPreferences.QUICK_ACTIONS_RADARR;
      case LunaModule.SABNZBD:
        return LunaSeaPreferences.QUICK_ACTIONS_SABNZBD;
      case LunaModule.SEARCH:
        return LunaSeaPreferences.QUICK_ACTIONS_SEARCH;
      case LunaModule.SONARR:
        return LunaSeaPreferences.QUICK_ACTIONS_SONARR;
      case LunaModule.TAUTULLI:
        return LunaSeaPreferences.QUICK_ACTIONS_TAUTULLI;
      case LunaModule.DASHBOARD:
      case LunaModule.EXTERNAL_MODULES:
      case LunaModule.SETTINGS:
      case LunaModule.WAKE_ON_LAN:
        throw ArgumentError('Module does not have a quick action: $module');
    }
  }
}

class IndexersStore extends BackendStore {
  List<LunaIndexer> get indexers => LunaBackendState.indexers.values.toList();
  bool get isEmpty => LunaBackendState.indexers.isEmpty;

  LunaIndexer? read(int id) => LunaBackendState.indexers[id];

  Future<int> create(LunaIndexer indexer) async {
    final created = await LunaGateway.createIndexer(indexer);
    final id = created.item1;
    LunaBackendState.indexers[id] = created.item2;
    notifyListeners();
    return id;
  }

  Future<void> update(int id, LunaIndexer indexer) async {
    await LunaGateway.updateIndexer(id, indexer);
    LunaBackendState.indexers[id] = indexer;
    notifyListeners();
  }

  Future<void> delete(int id) async {
    await LunaGateway.deleteIndexer(id);
    LunaBackendState.indexers.remove(id);
    notifyListeners();
  }
}

class ExternalModulesStore extends BackendStore {
  List<LunaExternalModule> get modules =>
      LunaBackendState.externalModules.values.toList();
  bool get isEmpty => LunaBackendState.externalModules.isEmpty;

  LunaExternalModule? read(int id) => LunaBackendState.externalModules[id];

  Future<int> create(LunaExternalModule module) async {
    final created = await LunaGateway.createExternalModule(module);
    final id = created.item1;
    LunaBackendState.externalModules[id] = created.item2;
    notifyListeners();
    return id;
  }

  Future<void> update(int id, LunaExternalModule module) async {
    await LunaGateway.updateExternalModule(id, module);
    LunaBackendState.externalModules[id] = module;
    notifyListeners();
  }

  Future<void> delete(int id) async {
    await LunaGateway.deleteExternalModule(id);
    LunaBackendState.externalModules.remove(id);
    notifyListeners();
  }
}

class DismissedBannersStore extends BackendStore {
  bool shouldShow(String key) =>
      !LunaBackendState.dismissedBanners.contains(key);

  Future<void> dismiss(String key) async {
    await LunaGateway.dismissBanner(key);
    LunaBackendState.dismissedBanners.add(key);
    notifyListeners();
  }

  Future<void> restore(String key) async {
    await LunaGateway.undismissBanner(key);
    LunaBackendState.dismissedBanners.remove(key);
    notifyListeners();
  }
}

class LogsStore extends BackendStore {
  static List<LunaLog> get currentLogs => LunaBackendState.logs.values.toList();
  static Iterable<dynamic> get currentKeys => LunaBackendState.logs.keys;

  static LunaLog? readLog(dynamic key) => LunaBackendState.logs[key];

  static Future<void> createLog(LunaLog log) async {
    final created = await LunaGateway.createLog(log);
    LunaBackendState.logs[created.item1] = created.item2;
  }

  static Future<void> deleteLog(dynamic key) async {
    LunaBackendState.logs.remove(key);
  }

  static Future<void> clearLogEntries() async {
    await LunaGateway.clearLogs();
    LunaBackendState.logs.clear();
  }

  List<LunaLog> get logs => LunaBackendState.logs.values.toList();

  Future<void> create(LunaLog log) async {
    final created = await LunaGateway.createLog(log);
    LunaBackendState.logs[created.item1] = created.item2;
    notifyListeners();
  }

  Future<void> delete(int id) async {
    LunaBackendState.logs.remove(id);
    notifyListeners();
  }

  Future<void> clear() async {
    await LunaGateway.clearLogs();
    LunaBackendState.logs.clear();
    notifyListeners();
  }
}
