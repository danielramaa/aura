import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/models/pinned_message.dart';
import 'package:projeto_es_2526/widgets/pinned_messages_banner.dart';

PinnedMessage makePinned(String id, String text) => PinnedMessage(
  messageId: id,
  text: text,
  senderNickname: 'CalmWolf42',
  senderAvatarIndex: 0,
  messageTimestamp: Timestamp.fromDate(DateTime(2026, 5, 1, 14, 30)),
  pinnedAt: Timestamp.fromDate(DateTime(2026, 5, 2)),
);

Future<void> pumpBanner(
  WidgetTester tester, {
  required List<PinnedMessage> pinned,
  bool canUnpin = false,
  void Function(String)? onNavigate,
  void Function(String)? onUnpin,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PinnedMessagesBanner(
          pinnedMessages: pinned,
          canUnpin: canUnpin,
          onNavigate: onNavigate ?? (_) {},
          onUnpin: onUnpin ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PinnedMessagesBanner', () {
    testWidgets('renders nothing when there are no pinned messages', (
      tester,
    ) async {
      await pumpBanner(tester, pinned: []);

      expect(find.byType(InkWell), findsNothing);
      expect(find.textContaining('pinned'), findsNothing);
    });

    testWidgets('shows singular count for one pinned message', (tester) async {
      await pumpBanner(tester, pinned: [makePinned('m1', 'Hello')]);

      expect(find.text('1 pinned message'), findsOneWidget);
    });

    testWidgets('shows plural count for multiple pinned messages', (
      tester,
    ) async {
      await pumpBanner(
        tester,
        pinned: [makePinned('m1', 'First'), makePinned('m2', 'Second')],
      );

      expect(find.text('2 pinned messages'), findsOneWidget);
    });

    testWidgets('is collapsed by default and expands on header tap', (
      tester,
    ) async {
      await pumpBanner(
        tester,
        pinned: [makePinned('m1', 'First pinned'), makePinned('m2', 'Second pinned')],
      );

      // Collapsed: the list (and the second item) is not built.
      expect(find.text('Second pinned'), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      await tester.tap(find.text('2 pinned messages'));
      await tester.pumpAndSettle();

      // Expanded: items are visible and the chevron flips.
      expect(find.text('Second pinned'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      // Tapping again collapses.
      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pumpAndSettle();
      expect(find.text('Second pinned'), findsNothing);
    });

    testWidgets('onNavigate fires with the tapped message id', (tester) async {
      final navigated = <String>[];
      await pumpBanner(
        tester,
        pinned: [makePinned('m1', 'First pinned'), makePinned('m2', 'Second pinned')],
        onNavigate: navigated.add,
      );

      await tester.tap(find.text('2 pinned messages'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Second pinned'));
      await tester.pumpAndSettle();

      expect(navigated, ['m2']);
    });

    testWidgets('no unpin button is shown when canUnpin is false', (
      tester,
    ) async {
      await pumpBanner(
        tester,
        pinned: [makePinned('m1', 'First pinned')],
        canUnpin: false,
      );

      await tester.tap(find.text('1 pinned message'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
    });

    testWidgets('onUnpin fires with the message id when canUnpin is true', (
      tester,
    ) async {
      final unpinned = <String>[];
      await pumpBanner(
        tester,
        pinned: [makePinned('m1', 'First pinned')],
        canUnpin: true,
        onUnpin: unpinned.add,
      );

      await tester.tap(find.text('1 pinned message'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.push_pin_outlined));
      await tester.pumpAndSettle();

      expect(unpinned, ['m1']);
    });
  });
}
