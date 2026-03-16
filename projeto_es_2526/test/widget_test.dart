import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/main.dart';

void main() {
  testWidgets('Home screen shows my groups title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('My Groups'), findsOneWidget);
  });
}