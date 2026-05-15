import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/extensions/datetime.dart';
import 'package:lunasea/extensions/double/time.dart';
import 'package:lunasea/modules/radarr.dart';

extension LunaRadarrEventType on RadarrEventType {
  // Get LunaSea associated colour of the event type.
  Color get lunaColour {
    switch (this) {
      case RadarrEventType.GRABBED:
        return LunaColours.orange;
      case RadarrEventType.DOWNLOAD_FAILED:
        return LunaColours.red;
      case RadarrEventType.DOWNLOAD_FOLDER_IMPORTED:
        return LunaColours.accent;
      case RadarrEventType.DOWNLOAD_IGNORED:
        return LunaColours.purple;
      case RadarrEventType.MOVIE_FILE_DELETED:
        return LunaColours.red;
      case RadarrEventType.MOVIE_FILE_RENAMED:
        return LunaColours.blue;
      case RadarrEventType.MOVIE_FOLDER_IMPORTED:
        return LunaColours.accent;
    }
  }

  IconData get lunaIcon {
    switch (this) {
      case RadarrEventType.GRABBED:
        return Icons.cloud_download_rounded;
      case RadarrEventType.DOWNLOAD_FAILED:
        return Icons.cloud_download_rounded;
      case RadarrEventType.DOWNLOAD_FOLDER_IMPORTED:
        return Icons.download_rounded;
      case RadarrEventType.MOVIE_FOLDER_IMPORTED:
        return Icons.download_rounded;
      case RadarrEventType.MOVIE_FILE_DELETED:
        return Icons.delete_rounded;
      case RadarrEventType.DOWNLOAD_IGNORED:
        return Icons.cancel_rounded;
      case RadarrEventType.MOVIE_FILE_RENAMED:
        return Icons.drive_file_rename_outline_rounded;
    }
  }

  Color get lunaIconColour {
    switch (this) {
      case RadarrEventType.GRABBED:
        return Colors.white;
      case RadarrEventType.DOWNLOAD_FAILED:
        return LunaColours.red;
      case RadarrEventType.DOWNLOAD_FOLDER_IMPORTED:
        return Colors.white;
      case RadarrEventType.DOWNLOAD_IGNORED:
        return Colors.white;
      case RadarrEventType.MOVIE_FILE_DELETED:
        return Colors.white;
      case RadarrEventType.MOVIE_FILE_RENAMED:
        return Colors.white;
      case RadarrEventType.MOVIE_FOLDER_IMPORTED:
        return Colors.white;
    }
  }

  String? lunaReadable(RadarrHistoryRecord record) {
    switch (this) {
      case RadarrEventType.GRABBED:
        return 'radarr.GrabbedFrom'
            .tr(args: [(record.data ?? {})['indexer'] ?? LunaUI.TEXT_EMDASH]);
      case RadarrEventType.DOWNLOAD_FAILED:
        return 'radarr.DownloadFailed'.tr();
      case RadarrEventType.DOWNLOAD_FOLDER_IMPORTED:
        return 'radarr.MovieImported'
            .tr(args: [record.quality?.quality?.name ?? LunaUI.TEXT_EMDASH]);
      case RadarrEventType.DOWNLOAD_IGNORED:
        return 'radarr.DownloadIgnored'.tr();
      case RadarrEventType.MOVIE_FILE_DELETED:
        return 'radarr.MovieFileDeleted'.tr();
      case RadarrEventType.MOVIE_FILE_RENAMED:
        return 'radarr.MovieFileRenamed'.tr();
      case RadarrEventType.MOVIE_FOLDER_IMPORTED:
        return 'radarr.MovieImported'
            .tr(args: [record.quality?.quality?.name ?? LunaUI.TEXT_EMDASH]);
    }
  }

  List<BackendPreferenceGroupContent> lunaTableContent(
    RadarrHistoryRecord record, {
    bool movieHistory = false,
  }) {
    switch (this) {
      case RadarrEventType.GRABBED:
        return _grabbedTableContent(record, !movieHistory);
      case RadarrEventType.DOWNLOAD_FAILED:
        return _downloadFailedTableContent(record, !movieHistory);
      case RadarrEventType.DOWNLOAD_FOLDER_IMPORTED:
        return _downloadFolderImportedTableContent(record);
      case RadarrEventType.DOWNLOAD_IGNORED:
        return _downloadIgnoredTableContent(record, !movieHistory);
      case RadarrEventType.MOVIE_FILE_DELETED:
        return _movieFileDeletedTableContent(record, !movieHistory);
      case RadarrEventType.MOVIE_FILE_RENAMED:
        return _movieFileRenamedTableContent(record);
      case RadarrEventType.MOVIE_FOLDER_IMPORTED:
        return _movieFolderImportedTableContent(record);
      default:
        return [];
    }
  }

