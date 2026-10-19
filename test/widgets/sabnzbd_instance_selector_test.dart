import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/widgets/ui/appbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> translations;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : true,
        );
    await EasyLocalization.ensureInitialized();
    translations =
        jsonDecode(await rootBundle.loadString('assets/localization/en.json'))
            as Map<String, dynamic>;
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          null,
        );
  });

  for (final module in [LunaModule.SONARR, LunaModule.RADARR]) {
    testWidgets('${module.name} retains its default selector behavior', (
      tester,
    ) async {
      final selections = <String>[];
      final instances = [
        for (final id in ['primary', 'secondary'])
          LunaServiceInstance(
            id: id,
            profileId: 'default',
            module: module,
            displayName: id,
            enabled: true,
            host: 'https://$id.example/',
            apiKey: '$id-key',
          ),
      ];
      for (final count in [0, 1, 2]) {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en')],
            path: 'assets/localization',
            startLocale: const Locale('en'),
            fallbackLocale: const Locale('en'),
            saveLocale: false,
            assetLoader: _Translations(translations),
            child: Builder(
              builder: (context) => MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: Scaffold(
                  appBar: LunaAppBar.instanceFilter(
                    title: module.title,
                    instances: instances.take(count).toList(),
                    onInstanceSelected: selections.add,
                    useDrawer: false,
                    hideLeading: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (count < 2) {
          expect(find.byTooltip('Switch Instance'), findsNothing);
          continue;
        }

        await tester.tap(find.byTooltip('Switch Instance'));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(selections, isEmpty);

        await tester.tap(find.byTooltip('Switch Instance'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('All Instances'));
        await tester.pumpAndSettle();
        expect(selections, isEmpty);

        await tester.tap(find.byTooltip('Switch Instance'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('secondary'));
        await tester.pumpAndSettle();
        expect(selections, ['secondary']);

        await tester.tap(find.byTooltip('Switch Instance'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('secondary'));
        await tester.pumpAndSettle();
        expect(selections, ['secondary', 'secondary']);
      }
    });
  }
}

class _Translations extends AssetLoader {
  final Map<String, dynamic> translations;

  const _Translations(this.translations);

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      translations;
}
