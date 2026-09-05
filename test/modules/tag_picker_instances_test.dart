import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/radarr.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/system/backend_state.dart';
import 'package:provider/provider.dart';

void main() {
  tearDown(LunaBackendState.clear);

  for (final editing in [false, true]) {
    testWidgets(
      'Sonarr ${editing ? 'edit' : 'add'} tags retain the selected instance',
      (tester) async {
        await _hydrate();
        final first = _SonarrTags('First server tag');
        final selected = _SonarrTags('Selected server tag');
        final add = _SonarrAdd()..tags = [];
        final edit = SonarrSeriesEditState()..tags = [];
        await tester.pumpWidget(
          ChangeNotifierProvider<SonarrState>.value(
            value: first,
            child: MaterialApp(
              home: MultiProvider(
                providers: [
                  ChangeNotifierProvider<SonarrState>.value(value: selected),
                  ChangeNotifierProvider<SonarrSeriesAddDetailsState>.value(
                    value: add,
                  ),
                  ChangeNotifierProvider<SonarrSeriesEditState>.value(
                    value: edit,
                  ),
                ],
                child: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => editing
                          ? SonarrDialogs().setEditTags(context)
                          : SonarrDialogs().setAddTags(context),
                      child: const Text('Open tags'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await _selectTag(tester);
        expect((editing ? edit.tags! : add.tags).map((tag) => tag.label), [
          'Selected server tag',
        ]);
        await tester.pumpWidget(const SizedBox.shrink());
        for (final state in [first, selected, add, edit]) {
          state.dispose();
        }
      },
    );

    testWidgets(
      'Radarr ${editing ? 'edit' : 'add'} tags retain the selected instance',
      (tester) async {
        await _hydrate();
        final first = _RadarrTags('First server tag');
        final selected = _RadarrTags('Selected server tag');
        final add = _RadarrAdd()..tags = [];
        final edit = RadarrMoviesEditState()..tags = [];
        await tester.pumpWidget(
          ChangeNotifierProvider<RadarrState>.value(
            value: first,
            child: MaterialApp(
              home: MultiProvider(
                providers: [
                  ChangeNotifierProvider<RadarrState>.value(value: selected),
                  ChangeNotifierProvider<RadarrAddMovieDetailsState>.value(
                    value: add,
                  ),
                  ChangeNotifierProvider<RadarrMoviesEditState>.value(
                    value: edit,
                  ),
                ],
                child: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => editing
                          ? RadarrDialogs().setEditTags(context)
                          : RadarrDialogs().setAddTags(context),
                      child: const Text('Open tags'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await _selectTag(tester);
        expect((editing ? edit.tags : add.tags).map((tag) => tag.label), [
          'Selected server tag',
        ]);
        await tester.pumpWidget(const SizedBox.shrink());
        for (final state in [first, selected, add, edit]) {
          state.dispose();
        }
      },
    );
  }
}

Future<void> _hydrate() => LunaBackendState.hydrate({
  'preferences': {'activeProfile': 'default', 'drawerManualOrder': []},
  'profiles': [
    {'id': 'default'},
  ],
});

Future<void> _selectTag(WidgetTester tester) async {
  await tester.tap(find.text('Open tags'));
  await tester.pumpAndSettle();
  expect(find.text('Selected server tag'), findsOneWidget);
  expect(find.text('First server tag'), findsNothing);
  await tester.tap(find.text('Selected server tag'));
  await tester.pumpAndSettle();
}

class _SonarrTags extends SonarrState {
  _SonarrTags(String label)
    : values = Future.value([SonarrTag(id: 1, label: label)]);
  final Future<List<SonarrTag>> values;
  @override
  void reset() {}
  @override
  Future<List<SonarrTag>> get tags => values;
}

class _RadarrTags extends RadarrState {
  _RadarrTags(String label)
    : values = Future.value([RadarrTag(id: 1, label: label)]);
  final Future<List<RadarrTag>> values;
  @override
  void reset() {}
  @override
  Future<List<RadarrTag>> get tags => values;
}

// Keep preference writes local; the dialog still uses the real tags setter.
class _SonarrAdd extends SonarrSeriesAddDetailsState {
  _SonarrAdd()
    : super(
        series: SonarrSeries(),
        instance: LunaServiceInstance(
          id: 'selected',
          profileId: 'default',
          module: LunaModule.SONARR,
        ),
      );
  @override
  void setPreference(String key, dynamic value) =>
      instance!.setPreference(key, value);
}

class _RadarrAdd extends RadarrAddMovieDetailsState {
  _RadarrAdd()
    : super(
        movie: RadarrMovie(),
        isDiscovery: false,
        instance: LunaServiceInstance(
          id: 'selected',
          profileId: 'default',
          module: LunaModule.RADARR,
        ),
      );
  @override
  void setPreference(String key, dynamic value) =>
      instance!.setPreference(key, value);
}
