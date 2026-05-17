import 'package:flutter/material.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/settings.dart';
import 'package:lunasea/modules/sonarr.dart';

class SonarrSeriesAddDetailsState extends ChangeNotifier {
  static const _monitoredKey = 'addSeriesDefaultMonitored';
  static const _useSeasonFoldersKey = 'addSeriesDefaultUseSeasonFolders';
  static const _seriesTypeKey = 'addSeriesDefaultSeriesType';
  static const _monitorTypeKey = 'addSeriesDefaultMonitorType';
  static const _rootFolderKey = 'addSeriesDefaultRootFolder';
  static const _qualityProfileKey = 'addSeriesDefaultQualityProfile';
  static const _languageProfileKey = 'addSeriesDefaultLanguageProfile';
  static const _tagsKey = 'addSeriesDefaultTags';
  static const _searchForMissingKey = 'addSeriesSearchForMissing';
  static const _searchForCutoffUnmetKey = 'addSeriesSearchForCutoffUnmet';

  final LunaServiceInstance? instance;
  final SonarrSeries series;
  bool canExecuteAction = false;

  SonarrSeriesAddDetailsState({required this.series, this.instance});

  T preference<T>(String key, T fallback) {
    return instance?.preference<T>(key, fallback) ?? fallback;
  }

  void setPreference(String key, dynamic value) {
    final instance = this.instance;
    if (instance == null) return;
    instance.setPreference(key, value);
    unawaited(
      SettingsServiceInstanceSettings.save(instance).catchError((_) {
        return instance;
      }),
    );
  }

  bool get searchForMissingEpisodes => preference(
    _searchForMissingKey,
    SonarrPreferences.ADD_SERIES_SEARCH_FOR_MISSING.read(),
  );

  set searchForMissingEpisodes(bool searchForMissingEpisodes) {
    if (instance != null) {
      setPreference(_searchForMissingKey, searchForMissingEpisodes);
    } else {
      SonarrPreferences.ADD_SERIES_SEARCH_FOR_MISSING.update(
        searchForMissingEpisodes,
      );
    }
    notifyListeners();
  }

  bool get searchForCutoffUnmetEpisodes => preference(
    _searchForCutoffUnmetKey,
    SonarrPreferences.ADD_SERIES_SEARCH_FOR_CUTOFF_UNMET.read(),
  );

  set searchForCutoffUnmetEpisodes(bool searchForCutoffUnmetEpisodes) {
    if (instance != null) {
      setPreference(_searchForCutoffUnmetKey, searchForCutoffUnmetEpisodes);
    } else {
      SonarrPreferences.ADD_SERIES_SEARCH_FOR_CUTOFF_UNMET.update(
        searchForCutoffUnmetEpisodes,
      );
    }
    notifyListeners();
  }

  bool _monitored = true;
  bool get monitored => _monitored;
  set monitored(bool monitored) {
    _monitored = monitored;
    if (instance != null) {
      setPreference(_monitoredKey, _monitored);
    } else {
      SonarrPreferences.ADD_SERIES_DEFAULT_MONITORED.update(_monitored);
    }
    notifyListeners();
  }

  void initializeMonitored() {
    _monitored = preference(
      _monitoredKey,
      SonarrPreferences.ADD_SERIES_DEFAULT_MONITORED.read(),
    );
  }

  bool _useSeasonFolders = true;
  bool get useSeasonFolders => _useSeasonFolders;
  set useSeasonFolders(bool useSeasonFolders) {
    _useSeasonFolders = useSeasonFolders;
    if (instance != null) {
      setPreference(_useSeasonFoldersKey, _useSeasonFolders);
    } else {
      SonarrPreferences.ADD_SERIES_DEFAULT_USE_SEASON_FOLDERS.update(
        _useSeasonFolders,
      );
    }
    notifyListeners();
  }

  void initializeUseSeasonFolders() {
    _useSeasonFolders = preference(
      _useSeasonFoldersKey,
      SonarrPreferences.ADD_SERIES_DEFAULT_USE_SEASON_FOLDERS.read(),
    );
  }

  late SonarrSeriesType _seriesType;
  SonarrSeriesType get seriesType => _seriesType;
  set seriesType(SonarrSeriesType seriesType) {
    _seriesType = seriesType;
    if (instance != null) {
      setPreference(_seriesTypeKey, _seriesType.value);
    } else {
      SonarrPreferences.ADD_SERIES_DEFAULT_SERIES_TYPE.update(
        _seriesType.value!,
      );
    }
    notifyListeners();
  }

  void initializeSeriesType() {
    _seriesType = SonarrSeriesType.values.firstWhere(
      (element) =>
          element.value ==
          preference(
            _seriesTypeKey,
            SonarrPreferences.ADD_SERIES_DEFAULT_SERIES_TYPE.read(),
          ),
      orElse: () => SonarrSeriesType.STANDARD,
    );
  }

