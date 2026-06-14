import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/widgets/ui.dart';

void main() {
  testWidgets('semantic row label includes title and body metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LunaBlock(
            title: 'Movie Title',
            body: const [
              TextSpan(text: '1080p'),
              TextSpan(text: '1.2 GB'),
            ],
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Movie Title\n1080p\n1.2 GB'), findsOneWidget);
  });
}
