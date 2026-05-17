import 'package:lunasea/core.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/system/gateway/service_endpoint.dart';

class LidarrAlbumData {
  String title;
  String releaseDate;
  int albumID;
  int trackCount;
  double percentageTracks;
  bool monitored;

  LidarrAlbumData({
    required this.albumID,
    required this.title,
    required this.monitored,
    required this.trackCount,
    required this.percentageTracks,
    required this.releaseDate,
  });

  DateTime? get releaseDateObject => DateTime.tryParse(releaseDate)?.toLocal();

  String get releaseDateString {
    if (releaseDateObject != null) {
      return DateFormat('MMMM dd, y').format(releaseDateObject!);
    }
    return 'Unknown Release Date';
  }

  String get tracks {
    return trackCount != 1 ? '$trackCount Tracks' : '$trackCount Track';
  }

  String albumCoverURI(LunaServiceInstance? instance) {
    if (instance != null && instance.enabled) {
      final endpoint = LunaServiceEndpoint.fromInstance(instance);
      final url =
          '${endpoint.mediaCoverBase('api/v1', 'MediaCover/Album')}/$albumID/cover-250.jpg';
      return endpoint.authenticatedUrl(url, instance.apiKey);
    }
    return '';
  }
}
