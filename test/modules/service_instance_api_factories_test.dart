import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/lidarr/core/api.dart';
import 'package:lunasea/modules/lidarr/core/state.dart';
import 'package:lunasea/modules/nzbget/core/api.dart';
import 'package:lunasea/modules/nzbget/core/state.dart';
import 'package:lunasea/modules/sabnzbd/core/api.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';
import 'package:lunasea/system/backend_state.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:provider/provider.dart';

void main() {
  tearDown(LunaBackendState.clear);

  test('LidarrAPI.fromInstance uses instance connection settings', () {
    final api = LidarrAPI.fromInstance(
      LunaServiceInstance(
        id: 'music',
        module: LunaModule.LIDARR,
        enabled: true,
        host: 'https://lidarr.example/',
        apiKey: 'instance-key',
        headers: {'X-Test': 'lidarr'},
      ),
    );

    expect(api.options.baseUrl, 'https://lidarr.example/api/v1/');
    expect(api.options.queryParameters['apikey'], 'instance-key');
    expect(api.options.headers['X-Test'], 'lidarr');
  });

  test('NZBGetAPI.fromInstance uses instance credentials and headers', () {
    final api = NZBGetAPI.fromInstance(
      LunaServiceInstance(
        id: 'downloads',
        module: LunaModule.NZBGET,
        enabled: true,
        host: 'https://nzbget.example/',
        username: 'instance-user',
        password: 'instance-pass',
        headers: {'X-Test': 'nzbget'},
      ),
    );

    expect(
      api.options.baseUrl,
      'https://nzbget.example/instance-user:instance-pass/jsonrpc',
    );
    expect(api.options.headers['X-Test'], 'nzbget');
  });

  test('SABnzbdAPI.fromInstance uses instance connection settings', () {
    final api = SABnzbdAPI.fromInstance(
      LunaServiceInstance(
        id: 'sab',
        module: LunaModule.SABNZBD,
        enabled: true,
        host: 'https://sab.example/',
        apiKey: 'instance-key',
        headers: {'X-Test': 'sabnzbd'},
      ),
    );

    expect(api.options.baseUrl, 'https://sab.example/api');
    expect(api.options.queryParameters['apikey'], 'instance-key');
    expect(api.options.queryParameters['output'], 'json');
    expect(api.options.headers['X-Test'], 'sabnzbd');
  });

  testWidgets('module state APIs prefer selected instances', (tester) async {
    late LidarrAPI lidarrApi;
    late NZBGetAPI nzbgetApi;
    late SABnzbdAPI sabnzbdApi;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ProfilesStore()),
          ChangeNotifierProvider(
            create: (_) => LidarrState(
              instance: LunaServiceInstance(
                id: 'music',
                module: LunaModule.LIDARR,
                enabled: true,
                host: 'https://selected-lidarr.example/',
                apiKey: 'selected-lidarr-key',
              ),
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => NZBGetState(
              instance: LunaServiceInstance(
                id: 'downloads',
                module: LunaModule.NZBGET,
                enabled: true,
                host: 'https://selected-nzbget.example/',
                username: 'selected-user',
                password: 'selected-pass',
              ),
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => SABnzbdState(
              instance: LunaServiceInstance(
                id: 'sab',
                module: LunaModule.SABNZBD,
                enabled: true,
                host: 'https://selected-sab.example/',
                apiKey: 'selected-sab-key',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              lidarrApi = context.read<LidarrState>().api(context);
              nzbgetApi = context.read<NZBGetState>().api(context);
              sabnzbdApi = context.read<SABnzbdState>().api(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(
      lidarrApi.options.baseUrl,
      'https://selected-lidarr.example/api/v1/',
    );
    expect(lidarrApi.options.queryParameters['apikey'], 'selected-lidarr-key');
    expect(
      nzbgetApi.options.baseUrl,
      'https://selected-nzbget.example/selected-user:selected-pass/jsonrpc',
    );
    expect(sabnzbdApi.options.baseUrl, 'https://selected-sab.example/api');
    expect(sabnzbdApi.options.queryParameters['apikey'], 'selected-sab-key');
  });

  testWidgets('module state APIs fall back to active profile instances', (
    tester,
  ) async {
    LunaBackendState.profiles['default'] = LunaProfile(
      serviceInstances: [
        LunaServiceInstance(
          id: 'lidarr',
          module: LunaModule.LIDARR,
          enabled: true,
          host: 'https://fallback-lidarr.example/',
          apiKey: 'fallback-lidarr-key',
        ),
        LunaServiceInstance(
          id: 'nzbget',
          module: LunaModule.NZBGET,
          enabled: true,
          host: 'https://fallback-nzbget.example/',
          username: 'fallback-user',
          password: 'fallback-pass',
        ),
        LunaServiceInstance(
          id: 'sabnzbd',
          module: LunaModule.SABNZBD,
          enabled: true,
          host: 'https://fallback-sab.example/',
          apiKey: 'fallback-sab-key',
        ),
      ],
    );
    late LidarrAPI lidarrApi;
    late NZBGetAPI nzbgetApi;
    late SABnzbdAPI sabnzbdApi;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ProfilesStore()),
          ChangeNotifierProvider(create: (_) => LidarrState()),
          ChangeNotifierProvider(create: (_) => NZBGetState()),
          ChangeNotifierProvider(create: (_) => SABnzbdState()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              lidarrApi = context.read<LidarrState>().api(context);
              nzbgetApi = context.read<NZBGetState>().api(context);
              sabnzbdApi = context.read<SABnzbdState>().api(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(
      lidarrApi.options.baseUrl,
      'https://fallback-lidarr.example/api/v1/',
    );
    expect(lidarrApi.options.queryParameters['apikey'], 'fallback-lidarr-key');
    expect(
      nzbgetApi.options.baseUrl,
      'https://fallback-nzbget.example/fallback-user:fallback-pass/jsonrpc',
    );
    expect(sabnzbdApi.options.baseUrl, 'https://fallback-sab.example/api');
    expect(sabnzbdApi.options.queryParameters['apikey'], 'fallback-sab-key');
  });
}
