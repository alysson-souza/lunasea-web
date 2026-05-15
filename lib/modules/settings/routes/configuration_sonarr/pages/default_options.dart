import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/settings.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/types/list_view_option.dart';

class ConfigurationSonarrDefaultOptionsRoute extends StatefulWidget {
  const ConfigurationSonarrDefaultOptionsRoute({
    Key? key,
  }) : super(key: key);

  @override
  State<ConfigurationSonarrDefaultOptionsRoute> createState() => _State();
}

class _State extends State<ConfigurationSonarrDefaultOptionsRoute>
    with LunaScrollControllerMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: _appBar(),
      body: _body(),
    );
  }

  PreferredSizeWidget _appBar() {
    return LunaAppBar(
      title: 'settings.DefaultOptions'.tr(),
      scrollControllers: [scrollController],
    );
  }

  Widget _body() {
    return LunaListView(
      controller: scrollController,
      children: [
        LunaHeader(text: 'sonarr.Series'.tr()),
        _filteringSeries(),
        _sortingSeries(),
        _sortingSeriesDirection(),
        _viewSeries(),
        LunaHeader(text: 'sonarr.Releases'.tr()),
        _filteringReleases(),
        _sortingReleases(),
        _sortingReleasesDirection(),
      ],
    );
  }

  Widget _viewSeries() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) {
        LunaListViewOption _view = settings.sonarrSeriesDefaultView;
        return LunaBlock(
          title: 'lunasea.View'.tr(),
          body: [TextSpan(text: _view.readable)],
          trailing: const LunaIconButton.arrow(),
          onTap: () async {
            List<String> titles = LunaListViewOption.values
                .map<String>((view) => view.readable)
                .toList();
            List<IconData> icons = LunaListViewOption.values
                .map<IconData>((view) => view.icon)
                .toList();

            Tuple2<bool, int> values = await SettingsDialogs().setDefaultOption(
              context,
              title: 'lunasea.View'.tr(),
              values: titles,
              icons: icons,
            );

            if (values.item1) {
              LunaListViewOption _opt = LunaListViewOption.values[values.item2];
              await context
                  .read<SettingsStore>()
                  .setSonarrSeriesDefaultView(_opt);
              context.read<SonarrState>().seriesViewType = _opt;
            }
          },
        );
      },
    );
  }

  Widget _sortingSeries() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.SortCategory'.tr(),
        body: [TextSpan(text: settings.sonarrSeriesDefaultSorting.readable)],
        trailing: const LunaIconButton.arrow(),
        onTap: () async {
          List<String?> titles = SonarrSeriesSorting.values
              .map<String?>((sorting) => sorting.readable)
              .toList();
          List<IconData> icons = List.filled(titles.length, LunaIcons.SORT);

          Tuple2<bool, int> values = await SettingsDialogs().setDefaultOption(
            context,
            title: 'settings.SortCategory'.tr(),
            values: titles,
            icons: icons,
          );

          if (values.item1) {
            final sorting = SonarrSeriesSorting.values[values.item2];
            await context
                .read<SettingsStore>()
                .setSonarrSeriesDefaultSorting(sorting);
            context.read<SonarrState>().seriesSortType = sorting;
            context.read<SonarrState>().seriesSortAscending = context
                .read<SettingsStore>()
                .sonarrSeriesDefaultSortingAscending;
          }
        },
      ),
    );
  }

  Widget _sortingSeriesDirection() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.SortDirection'.tr(),
        body: [
          TextSpan(
            text: settings.sonarrSeriesDefaultSortingAscending
                ? 'lunasea.Ascending'.tr()
                : 'lunasea.Descending'.tr(),
          ),
        ],
        trailing: LunaSwitch(
          value: settings.sonarrSeriesDefaultSortingAscending,
          onChanged: context
              .read<SettingsStore>()
              .setSonarrSeriesDefaultSortingAscending,
        ),
      ),
    );
  }

  Widget _filteringSeries() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.FilterCategory'.tr(),
        body: [TextSpan(text: settings.sonarrSeriesDefaultFilter.readable)],
        trailing: const LunaIconButton.arrow(),
        onTap: () async {
          List<String> titles = SonarrSeriesFilter.values
              .map<String>((sorting) => sorting.readable)
              .toList();
          List<IconData> icons = List.filled(titles.length, LunaIcons.FILTER);

          Tuple2<bool, int> values = await SettingsDialogs().setDefaultOption(
            context,
            title: 'settings.FilterCategory'.tr(),
            values: titles,
            icons: icons,
          );

          if (values.item1) {
            await context.read<SettingsStore>().setSonarrSeriesDefaultFilter(
                  SonarrSeriesFilter.values[values.item2],
                );
          }
        },
      ),
    );
  }

  Widget _sortingReleases() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.SortCategory'.tr(),
        body: [TextSpan(text: settings.sonarrReleasesDefaultSorting.readable)],
        trailing: const LunaIconButton.arrow(),
        onTap: () async {
          List<String?> titles = SonarrReleasesSorting.values
              .map<String?>((sorting) => sorting.readable)
              .toList();
          List<IconData> icons = List.filled(titles.length, LunaIcons.SORT);

          Tuple2<bool, int> values = await SettingsDialogs().setDefaultOption(
            context,
            title: 'settings.SortCategory'.tr(),
            values: titles,
            icons: icons,
          );

          if (values.item1) {
            await context.read<SettingsStore>().setSonarrReleasesDefaultSorting(
                  SonarrReleasesSorting.values[values.item2],
                );
          }
        },
      ),
    );
  }

  Widget _sortingReleasesDirection() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.SortDirection'.tr(),
        body: [
          TextSpan(
            text: settings.sonarrReleasesDefaultSortingAscending
                ? 'lunasea.Ascending'.tr()
                : 'lunasea.Descending'.tr(),
          ),
        ],
        trailing: LunaSwitch(
          value: settings.sonarrReleasesDefaultSortingAscending,
          onChanged: context
              .read<SettingsStore>()
              .setSonarrReleasesDefaultSortingAscending,
        ),
      ),
    );
  }

  Widget _filteringReleases() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.FilterCategory'.tr(),
        body: [TextSpan(text: settings.sonarrReleasesDefaultFilter.readable)],
        trailing: const LunaIconButton.arrow(),
        onTap: () async {
          List<String> titles = SonarrReleasesFilter.values
              .map<String>((sorting) => sorting.readable)
              .toList();
          List<IconData> icons = List.filled(titles.length, LunaIcons.FILTER);

          Tuple2<bool, int> values = await SettingsDialogs().setDefaultOption(
            context,
            title: 'settings.FilterCategory'.tr(),
            values: titles,
            icons: icons,
          );

          if (values.item1) {
            await context.read<SettingsStore>().setSonarrReleasesDefaultFilter(
                  SonarrReleasesFilter.values[values.item2],
                );
          }
        },
      ),
    );
  }
}
