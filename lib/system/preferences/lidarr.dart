import 'package:lunasea/system/preferences/preference.dart';
import 'package:lunasea/modules/lidarr/core/api/data/metadata.dart';
import 'package:lunasea/modules/lidarr/core/api/data/qualityprofile.dart';
import 'package:lunasea/modules/lidarr/core/api/data/rootfolder.dart';

enum LidarrPreferences<T> with BackendPreference<T> {
  NAVIGATION_INDEX<int>(0),
  ADD_MONITORED_STATUS<String>('all'),
  ADD_ARTIST_SEARCH_FOR_MISSING<bool>(true),
  ADD_ALBUM_FOLDERS<bool>(true),
  ADD_QUALITY_PROFILE<LidarrQualityProfile?>(null),
  ADD_METADATA_PROFILE<LidarrMetadataProfile?>(null),
  ADD_ROOT_FOLDER<LidarrRootFolder?>(null);

  @override
  BackendPreferenceGroup get table => BackendPreferenceGroup.lidarr;

  @override
  final T fallback;

  const LidarrPreferences(this.fallback);
  @override
  List<LidarrPreferences> get blockedFromImportExport {
    return [
      LidarrPreferences.ADD_ALBUM_FOLDERS,
      LidarrPreferences.ADD_QUALITY_PROFILE,
      LidarrPreferences.ADD_METADATA_PROFILE,
      LidarrPreferences.ADD_ROOT_FOLDER,
    ];
  }
}