  List<BackendPreferenceGroupContent> _grabbedTableContent(
    RadarrHistoryRecord record,
    bool showSourceTitle,
  ) {
    return [
      if (showSourceTitle)
        BackendPreferenceGroupContent(
          title: 'source title',
          body: record.sourceTitle ?? LunaUI.TEXT_EMDASH,
        ),
      BackendPreferenceGroupContent(
        title: 'quality',
        body: record.quality?.quality?.name ?? LunaUI.TEXT_EMDASH,
      ),
      BackendPreferenceGroupContent(
        title: 'languages',
        body: record.languages
            ?.map<String?>((language) => language.name)
            .join('\n'),
      ),
      BackendPreferenceGroupContent(
        title: 'indexer',
        body: record.data!['indexer'] ?? LunaUI.TEXT_EMDASH,
      ),
      BackendPreferenceGroupContent(
        title: 'group',
        body: record.data!['releaseGroup'] ?? LunaUI.TEXT_EMDASH,
      ),
      BackendPreferenceGroupContent(
        title: 'client',
        body: record.data!['downloadClientName'] ?? LunaUI.TEXT_EMDASH,
      ),
      BackendPreferenceGroupContent(
        title: 'age',
        body: record.data!['ageHours'] != null
            ? double.tryParse((record.data!['ageHours'] as String))
                    ?.asTimeAgo() ??
                LunaUI.TEXT_EMDASH
            : LunaUI.TEXT_EMDASH,
      ),
      BackendPreferenceGroupContent(
        title: 'published date',
        body: DateTime.tryParse(record.data!['publishedDate']) != null
            ? DateTime.tryParse(record.data!['publishedDate'])
                    ?.asDateTime(delimiter: '\n') ??
                LunaUI.TEXT_EMDASH
            : LunaUI.TEXT_EMDASH,
      ),
      BackendPreferenceGroupContent(
        title: 'info url',
        body: record.data!['nzbInfoUrl'] ?? LunaUI.TEXT_EMDASH,
        bodyIsUrl: record.data!['nzbInfoUrl'] != null,
      ),
    ];
  }

  List<BackendPreferenceGroupContent> _downloadFailedTableContent(
    RadarrHistoryRecord record,
    bool showSourceTitle,
  ) {
    return [
      if (showSourceTitle)
        BackendPreferenceGroupContent(
          title: 'source title',
          body: record.sourceTitle ?? LunaUI.TEXT_EMDASH,
        ),
      BackendPreferenceGroupContent(
        title: 'client',
        body: record.data!['downloadClientName'] ?? LunaUI.TEXT_EMDASH,
      ),
      BackendPreferenceGroupContent(
        title: 'message',
        body: record.data!['message'] ?? LunaUI.TEXT_EMDASH,
      ),
    ];
  }

  List<BackendPreferenceGroupContent> _downloadFolderImportedTableContent(
    RadarrHistoryRecord record,
  ) {
    return [
      BackendPreferenceGroupContent(
        title: 'source title',
        body: record.sourceTitle ?? LunaUI.TEXT_EMDASH,
      ),
      BackendPreferenceGroupContent(
        title: 'quality',
        body: record.quality?.quality?.name ?? LunaUI.TEXT_EMDASH,
      ),
      BackendPreferenceGroupContent(
        title: 'languages',
        body: record.languages
                ?.map<String?>((language) => language.name)
                .join('\n') ??
            LunaUI.TEXT_EMDASH,
      ),
      BackendPreferenceGroupContent(
        title: 'client',
        body: record.data!['downloadClientName'] ?? LunaUI.TEXT_EMDASH,
      ),
      BackendPreferenceGroupContent(
        title: 'source',
        body: record.data!['droppedPath'] ?? LunaUI.TEXT_EMDASH,
      ),
      BackendPreferenceGroupContent(
        title: 'imported to',
        body: record.data!['importedPath'] ?? LunaUI.TEXT_EMDASH,
      ),
    ];
  }

  List<BackendPreferenceGroupContent> _downloadIgnoredTableContent(
    RadarrHistoryRecord record,
    bool showSourceTitle,
  ) {
    return [
      if (showSourceTitle)
        BackendPreferenceGroupContent(
          title: 'source title',
          body: record.sourceTitle ?? LunaUI.TEXT_EMDASH,
        ),
      BackendPreferenceGroupContent(
        title: 'message',
        body: record.data!['message'] ?? LunaUI.TEXT_EMDASH,
      ),
    ];
  }

  List<BackendPreferenceGroupContent> _movieFileDeletedTableContent(
    RadarrHistoryRecord record,
    bool showSourceTitle,
  ) {
    return [
      if (showSourceTitle)
        BackendPreferenceGroupContent(
          title: 'source title',
          body: record.sourceTitle ?? LunaUI.TEXT_EMDASH,
        ),
      BackendPreferenceGroupContent(
        title: 'reason',
        body: record.lunaFileDeletedReasonMessage,
      ),
    ];
  }

  List<BackendPreferenceGroupContent> _movieFileRenamedTableContent(
    RadarrHistoryRecord record,
  ) {
    return [
      BackendPreferenceGroupContent(
        title: 'source',
        body: record.data!['sourceRelativePath'] ?? LunaUI.TEXT_EMDASH,
      ),
      BackendPreferenceGroupContent(
        title: 'destination',
        body: record.data!['relativePath'] ?? LunaUI.TEXT_EMDASH,
      ),
    ];
  }

  List<BackendPreferenceGroupContent> _movieFolderImportedTableContent(
    RadarrHistoryRecord record,
  ) {
    return [
      BackendPreferenceGroupContent(
        title: 'source title',
        body: record.sourceTitle ?? LunaUI.TEXT_EMDASH,
      ),
      BackendPreferenceGroupContent(
        title: 'quality',
        body: record.quality?.quality?.name ?? LunaUI.TEXT_EMDASH,
      ),
      BackendPreferenceGroupContent(
        title: 'languages',
        body: ([RadarrLanguage(name: LunaUI.TEXT_EMDASH)])
            .map<String?>((language) => language.name)
            .join('\n'),
      ),
      BackendPreferenceGroupContent(
        title: 'client',
        body: record.data!['downloadClientName'] ?? LunaUI.TEXT_EMDASH,
      ),
      BackendPreferenceGroupContent(
        title: 'source',
        body: record.data!['droppedPath'] ?? LunaUI.TEXT_EMDASH,
      ),
      BackendPreferenceGroupContent(
        title: 'imported to',
        body: record.data!['importedPath'] ?? LunaUI.TEXT_EMDASH,
      ),
    ];
  }
}
