import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/sonarr.dart';

void main() {
  test('add series details reads defaults from its service instance', () {
    final instance = LunaServiceInstance(
      id: 'sonarr-main',
      module: LunaModule.SONARR,
      preferences: {
        'addSeriesDefaultRootFolder': 2,
        'addSeriesDefaultQualityProfile': 20,
        'addSeriesDefaultLanguageProfile': 200,
        'addSeriesDefaultTags': [100, 300],
        'addSeriesDefaultMonitored': false,
        'addSeriesDefaultUseSeasonFolders': false,
        'addSeriesDefaultSeriesType': 'anime',
        'addSeriesDefaultMonitorType': 'future',
        'addSeriesSearchForMissing': true,
        'addSeriesSearchForCutoffUnmet': true,
      },
    );
    final state = SonarrSeriesAddDetailsState(
      series: SonarrSeries(title: 'Example Series'),
      instance: instance,
    );

    state.initializeMonitored();
    state.initializeUseSeasonFolders();
    state.initializeSeriesType();
    state.initializeMonitorType();
    state.initializeRootFolder([
      SonarrRootFolder(id: 1, path: '/series/one'),
      SonarrRootFolder(id: 2, path: '/series/two'),
    ]);
    state.initializeQualityProfile([
      SonarrQualityProfile(id: 10, name: 'HD'),
      SonarrQualityProfile(id: 20, name: 'UHD'),
    ]);
    state.initializeLanguageProfile([
      SonarrLanguageProfile(id: 100, name: 'English'),
      SonarrLanguageProfile(id: 200, name: 'Japanese'),
    ]);
    state.initializeTags([
      SonarrTag(id: 100, label: 'favorite'),
      SonarrTag(id: 200, label: 'skip'),
      SonarrTag(id: 300, label: 'archive'),
    ]);

    expect(state.rootFolder.id, 2);
    expect(state.qualityProfile.id, 20);
    expect(state.languageProfile.id, 200);
    expect(state.tags.map((tag) => tag.id), [100, 300]);
    expect(state.monitored, isFalse);
    expect(state.useSeasonFolders, isFalse);
    expect(state.seriesType, SonarrSeriesType.ANIME);
    expect(state.monitorType, SonarrSeriesMonitorType.FUTURE);
    expect(state.searchForMissingEpisodes, isTrue);
    expect(state.searchForCutoffUnmetEpisodes, isTrue);

    state.searchForMissingEpisodes = false;
    state.searchForCutoffUnmetEpisodes = false;

    expect(instance.preferences['addSeriesSearchForMissing'], isFalse);
    expect(instance.preferences['addSeriesSearchForCutoffUnmet'], isFalse);
  });
}