  late SonarrSeriesMonitorType _monitorType;
  SonarrSeriesMonitorType get monitorType => _monitorType;
  set monitorType(SonarrSeriesMonitorType monitorType) {
    _monitorType = monitorType;
    if (instance != null) {
      setPreference(_monitorTypeKey, _monitorType.value);
    } else {
      SonarrPreferences.ADD_SERIES_DEFAULT_MONITOR_TYPE.update(
        _monitorType.value!,
      );
    }
    notifyListeners();
  }

  void initializeMonitorType() {
    _monitorType = SonarrSeriesMonitorType.values.firstWhere(
      (element) =>
          element.value ==
          preference(
            _monitorTypeKey,
            SonarrPreferences.ADD_SERIES_DEFAULT_MONITOR_TYPE.read(),
          ),
      orElse: () => SonarrSeriesMonitorType.ALL,
    );
  }

  late SonarrRootFolder _rootFolder;
  SonarrRootFolder get rootFolder => _rootFolder;
  set rootFolder(SonarrRootFolder rootFolder) {
    _rootFolder = rootFolder;
    if (instance != null) {
      setPreference(_rootFolderKey, _rootFolder.id);
    } else {
      SonarrPreferences.ADD_SERIES_DEFAULT_ROOT_FOLDER.update(_rootFolder.id);
    }
    notifyListeners();
  }

  void initializeRootFolder(List<SonarrRootFolder> rootFolders) {
    _rootFolder = rootFolders.firstWhere(
      (element) =>
          element.id ==
          preference(
            _rootFolderKey,
            SonarrPreferences.ADD_SERIES_DEFAULT_ROOT_FOLDER.read(),
          ),
      orElse: () => rootFolders.isNotEmpty
          ? rootFolders[0]
          : SonarrRootFolder(id: -1, freeSpace: 0, path: LunaUI.TEXT_EMDASH),
    );
  }

  late SonarrQualityProfile _qualityProfile;
  SonarrQualityProfile get qualityProfile => _qualityProfile;
  set qualityProfile(SonarrQualityProfile qualityProfile) {
    _qualityProfile = qualityProfile;
    if (instance != null) {
      setPreference(_qualityProfileKey, _qualityProfile.id);
    } else {
      SonarrPreferences.ADD_SERIES_DEFAULT_QUALITY_PROFILE.update(
        _qualityProfile.id,
      );
    }
    notifyListeners();
  }

  void initializeQualityProfile(List<SonarrQualityProfile> qualityProfiles) {
    _qualityProfile = qualityProfiles.firstWhere(
      (element) =>
          element.id ==
          preference(
            _qualityProfileKey,
            SonarrPreferences.ADD_SERIES_DEFAULT_QUALITY_PROFILE.read(),
          ),
      orElse: () => qualityProfiles.isNotEmpty
          ? qualityProfiles[0]
          : SonarrQualityProfile(id: -1, name: LunaUI.TEXT_EMDASH),
    );
  }

  late SonarrLanguageProfile _languageProfile;
  SonarrLanguageProfile get languageProfile => _languageProfile;
  set languageProfile(SonarrLanguageProfile languageProfile) {
    _languageProfile = languageProfile;
    if (instance != null) {
      setPreference(_languageProfileKey, _languageProfile.id);
    } else {
      SonarrPreferences.ADD_SERIES_DEFAULT_LANGUAGE_PROFILE.update(
        _languageProfile.id,
      );
    }
    notifyListeners();
  }

  void initializeLanguageProfile(List<SonarrLanguageProfile> languageProfiles) {
    _languageProfile = languageProfiles.firstWhere(
      (element) =>
          element.id ==
          preference(
            _languageProfileKey,
            SonarrPreferences.ADD_SERIES_DEFAULT_LANGUAGE_PROFILE.read(),
          ),
      orElse: () => languageProfiles.isNotEmpty
          ? languageProfiles[0]
          : SonarrLanguageProfile(id: -1, name: LunaUI.TEXT_EMDASH),
    );
  }

  late List<SonarrTag> _tags;
  List<SonarrTag> get tags => _tags;
  set tags(List<SonarrTag> tags) {
    _tags = tags;
    final tagIds = tags.map<int?>((tag) => tag.id).toList();
    if (instance != null) {
      setPreference(_tagsKey, tagIds);
    } else {
      SonarrPreferences.ADD_SERIES_DEFAULT_TAGS.update(tagIds);
    }
    notifyListeners();
  }

  void initializeTags(List<SonarrTag> tags) {
    _tags = tags
        .where(
          (tag) => preference(
            _tagsKey,
            SonarrPreferences.ADD_SERIES_DEFAULT_TAGS.read(),
          ).contains(tag.id),
        )
        .toList();
  }

  LunaLoadingState _state = LunaLoadingState.INACTIVE;
  LunaLoadingState get state => _state;
  set state(LunaLoadingState state) {
    _state = state;
    notifyListeners();
  }
}
