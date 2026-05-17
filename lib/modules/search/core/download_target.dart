import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules/nzbget.dart';
import 'package:lunasea/modules/sabnzbd.dart';
import 'package:lunasea/modules/search.dart';
import 'package:lunasea/system/filesystem/filesystem.dart';
import 'package:lunasea/widgets/sheets/download_client/target.dart';

class SearchDownloadTarget {
  final SearchDownloadType type;
  final LunaServiceInstance? instance;

  const SearchDownloadTarget(this.type, {this.instance});

  String get label => instance == null
      ? type.name
      : '${instance!.module.title} - ${instance!.displayName}';

  IconData get icon => type.icon;

  static List<SearchDownloadTarget> available(LunaProfile profile) {
    return [
      ...DownloadClientTarget.available(profile).map(
        (target) => SearchDownloadTarget(
          target.instance.module == LunaModule.SABNZBD
              ? SearchDownloadType.SABNZBD
              : SearchDownloadType.NZBGET,
          instance: target.instance,
        ),
      ),
      const SearchDownloadTarget(SearchDownloadType.FILESYSTEM),
    ];
  }

  Future<void> execute(BuildContext context, NewznabResultData data) async {
    switch (type) {
      case SearchDownloadType.NZBGET:
        final selected = instance;
        if (selected == null) return;
        return _executeNZBGet(selected, data);
      case SearchDownloadType.SABNZBD:
        final selected = instance;
        if (selected == null) return;
        return _executeSABnzbd(selected, data);
      case SearchDownloadType.FILESYSTEM:
        return _executeFileSystem(context, data);
    }
  }

  Future<void> _executeNZBGet(
    LunaServiceInstance instance,
    NewznabResultData data,
  ) async {
    final api = NZBGetAPI.fromInstance(instance);
    await api
        .uploadURL(data.linkDownload)
        .then(
          (_) => showLunaSuccessSnackBar(
            title: 'search.SentNZBData'.tr(),
            message: 'search.SentTo'.tr(args: [label]),
            showButton: true,
            buttonOnPressed: () => instance.module.launchInstance(instance),
          ),
        )
        .catchError((error, stack) {
          LunaLogger().error('Failed to download data', error, stack);
          return showLunaErrorSnackBar(
            title: 'search.FailedToSend'.tr(),
            error: error,
          );
        });
  }

  Future<void> _executeSABnzbd(
    LunaServiceInstance instance,
    NewznabResultData data,
  ) async {
    final api = SABnzbdAPI.fromInstance(instance);
    await api
        .uploadURL(data.linkDownload)
        .then(
          (_) => showLunaSuccessSnackBar(
            title: 'search.SentNZBData'.tr(),
            message: 'search.SentTo'.tr(args: [label]),
            showButton: true,
            buttonOnPressed: () => instance.module.launchInstance(instance),
          ),
        )
        .catchError((error, stack) {
          LunaLogger().error('Failed to download data', error, stack);
          return showLunaErrorSnackBar(
            title: 'search.FailedToSend'.tr(),
            error: error,
          );
        });
  }

  Future<void> _executeFileSystem(
    BuildContext context,
    NewznabResultData data,
  ) async {
    showLunaInfoSnackBar(
      title: 'search.Downloading'.tr(),
      message: 'search.DownloadingNZBToDevice'.tr(),
    );
    final cleanTitle = data.title.replaceAll(RegExp(r'[^0-9a-zA-Z. -]+'), '');
    try {
      context.read<SearchState>().api.downloadRelease(data).then((
        download,
      ) async {
        final result = await LunaFileSystem().save(
          context,
          '$cleanTitle.nzb',
          utf8.encode(download!),
        );
        if (result) {
          showLunaSuccessSnackBar(
            title: 'Saved NZB',
            message: 'NZB has been successfully saved',
          );
        }
      });
    } catch (error, stack) {
      LunaLogger().error('Error downloading NZB', error, stack);
      showLunaErrorSnackBar(
        title: 'search.FailedToDownloadNZB'.tr(),
        error: error,
      );
    }
  }
}
