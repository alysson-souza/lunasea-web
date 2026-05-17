import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/dashboard/core/api/api.dart';
import 'package:lunasea/modules/dashboard/core/api/data/lidarr.dart';
import 'package:lunasea/modules/dashboard/core/api/data/radarr.dart';
import 'package:lunasea/modules/dashboard/core/api/data/sonarr.dart';
import 'package:lunasea/system/backend_state.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:provider/provider.dart';

void main() {
  tearDown(LunaBackendState.clear);

  group('dashboard calendar source instances', () {
    test('Radarr calendar data retains source instance details', () {
      const ref = LunaServiceInstanceRef(
        profileId: 'profile-a',
        module: LunaModule.RADARR,
        instanceId: 'radarr-4k',
      );

      final data = CalendarRadarrData(
        id: 1,
        title: 'Movie',
        sourceInstance: 'Radarr 4K',
        sourceRef: ref,
        hasFile: false,
        fileQualityProfile: '',
        year: 2026,
        runtime: 120,
        studio: 'Studio',
        releaseDate: DateTime(2026, 5, 17),
      );

      expect(data.sourceInstance, 'Radarr 4K');
      expect(data.sourceRef.profileId, 'profile-a');
      expect(data.sourceRef.module, LunaModule.RADARR);
      expect(data.sourceRef.instanceId, 'radarr-4k');
    });

    test('Sonarr calendar data retains source instance details', () {
      const ref = LunaServiceInstanceRef(
        profileId: 'profile-a',
        module: LunaModule.SONARR,
        instanceId: 'sonarr-anime',
      );

      final data = CalendarSonarrData(
        id: 2,
        title: 'Series',
        sourceInstance: 'Sonarr Anime',
        sourceRef: ref,
        episodeTitle: 'Episode',
        seasonNumber: 1,
        episodeNumber: 2,
        seriesID: 20,
        airTime: '2026-05-17T12:00:00Z',
        hasFile: true,
        fileQualityProfile: 'HDTV-1080p',
      );

      expect(data.sourceInstance, 'Sonarr Anime');
      expect(data.sourceRef.profileId, 'profile-a');
      expect(data.sourceRef.module, LunaModule.SONARR);
      expect(data.sourceRef.instanceId, 'sonarr-anime');
    });

    test('Lidarr calendar data retains source instance details', () {
      const ref = LunaServiceInstanceRef(
        profileId: 'profile-a',
        module: LunaModule.LIDARR,
        instanceId: 'lidarr-lossless',
      );

      final data = CalendarLidarrData(
        id: 3,
        title: 'Artist',
        sourceInstance: 'Lidarr Lossless',
        sourceRef: ref,
        albumTitle: 'Album',
        artistId: 30,
        hasAllFiles: false,
        totalTrackCount: 10,
      );

      expect(data.sourceInstance, 'Lidarr Lossless');
      expect(data.sourceRef.profileId, 'profile-a');
      expect(data.sourceRef.module, LunaModule.LIDARR);
      expect(data.sourceRef.instanceId, 'lidarr-lossless');
    });

    testWidgets('Radarr artwork URLs use the source instance', (tester) async {
      LunaBackendState.profiles['profile-a'] = LunaProfile(
        key: 'profile-a',
        serviceInstances: [
          LunaServiceInstance(
            id: 'radarr-4k',
            profileId: 'profile-a',
            module: LunaModule.RADARR,
            enabled: true,
            host: 'https://radarr-4k.example/',
            apiKey: 'radarr-4k-key',
          ),
        ],
      );

      final data = CalendarRadarrData(
        id: 10,
        title: 'Movie',
        sourceInstance: 'Radarr 4K',
        sourceRef: const LunaServiceInstanceRef(
          profileId: 'profile-a',
          module: LunaModule.RADARR,
          instanceId: 'radarr-4k',
        ),
        hasFile: false,
        fileQualityProfile: '',
        year: 2026,
        runtime: 120,
        studio: 'Studio',
        releaseDate: DateTime(2026, 5, 17),
      );

      await tester.pumpWidget(
        _withProfilesStore((context) {
          expect(
            data.posterUrl(context),
            'https://radarr-4k.example/api/v3/MediaCover/10/poster-500.jpg?apikey=radarr-4k-key',
          );
          expect(
            data.backgroundUrl(context),
            'https://radarr-4k.example/api/v3/MediaCover/10/fanart-360.jpg?apikey=radarr-4k-key',
          );
          return const SizedBox.shrink();
        }),
      );
    });

    testWidgets('Sonarr artwork URLs use the source instance', (tester) async {
      LunaBackendState.profiles['profile-a'] = LunaProfile(
        key: 'profile-a',
        serviceInstances: [
          LunaServiceInstance(
            id: 'sonarr-anime',
            profileId: 'profile-a',
            module: LunaModule.SONARR,
            enabled: true,
            host: 'https://sonarr-anime.example/',
            apiKey: 'sonarr-anime-key',
          ),
        ],
      );

      final data = CalendarSonarrData(
        id: 20,
        title: 'Series',
        sourceInstance: 'Sonarr Anime',
        sourceRef: const LunaServiceInstanceRef(
          profileId: 'profile-a',
          module: LunaModule.SONARR,
          instanceId: 'sonarr-anime',
        ),
        episodeTitle: 'Episode',
        seasonNumber: 1,
        episodeNumber: 2,
        seriesID: 200,
        airTime: '2026-05-17T12:00:00Z',
        hasFile: true,
        fileQualityProfile: 'HDTV-1080p',
      );

      await tester.pumpWidget(
        _withProfilesStore((context) {
          expect(
            data.posterUrl(context),
            'https://sonarr-anime.example/api/v3/MediaCover/200/poster-500.jpg?apikey=sonarr-anime-key',
          );
          expect(
            data.backgroundUrl(context),
            'https://sonarr-anime.example/api/v3/MediaCover/200/fanart-360.jpg?apikey=sonarr-anime-key',
          );
          return const SizedBox.shrink();
        }),
      );
    });

    testWidgets('Lidarr artwork URLs use the source instance', (tester) async {
      LunaBackendState.profiles['profile-a'] = LunaProfile(
        key: 'profile-a',
        serviceInstances: [
          LunaServiceInstance(
            id: 'lidarr-lossless',
            profileId: 'profile-a',
            module: LunaModule.LIDARR,
            enabled: true,
            host: 'https://lidarr-lossless.example/',
            apiKey: 'lidarr-lossless-key',
          ),
        ],
      );

      final data = CalendarLidarrData(
        id: 30,
        title: 'Artist',
        sourceInstance: 'Lidarr Lossless',
        sourceRef: const LunaServiceInstanceRef(
          profileId: 'profile-a',
          module: LunaModule.LIDARR,
          instanceId: 'lidarr-lossless',
        ),
        albumTitle: 'Album',
        artistId: 300,
        hasAllFiles: false,
        totalTrackCount: 10,
      );

      await tester.pumpWidget(
        _withProfilesStore((context) {
          expect(
            data.posterUrl(context),
            'https://lidarr-lossless.example/api/v1/MediaCover/Artist/300/poster-500.jpg?apikey=lidarr-lossless-key',
          );
          expect(
            data.backgroundUrl(context),
            'https://lidarr-lossless.example/api/v1/MediaCover/Artist/300/fanart-360.jpg?apikey=lidarr-lossless-key',
          );
          return const SizedBox.shrink();
        }),
      );
    });

    testWidgets('source artwork returns empty when instance is unavailable', (
      tester,
    ) async {
      LunaBackendState.profiles['profile-a'] = LunaProfile(
        key: 'profile-a',
        serviceInstances: [
          LunaServiceInstance(
            id: 'radarr-disabled',
            profileId: 'profile-a',
            module: LunaModule.RADARR,
            enabled: false,
            host: 'https://radarr-disabled.example/',
            apiKey: 'disabled-key',
          ),
        ],
      );

      final data = CalendarRadarrData(
        id: 10,
        title: 'Movie',
        sourceInstance: 'Radarr Disabled',
        sourceRef: const LunaServiceInstanceRef(
          profileId: 'profile-a',
          module: LunaModule.RADARR,
          instanceId: 'radarr-disabled',
        ),
        hasFile: false,
        fileQualityProfile: '',
        year: 2026,
        runtime: 120,
        studio: 'Studio',
        releaseDate: DateTime(2026, 5, 17),
      );

      await tester.pumpWidget(
        _withProfilesStore((context) {
          expect(data.posterUrl(context), isNull);
          expect(data.backgroundUrl(context), isNull);
          return const SizedBox.shrink();
        }),
      );
    });

    test(
      'getUpcoming stamps parsed entries with each source instance',
      () async {
        final profile = LunaProfile(
          key: 'profile-a',
          serviceInstances: [
            LunaServiceInstance(
              id: 'radarr-4k',
              profileId: 'profile-a',
              module: LunaModule.RADARR,
              displayName: 'Radarr 4K',
              enabled: true,
              host: 'https://radarr-4k.example/',
            ),
            LunaServiceInstance(
              id: 'radarr-hd',
              profileId: 'profile-a',
              module: LunaModule.RADARR,
              displayName: 'Radarr HD',
              enabled: true,
              host: 'https://radarr-hd.example/',
            ),
          ],
        );

        final api = API.test(
          profile: profile,
          radarrCalendarFetcher: (instance, today) async => [
            {
              'id': instance.id == 'radarr-4k' ? 10 : 20,
              'title': instance.displayName,
              'hasFile': false,
              'year': 2026,
              'runtime': 120,
              'studio': 'Studio',
              'digitalRelease': '2026-05-17',
            },
          ],
        );

        final upcoming = await api.getUpcoming(DateTime(2026, 5, 17));
        final entries = upcoming[DateTime(2026, 5, 17)]!;

        expect(entries, hasLength(2));
        expect(
          entries.map((entry) => entry.sourceInstance),
          containsAll(['Radarr 4K', 'Radarr HD']),
        );
        expect(
          entries.map((entry) => entry.sourceRef),
          containsAll([
            const LunaServiceInstanceRef(
              profileId: 'profile-a',
              module: LunaModule.RADARR,
              instanceId: 'radarr-4k',
            ),
            const LunaServiceInstanceRef(
              profileId: 'profile-a',
              module: LunaModule.RADARR,
              instanceId: 'radarr-hd',
            ),
          ]),
        );
      },
    );
  });
}

Widget _withProfilesStore(WidgetBuilder builder) {
  return ChangeNotifierProvider(
    create: (_) => ProfilesStore(),
    child: MaterialApp(home: Builder(builder: builder)),
  );
}
