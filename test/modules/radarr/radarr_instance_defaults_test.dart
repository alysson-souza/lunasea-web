import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/radarr.dart';

void main() {
  test('add movie details reads defaults from its service instance', () {
    final instance = LunaServiceInstance(
      id: 'radarr-main',
      module: LunaModule.RADARR,
      preferences: {
        'addMovieDefaultRootFolderId': 2,
        'addMovieDefaultQualityProfileId': 20,
        'addMovieDefaultTags': [100, 300],
      },
    );
    final state = RadarrAddMovieDetailsState(
      movie: RadarrMovie(title: 'Example Movie'),
      isDiscovery: false,
      instance: instance,
    );

    state.initializeRootFolder([
      RadarrRootFolder(id: 1, path: '/movies/one'),
      RadarrRootFolder(id: 2, path: '/movies/two'),
    ]);
    state.initializeQualityProfile([
      RadarrQualityProfile(id: 10, name: 'HD'),
      RadarrQualityProfile(id: 20, name: 'UHD'),
    ]);
    state.initializeTags([
      RadarrTag(id: 100, label: 'favorite'),
      RadarrTag(id: 200, label: 'skip'),
      RadarrTag(id: 300, label: 'archive'),
    ]);

    expect(state.rootFolder.id, 2);
    expect(state.qualityProfile.id, 20);
    expect(state.tags.map((tag) => tag.id), [100, 300]);
  });
}
