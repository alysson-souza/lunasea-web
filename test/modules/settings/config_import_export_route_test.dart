import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/modules/settings/routes/settings/route.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('settings home exposes configuration import and export', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ProfilesStore()),
          ChangeNotifierProvider(create: (_) => SettingsStore()),
          ChangeNotifierProvider(create: (_) => IndexersStore()),
          ChangeNotifierProvider(create: (_) => ExternalModulesStore()),
        ],
        child: const MaterialApp(home: SettingsRoute()),
      ),
    );

    expect(find.text('settings.ImportExportConfiguration'), findsOneWidget);
    expect(find.byIcon(Icons.import_export_rounded), findsOneWidget);
  });
}
