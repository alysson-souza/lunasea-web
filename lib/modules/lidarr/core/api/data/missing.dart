import 'package:lunasea/core.dart';
import 'package:lunasea/system/gateway/service_endpoint.dart';

class LidarrMissingData {
  String title;
  String artistTitle;
  String releaseDate;
  int artistID;
  int albumID;
  bool monitored;

  LidarrMissingData({
    required this.title,
    required this.artistTitle,
    required this.artistID,
    required this.albumID,
    required this.releaseDate,
    required this.monitored,
  });

  DateTime? get releaseDateObject {
    return DateTime.tryParse(releaseDate)?.toLocal();
  }

  String get releaseDateString {
    if (releaseDateObject != null) {
      Duration age = DateTime.now().difference(releaseDateObject!);
      if (age.inDays >= 1) {
        return age.inDays <= 1
            ? '${age.inDays} Day Ago'
            : '${age.inDays} Days Ago';
      }
      if (age.inHours >= 1) {
        return age.inHours <= 1
            ? '${age.inHours} Hour Ago'
            : '${age.inHours} Hours Ago';
      }
      return age.inMinutes <= 1
          ? '${age.inMinutes} Minute Ago'
          : '${age.inMinutes} Minutes Ago';
    }
    return 'Unknown Date/Time';
  }

  String albumCoverURI(LunaProfile profile) {
    final endpoint =
        LunaServiceEndpoint.fromProfile(profile, LunaModule.LIDARR);
    if (profile.lidarrEnabled) {
      final url =
          '${endpoint.mediaCoverBase('api/v1', 'MediaCover/Album')}/$albumID/cover-250.jpg';
      return endpoint.authenticatedUrl(url, profile.lidarrKey);
    }
    return '';
  }

  String posterURI(LunaProfile profile) {
    final endpoint =
        LunaServiceEndpoint.fromProfile(profile, LunaModule.LIDARR);
    if (profile.lidarrEnabled) {
      final url =
          '${endpoint.mediaCoverBase('api/v1', 'MediaCover/Artist')}/$artistID/poster-500.jpg';
      return endpoint.authenticatedUrl(url, profile.lidarrKey);
    }
    return '';
  }

  String fanartURI(LunaProfile profile, {bool highRes = false}) {
    final endpoint =
        LunaServiceEndpoint.fromProfile(profile, LunaModule.LIDARR);
    if (profile.lidarrEnabled) {
      final url =
          '${endpoint.mediaCoverBase('api/v1', 'MediaCover/Artist')}/$artistID/fanart-360.jpg';
      return endpoint.authenticatedUrl(url, profile.lidarrKey);
    }
    return '';
  }
}
