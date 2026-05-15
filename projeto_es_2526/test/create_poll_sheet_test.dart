import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/widgets/create_poll_sheet.dart';

Widget buildSheet({
  required Future<String?> Function(String, List<String>) onPublish,
}) => MaterialApp(
  home: Scaffold(body: CreatePollSheet(onPublish: onPublish)),
);

/// Pumps the sheet and sets a comfortable screen size so all fields are reachable.
Future<void> pumpSheet(
  WidgetTester tester, {
  required Future<String?> Function(String, List<String>) onPublish,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(buildSheet(onPublish: onPublish));
  await tester.pumpAndSettle();
}

// TextFields appear in build order: [0] question, [1] option 1, [2] option 2, …
Finder questionField() => find.byType(TextField).at(0);
Finder optionField(int n) =>
    find.byType(TextField).at(n); // 1-based option → index n

void main() {
  group('CreatePollSheet — validation', () {
    testWidgets('shows error when question is empty and Publish is tapped', (
      tester,
    ) async {
      await pumpSheet(tester, onPublish: (_, opts) async => null);

      await tester.ensureVisible(find.text('Publish Poll'));
      await tester.tap(find.text('Publish Poll'));
      await tester.pumpAndSettle();

      expect(find.text('Question cannot be empty.'), findsOneWidget);
    });

    testWidgets('shows error for each empty option when Publish is tapped', (
      tester,
    ) async {
      await pumpSheet(tester, onPublish: (_, opts) async => null);

      await tester.enterText(questionField(), 'My question?');
      // Leave both option fields empty.
      await tester.ensureVisible(find.text('Publish Poll'));
      await tester.tap(find.text('Publish Poll'));
      await tester.pumpAndSettle();

      expect(find.text('Option cannot be empty.'), findsWidgets);
    });

    testWidgets('does not call onPublish when validation fails', (
      tester,
    ) async {
      var called = false;
      await pumpSheet(
        tester,
        onPublish: (_, opts) async {
          called = true;
          return null;
        },
      );

      await tester.ensureVisible(find.text('Publish Poll'));
      await tester.tap(find.text('Publish Poll'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
    });

    testWidgets('error clears when user starts typing in question field', (
      tester,
    ) async {
      await pumpSheet(tester, onPublish: (_, opts) async => null);

      await tester.ensureVisible(find.text('Publish Poll'));
      await tester.tap(find.text('Publish Poll'));
      await tester.pumpAndSettle();

      expect(find.text('Question cannot be empty.'), findsOneWidget);

      await tester.enterText(questionField(), 'A');
      await tester.pumpAndSettle();

      expect(find.text('Question cannot be empty.'), findsNothing);
    });
  });

  group('CreatePollSheet — option limits', () {
    testWidgets('starts with exactly 2 option fields', (tester) async {
      await pumpSheet(tester, onPublish: (_, opts) async => null);

      // 1 question + 2 options = 3 TextFields total.
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('remove button is hidden when only 2 options exist', (
      tester,
    ) async {
      await pumpSheet(tester, onPublish: (_, opts) async => null);

      expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
    });

    testWidgets('add option button adds a new field', (tester) async {
      await pumpSheet(tester, onPublish: (_, opts) async => null);

      await tester.ensureVisible(find.textContaining('Add option'));
      await tester.tap(find.textContaining('Add option'));
      await tester.pumpAndSettle();

      // Now 1 question + 3 options = 4 TextFields.
      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('remove button appears when more than 2 options exist', (
      tester,
    ) async {
      await pumpSheet(tester, onPublish: (_, opts) async => null);

      await tester.ensureVisible(find.textContaining('Add option'));
      await tester.tap(find.textContaining('Add option'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.remove_circle_outline), findsWidgets);
    });

    testWidgets('add option button is hidden once 6 options are present', (
      tester,
    ) async {
      await pumpSheet(tester, onPublish: (_, opts) async => null);

      for (int i = 0; i < 4; i++) {
        await tester.ensureVisible(find.textContaining('Add option'));
        await tester.tap(find.textContaining('Add option'));
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('Add option'), findsNothing);
      // 1 question + 6 options = 7 TextFields.
      expect(find.byType(TextField), findsNWidgets(7));
    });

    testWidgets('removing an option reduces the field count', (tester) async {
      await pumpSheet(tester, onPublish: (_, opts) async => null);

      await tester.ensureVisible(find.textContaining('Add option'));
      await tester.tap(find.textContaining('Add option'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(4));

      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(3));
    });
  });

  group('CreatePollSheet — publish', () {
    testWidgets('calls onPublish with trimmed question and options', (
      tester,
    ) async {
      String? capturedQuestion;
      List<String>? capturedOptions;

      await pumpSheet(
        tester,
        onPublish: (q, opts) async {
          capturedQuestion = q;
          capturedOptions = opts;
          return null;
        },
      );

      await tester.enterText(questionField(), '  Is Flutter great?  ');
      await tester.enterText(optionField(1), '  Yes  ');
      await tester.enterText(optionField(2), '  No  ');

      await tester.ensureVisible(find.text('Publish Poll'));
      await tester.tap(find.text('Publish Poll'));
      await tester.pumpAndSettle();

      expect(capturedQuestion, 'Is Flutter great?');
      expect(capturedOptions, ['Yes', 'No']);
    });

    testWidgets('shows snackbar when onPublish returns an error', (
      tester,
    ) async {
      await pumpSheet(tester, onPublish: (_, opts) async => 'Network error.');

      await tester.enterText(questionField(), 'A question');
      await tester.enterText(optionField(1), 'Yes');
      await tester.enterText(optionField(2), 'No');

      await tester.ensureVisible(find.text('Publish Poll'));
      await tester.tap(find.text('Publish Poll'));
      await tester.pumpAndSettle();

      expect(find.text('Network error.'), findsOneWidget);
    });
  });
}
