import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/database/models/indexer.dart';
import 'package:lunasea/router/routes/settings.dart';

class ConfigurationSearchRoute extends StatefulWidget {
  const ConfigurationSearchRoute({super.key});

  @override
  State<ConfigurationSearchRoute> createState() => _State();
}

class _State extends State<ConfigurationSearchRoute>
    with LunaScrollControllerMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: _appBar(),
      body: _body(),
      bottomNavigationBar: _bottomNavigationBar(),
    );
  }

  PreferredSizeWidget _appBar() {
    return LunaAppBar(
      title: 'search.Search'.tr(),
      scrollControllers: [scrollController],
    );
  }

  Widget _bottomNavigationBar() {
    return LunaBottomActionBar(
      actions: [
        LunaButton.text(
          text: 'search.AddIndexer'.tr(),
          icon: Icons.add_rounded,
          onTap: SettingsRoutes.CONFIGURATION_SEARCH_ADD_INDEXER.go,
        ),
      ],
    );
  }

  Widget _body() {
    return Consumer<IndexersStore>(
      builder: (context, indexers, _) => LunaListView(
        controller: scrollController,
        children: [
          LunaModule.SEARCH.informationBanner(),
          ..._indexerSection(indexers),
          ..._customization(),
        ],
      ),
    );
  }

  List<Widget> _indexerSection(IndexersStore store) {
    if (store.isEmpty) {
      return [LunaMessage(text: 'search.NoIndexersFound'.tr())];
    }
    return _indexers(store);
  }

  List<Widget> _indexers(IndexersStore store) {
    List<LunaIndexer> indexers = store.indexers;
    indexers.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    List<LunaBlock> list = List.generate(
      indexers.length,
      (index) =>
          _indexerTile(indexers[index], indexers[index].key) as LunaBlock,
    );
    return list;
  }

  Widget _indexerTile(LunaIndexer indexer, int index) {
    return LunaBlock(
      title: indexer.displayName,
      body: [TextSpan(text: indexer.host)],
      trailing: const LunaIconButton.arrow(),
      onTap: () => SettingsRoutes.CONFIGURATION_SEARCH_EDIT_INDEXER.go(
        params: {'id': index.toString()},
      ),
    );
  }

  List<Widget> _customization() {
    return [LunaDivider(), _hideAdultCategories(), _showLinks()];
  }

  Widget _hideAdultCategories() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'search.HideAdultCategories'.tr(),
        body: [TextSpan(text: 'search.HideAdultCategoriesDescription'.tr())],
        trailing: LunaSwitch(
          value: settings.searchHideAdultCategories,
          onChanged: context.read<SettingsStore>().setSearchHideAdultCategories,
        ),
      ),
    );
  }

  Widget _showLinks() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'search.ShowLinks'.tr(),
        body: [TextSpan(text: 'search.ShowLinksDescription'.tr())],
        trailing: LunaSwitch(
          value: settings.searchShowLinks,
          onChanged: context.read<SettingsStore>().setSearchShowLinks,
        ),
      ),
    );
  }
}
