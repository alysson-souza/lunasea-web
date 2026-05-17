import 'package:flutter/widgets.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/lidarr.dart';

class LidarrState extends LunaModuleState {
  final LunaServiceInstance? instance;

  LidarrState({this.instance}) {
    reset();
  }

  @override
  void reset() {}

  LidarrAPI api(BuildContext context) {
    final selected = selectedInstance(context);
    if (selected != null) return LidarrAPI.fromInstance(selected);
    throw StateError('No enabled Lidarr service instance is configured.');
  }

  LunaServiceInstance? selectedInstance(BuildContext context) {
    final selected = instance;
    if (selected != null) return selected;
    final profile = context.read<ProfilesStore>().active;
    final instances = profile.enabledInstances(LunaModule.LIDARR);
    return instances.isEmpty ? null : instances.first;
  }

  ///Catalogue Sticky Header Content
  String _searchCatalogueFilter = '';
  String get searchCatalogueFilter => _searchCatalogueFilter;
  set searchCatalogueFilter(String searchCatalogueFilter) {
    _searchCatalogueFilter = searchCatalogueFilter;
    notifyListeners();
  }

  LidarrCatalogueSorting _sortCatalogueType =
      LidarrCatalogueSorting.alphabetical;
  LidarrCatalogueSorting get sortCatalogueType => _sortCatalogueType;
  set sortCatalogueType(LidarrCatalogueSorting sortCatalogueType) {
    _sortCatalogueType = sortCatalogueType;
    notifyListeners();
  }

  bool _sortCatalogueAscending = true;
  bool get sortCatalogueAscending => _sortCatalogueAscending;
  set sortCatalogueAscending(bool sortCatalogueAscending) {
    _sortCatalogueAscending = sortCatalogueAscending;
    notifyListeners();
  }

  bool _hideUnmonitoredArtists = false;
  bool get hideUnmonitoredArtists => _hideUnmonitoredArtists;
  set hideUnmonitoredArtists(bool hideUnmonitoredArtists) {
    _hideUnmonitoredArtists = hideUnmonitoredArtists;
    notifyListeners();
  }

  ///Releases Sticky Header Content

  String _searchReleasesFilter = '';
  String get searchReleasesFilter => _searchReleasesFilter;
  set searchReleasesFilter(String searchReleasesFilter) {
    _searchReleasesFilter = searchReleasesFilter;
    notifyListeners();
  }

  LidarrReleasesSorting _sortReleasesType = LidarrReleasesSorting.weight;
  LidarrReleasesSorting get sortReleasesType => _sortReleasesType;
  set sortReleasesType(LidarrReleasesSorting sortReleasesType) {
    _sortReleasesType = sortReleasesType;
    notifyListeners();
  }

  bool _sortReleasesAscending = true;
  bool get sortReleasesAscending => _sortReleasesAscending;
  set sortReleasesAscending(bool sortReleasesAscending) {
    _sortReleasesAscending = sortReleasesAscending;
    notifyListeners();
  }

  bool _hideRejectedReleases = false;
  bool get hideRejectedReleases => _hideRejectedReleases;
  set hideRejectedReleases(bool hideRejectedReleases) {
    _hideRejectedReleases = hideRejectedReleases;
    notifyListeners();
  }

  /// Add New Series Content

  String _addSearchQuery = '';
  String get addSearchQuery => _addSearchQuery;
  set addSearchQuery(String addSearchQuery) {
    _addSearchQuery = addSearchQuery;
    notifyListeners();
  }
}
