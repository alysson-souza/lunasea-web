import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';

enum SearchDownloadType { NZBGET, SABNZBD, FILESYSTEM }

extension SearchDownloadTypeExtension on SearchDownloadType {
  String get name {
    switch (this) {
      case SearchDownloadType.NZBGET:
        return 'NZBGet';
      case SearchDownloadType.SABNZBD:
        return 'SABnzbd';
      case SearchDownloadType.FILESYSTEM:
        return 'search.DownloadToDevice'.tr();
    }
  }

  IconData get icon {
    switch (this) {
      case SearchDownloadType.NZBGET:
        return LunaModule.NZBGET.icon;
      case SearchDownloadType.SABNZBD:
        return LunaModule.SABNZBD.icon;
      case SearchDownloadType.FILESYSTEM:
        return Icons.download_rounded;
    }
  }
}
