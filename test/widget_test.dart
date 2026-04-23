import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recording/main.dart';

void main() {
  testWidgets('Demo page renders empty state initially', (tester) async {
    await tester.pumpWidget(const VoiceRecorderDemoApp());
    await tester.pump();

    expect(find.text('Voice Recorder'), findsOneWidget);
    expect(find.text('Hali ovozli xabar yo\'q'), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });
}
