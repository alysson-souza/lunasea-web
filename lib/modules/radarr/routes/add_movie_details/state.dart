import 'package:flutter/material.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/radarr.dart';
import 'package:lunasea/modules/settings.dart';

class RadarrAddMovieDetailsState extends ChangeNotifier {
  static const _monitoredKey = 'addMovieDefaultMonitoredState';
  static const _rootFolderKey = 'addMovieDefaultRootFolderId';
  static const _qualityProfileKey = 'addMovieDefaultQualityProfileId';
  static const _minimumAvailabilityKey = 'addMovieDefaultMinimumAvailabilityId';
  static const _tagsKey = 'addMovieDefaultTags';
  static const _searchForMovieKey = 'addMovieSearchForMissing';

  final LunaServiceInstance? instance;
  final bool isDiscovery;
  final RadarrMovie movie;
  bool canExecuteAction = false;

  RadarrAddMovieDetailsState({
    required this.movie,
    required this.isDiscovery,
    this.instance,
  });

  T preference<T>(String key, T fallback) {
    return instance?.preference<T>(key, fallback) ?? fallback;
  }

  void setPreference(String key, dynamic value) {
    final instance = this.instance;
    if (instance == null) return;
    instance.setPreference(key, value);
    unawaited(SettingsServiceInstanceSettings.save(instance));
  }

  late bool _monitored = preference(
    _monitoredKey,
    RadarrPreferences.ADD_MOVIE_DEFAULT_MONITORED_STATE.read(),
  );

  bool get searchForMovie => preference(
    _searchForMovieKey,
    RadarrPreferences.ADD_MOVIE_SEARCH_FOR_MISSING.read(),
  );

  set searchForMovie(bool searchForMovie) {
    if (instance != null) {
      setPreference(_searchForMovieKey, searchForMovie);
    } else {
      RadarrPreferences.ADD_MOVIE_SEARCH_FOR_MISSING.update(searchForMovie);
    }
    notifyListeners();
  }

  bool get monitored => _monitored;
  set monitored(bool monitored) {
    _monitored = monitored;
    if (instance != null) {
      setPreference(_monitoredKey, _monitored);
    } else {
      RadarrPreferences.ADD_MOVIE_DEFAULT_MONITORED_STATE.update(_monitored);
    }
    notifyListeners();
  }

  late RadarrAvailability _availability;
  RadarrAvailability get availability => _availability;
  set availability(RadarrAvailability availability) {
    _availability = availability;
    if (instance != null) {
      setPreference(_minimumAvailabilityKey, _availability.value);
    } else {
      RadarrPreferences.ADD_MOVIE_DEFAULT_MINIMUM_AVAILABILITY_ID.update(
        _availability.value,
      );
    }
    notifyListeners();
  }

  void initializeAvailability() {
    RadarrAvailability? _ra = RadarrAvailability.TBA.from(
      preference(
        _minimumAvailabilityKey,
        RadarrPreferences.ADD_MOVIE_DEFAULT_MINIMUM_AVAILABILITY_ID.read(),
      ),
    );

    if (_ra == RadarrAvailability.TBA || _ra == RadarrAvailability.PREDB) {
      _availability = RadarrAvailability.ANNOUNCED;
    } else {
      _availability = RadarrAvailability.values.firstWhere(
        (avail) => avail == _ra,
        orElse: () => RadarrAvailability.ANNOUNCED,
      );
    }
  }

  late RadarrRootFolder _rootFolder;
  RadarrRootFolder get rootFolder => _rootFolder;
  set rootFolder(RadarrRootFolder rootFolder) {
    _rootFolder = rootFolder;
    if (instance != null) {
      setPreference(_rootFolderKey, _rootFolder.id);
    } else {
      RadarrPreferences.ADD_MOVIE_DEFAULT_ROOT_FOLDER_ID.update(_rootFolder.id);
    }
    notifyListeners();
  }

  void initializeRootFolder(List<RadarrRootFolder>? rootFolders) {
    _rootFolder = (rootFolders ?? []).firstWhere(
      (element) =>
          element.id ==
          preference(
            _rootFolderKey,
            RadarrPreferences.ADD_MOVIE_DEFAULT_ROOT_FOLDER_ID.read(),
          ),
      orElse: () => (rootFolders?.length ?? 0) != 0
          ? rootFolders![0]
          : RadarrRootFolder(id: -1, freeSpace: 0, path: LunaUI.TEXT_EMDASH),
    );
  }

  late RadarrQualityProfile _qualityProfile;
  RadarrQualityProfile get qualityProfile => _qualityProfile;
  set qualityProfile(RadarrQualityProfile qualityProfile) {
    _qualityProfile = qualityProfile;
    if (instance != null) {
      setPreference(_qualityProfileKey, _qualityProfile.id);
    } else {
      RadarrPreferences.ADD_MOVIE_DEFAULT_QUALITY_PROFILE_ID.update(
        _qualityProfile.id,
      );
    }
    notifyListeners();
  }

  void initializeQualityProfile(List<RadarrQualityProfile>? qualityProfiles) {
    _qualityProfile = (qualityProfiles ?? []).firstWhere(
      (element) =>
          element.id ==
          preference(
            _qualityProfileKey,
            RadarrPreferences.ADD_MOVIE_DEFAULT_QUALITY_PROFILE_ID.read(),
          ),
      orElse: () => (qualityProfiles?.length ?? 0) != 0
          ? qualityProfiles![0]
          : RadarrQualityProfile(id: -1, name: LunaUI.TEXT_EMDASH),
    );
  }

  List<RadarrTag> _tags = [];
  List<RadarrTag> get tags => _tags;
  set tags(List<RadarrTag> tags) {
    _tags = tags;
    final tagIds = tags.map<int?>((tag) => tag.id).toList();
    if (instance != null) {
      setPreference(_tagsKey, tagIds);
    } else {
      RadarrPreferences.ADD_MOVIE_DEFAULT_TAGS.update(tagIds);
    }
    notifyListeners();
  }

  void initializeTags(List<RadarrTag>? tags) {
    _tags = (tags ?? [])
        .where(
          (tag) => preference(
            _tagsKey,
            RadarrPreferences.ADD_MOVIE_DEFAULT_TAGS.read(),
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
