import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/radarr.dart';
import 'package:lunasea/modules/settings.dart';
import 'package:lunasea/types/list_view_option.dart';

class ConfigurationRadarrDefaultOptionsRoute extends StatefulWidget {
  const ConfigurationRadarrDefaultOptionsRoute({super.key});

  @override
  State<ConfigurationRadarrDefaultOptionsRoute> createState() => _State();
}

class _State extends State<ConfigurationRadarrDefaultOptionsRoute>
    with LunaScrollControllerMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: _appBar() as PreferredSizeWidget?,
      body: _body(),
    );
  }

  Widget _appBar() {
    return LunaAppBar(
      title: 'settings.DefaultOptions'.tr(),
      scrollControllers: [scrollController],
    );
  }

  Widget _body() {
    return LunaListView(
      controller: scrollController,
      children: [
        LunaHeader(text: 'radarr.Movies'.tr()),
        _filteringMovies(),
        _sortingMovies(),
        _sortingMoviesDirection(),
        _viewMovies(),
        LunaHeader(text: 'radarr.Releases'.tr()),
        _filteringReleases(),
        _sortingReleases(),
        _sortingReleasesDirection(),
      ],
    );
  }

  Widget _viewMovies() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) {
        final view = settings.radarrMoviesDefaultView;
        return LunaBlock(
          title: 'lunasea.View'.tr(),
          body: [TextSpan(text: view.readable)],
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
              await context.read<SettingsStore>().setRadarrMoviesDefaultView(
                _opt,
              );
              context.read<RadarrState>().moviesViewType = _opt;
            }
          },
        );
      },
    );
  }

  Widget _sortingMovies() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.SortCategory'.tr(),
        body: [TextSpan(text: settings.radarrMoviesDefaultSorting.readable)],
        trailing: const LunaIconButton.arrow(),
        onTap: () async {
          List<String> titles = RadarrMoviesSorting.values
              .map<String>((sorting) => sorting.readable)
              .toList();
          List<IconData> icons = List.filled(titles.length, LunaIcons.SORT);

          Tuple2<bool, int> values = await SettingsDialogs().setDefaultOption(
            context,
            title: 'settings.SortCategory'.tr(),
            values: titles,
            icons: icons,
          );

          if (values.item1) {
            final sorting = RadarrMoviesSorting.values[values.item2];
            await context.read<SettingsStore>().setRadarrMoviesDefaultSorting(
              sorting,
            );
            context.read<RadarrState>().moviesSortType = sorting;
            context.read<RadarrState>().moviesSortAscending = context
                .read<SettingsStore>()
                .radarrMoviesDefaultSortingAscending;
          }
        },
      ),
    );
  }

  Widget _sortingMoviesDirection() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.SortDirection'.tr(),
        body: [
          TextSpan(
            text: settings.radarrMoviesDefaultSortingAscending
                ? 'lunasea.Ascending'.tr()
                : 'lunasea.Descending'.tr(),
          ),
        ],
        trailing: LunaSwitch(
          value: settings.radarrMoviesDefaultSortingAscending,
          onChanged: (value) async {
            await context
                .read<SettingsStore>()
                .setRadarrMoviesDefaultSortingAscending(value);
            context.read<RadarrState>().moviesSortType = context
                .read<SettingsStore>()
                .radarrMoviesDefaultSorting;
            context.read<RadarrState>().moviesSortAscending = value;
          },
        ),
      ),
    );
  }

  Widget _filteringMovies() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.FilterCategory'.tr(),
        body: [TextSpan(text: settings.radarrMoviesDefaultFilter.readable)],
        trailing: const LunaIconButton.arrow(),
        onTap: () async {
          List<String?> titles = RadarrMoviesFilter.values
              .map<String?>((filter) => filter.readable)
              .toList();
          List<IconData> icons = List.filled(titles.length, LunaIcons.FILTER);

          Tuple2<bool, int> values = await SettingsDialogs().setDefaultOption(
            context,
            title: 'settings.FilterCategory'.tr(),
            values: titles,
            icons: icons,
          );

          if (values.item1) {
            final filter = RadarrMoviesFilter.values[values.item2];
            await context.read<SettingsStore>().setRadarrMoviesDefaultFilter(
              filter,
            );
            context.read<RadarrState>().moviesFilterType = filter;
          }
        },
      ),
    );
  }

  Widget _sortingReleases() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.SortCategory'.tr(),
        body: [TextSpan(text: settings.radarrReleasesDefaultSorting.readable)],
        trailing: const LunaIconButton.arrow(),
        onTap: () async {
          List<String?> titles = RadarrReleasesSorting.values
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
            await context.read<SettingsStore>().setRadarrReleasesDefaultSorting(
              RadarrReleasesSorting.values[values.item2],
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
            text: settings.radarrReleasesDefaultSortingAscending
                ? 'lunasea.Ascending'.tr()
                : 'lunasea.Descending'.tr(),
          ),
        ],
        trailing: LunaSwitch(
          value: settings.radarrReleasesDefaultSortingAscending,
          onChanged: context
              .read<SettingsStore>()
              .setRadarrReleasesDefaultSortingAscending,
        ),
      ),
    );
  }

  Widget _filteringReleases() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.FilterCategory'.tr(),
        body: [TextSpan(text: settings.radarrReleasesDefaultFilter.readable)],
        trailing: const LunaIconButton.arrow(),
        onTap: () async {
          List<String?> titles = RadarrReleasesFilter.values
              .map<String?>((sorting) => sorting.readable)
              .toList();
          List<IconData> icons = List.filled(titles.length, LunaIcons.FILTER);

          Tuple2<bool, int> values = await SettingsDialogs().setDefaultOption(
            context,
            title: 'settings.FilterCategory'.tr(),
            values: titles,
            icons: icons,
          );

          if (values.item1) {
            await context.read<SettingsStore>().setRadarrReleasesDefaultFilter(
              RadarrReleasesFilter.values[values.item2],
            );
          }
        },
      ),
    );
  }
}
