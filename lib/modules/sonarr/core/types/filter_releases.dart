import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sonarr.dart';

enum SonarrReleasesFilter {
  ALL,
  APPROVED,
  REJECTED,
}

extension SonarrReleasesFilterExtension on SonarrReleasesFilter {
  SonarrReleasesFilter? fromKey(String? key) {
    switch (key) {
      case 'all':
        return SonarrReleasesFilter.ALL;
      case 'approved':
        return SonarrReleasesFilter.APPROVED;
      case 'rejected':
        return SonarrReleasesFilter.REJECTED;
      default:
        return null;
    }
  }

  String get key {
    switch (this) {
      case SonarrReleasesFilter.ALL:
        return 'all';
      case SonarrReleasesFilter.APPROVED:
        return 'approved';
      case SonarrReleasesFilter.REJECTED:
        return 'rejected';
    }
  }

  String get readable {
    switch (this) {
      case SonarrReleasesFilter.ALL:
        return 'sonarr.All'.tr();
      case SonarrReleasesFilter.APPROVED:
        return 'sonarr.Approved'.tr();
      case SonarrReleasesFilter.REJECTED:
        return 'sonarr.Rejected'.tr();
    }
  }

  List<SonarrRelease> filter(List<SonarrRelease> releases) =>
      _Filterer().byType(releases, this);
}

class _Filterer {
  List<SonarrRelease> byType(
    List<SonarrRelease> releases,
    SonarrReleasesFilter type,
  ) {
    switch (type) {
      case SonarrReleasesFilter.ALL:
        return releases;
      case SonarrReleasesFilter.APPROVED:
        return _approved(releases);
      case SonarrReleasesFilter.REJECTED:
        return _rejected(releases);
    }
  }

  List<SonarrRelease> _approved(List<SonarrRelease> releases) =>
      releases.where((element) => element.approved!).toList();
  List<SonarrRelease> _rejected(List<SonarrRelease> releases) =>
      releases.where((element) => !element.approved!).toList();
}
