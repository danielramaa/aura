import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/models/anonymous_identity.dart';
import 'package:projeto_es_2526/models/poll.dart';
import 'package:projeto_es_2526/services/poll_service.dart';

AnonymousIdentity makeIdentity({String id = 'anon-1'}) => AnonymousIdentity(
  anonymousId: id,
  nickname: 'CalmWolf42',
  avatarIndex: 0,
);

/// Seeds a poll document and returns its ID.
Future<String> seedPoll(
  FakeFirebaseFirestore firestore, {
  String groupId = 'g1',
  String creatorId = 'anon-1',
  Timestamp? createdAt,
  Timestamp? closedAt,
  List<Map<String, dynamic>>? options,
}) async {
  final ref =
      firestore.collection('groups').doc(groupId).collection('polls').doc();
  await ref.set({
    'question': 'Favourite colour?',
    'options':
        options ??
        [
          {'text': 'Red', 'voteCount': 0},
          {'text': 'Blue', 'voteCount': 0},
        ],
    'creatorAnonymousId': creatorId,
    'createdAt': createdAt ?? Timestamp.now(),
    'closedAt': closedAt,
  });
  return ref.id;
}

void main() {
  // ---------------------------------------------------------------------------
  // Poll model
  // ---------------------------------------------------------------------------

  group('Poll.fromFirestore', () {
    test('parses all fields', () async {
      final firestore = FakeFirebaseFirestore();
      final ts = Timestamp.fromDate(DateTime(2026, 4, 24));
      final pollId = await seedPoll(firestore, createdAt: ts);

      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('polls')
          .doc(pollId)
          .get();
      final poll = Poll.fromFirestore(doc);

      expect(poll.id, pollId);
      expect(poll.question, 'Favourite colour?');
      expect(poll.options.length, 2);
      expect(poll.options.first.text, 'Red');
      expect(poll.options.first.voteCount, 0);
      expect(poll.creatorAnonymousId, 'anon-1');
      expect(poll.createdAt, ts);
      expect(poll.closedAt, isNull);
    });

    test('parses closedAt when set', () async {
      final firestore = FakeFirebaseFirestore();
      final closed = Timestamp.fromDate(DateTime(2026, 5, 1));
      final pollId = await seedPoll(firestore, closedAt: closed);

      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('polls')
          .doc(pollId)
          .get();
      final poll = Poll.fromFirestore(doc);

      expect(poll.closedAt, closed);
    });
  });

  group('Poll.isOpen', () {
    test('is true when closedAt is null and within 24 hours', () {
      final poll = Poll(
        id: 'p1',
        question: 'Q?',
        options: const [PollOption(text: 'A'), PollOption(text: 'B')],
        creatorAnonymousId: 'anon-1',
        createdAt: Timestamp.now(),
      );
      expect(poll.isOpen, isTrue);
    });

    test('is false when closedAt is set', () {
      final poll = Poll(
        id: 'p1',
        question: 'Q?',
        options: const [PollOption(text: 'A'), PollOption(text: 'B')],
        creatorAnonymousId: 'anon-1',
        createdAt: Timestamp.now(),
        closedAt: Timestamp.now(),
      );
      expect(poll.isOpen, isFalse);
    });

    test('is false when 24 hours have elapsed', () {
      final poll = Poll(
        id: 'p1',
        question: 'Q?',
        options: const [PollOption(text: 'A'), PollOption(text: 'B')],
        creatorAnonymousId: 'anon-1',
        createdAt: Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 25)),
        ),
      );
      expect(poll.isOpen, isFalse);
    });
  });

  group('Poll.totalVotes', () {
    test('sums all option vote counts', () {
      final poll = Poll(
        id: 'p1',
        question: 'Q?',
        options: const [
          PollOption(text: 'A', voteCount: 3),
          PollOption(text: 'B', voteCount: 7),
        ],
        creatorAnonymousId: 'anon-1',
        createdAt: Timestamp.now(),
      );
      expect(poll.totalVotes, 10);
    });

    test('returns 0 when no votes cast', () {
      final poll = Poll(
        id: 'p1',
        question: 'Q?',
        options: const [PollOption(text: 'A'), PollOption(text: 'B')],
        creatorAnonymousId: 'anon-1',
        createdAt: Timestamp.now(),
      );
      expect(poll.totalVotes, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // PollService.createPoll — validation
  // ---------------------------------------------------------------------------

  group('PollService.createPoll — validation', () {
    late FakeFirebaseFirestore firestore;
    late PollService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = PollService(firestore: firestore);
    });

    Future<int> pollCount() async {
      final snap = await firestore
          .collection('groups')
          .doc('g1')
          .collection('polls')
          .get();
      return snap.docs.length;
    }

    test('returns error for empty question', () async {
      final err = await service.createPoll(
        groupId: 'g1',
        question: '   ',
        optionTexts: ['A', 'B'],
        identity: makeIdentity(),
      );
      expect(err, isNotNull);
      expect(await pollCount(), 0);
    });

    test('returns error when fewer than 2 options', () async {
      final err = await service.createPoll(
        groupId: 'g1',
        question: 'Q?',
        optionTexts: ['Only one'],
        identity: makeIdentity(),
      );
      expect(err, isNotNull);
      expect(await pollCount(), 0);
    });

    test('returns error when more than 6 options', () async {
      final err = await service.createPoll(
        groupId: 'g1',
        question: 'Q?',
        optionTexts: ['A', 'B', 'C', 'D', 'E', 'F', 'G'],
        identity: makeIdentity(),
      );
      expect(err, isNotNull);
      expect(await pollCount(), 0);
    });

    test('returns error when any option text is blank', () async {
      final err = await service.createPoll(
        groupId: 'g1',
        question: 'Q?',
        optionTexts: ['A', '  '],
        identity: makeIdentity(),
      );
      expect(err, isNotNull);
      expect(await pollCount(), 0);
    });
  });

  // ---------------------------------------------------------------------------
  // PollService.createPoll — success
  // ---------------------------------------------------------------------------

  group('PollService.createPoll — success', () {
    late FakeFirebaseFirestore firestore;
    late PollService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = PollService(firestore: firestore);
    });

    Future<Map<String, dynamic>?> firstPoll() async {
      final snap = await firestore
          .collection('groups')
          .doc('g1')
          .collection('polls')
          .get();
      return snap.docs.isEmpty ? null : snap.docs.first.data();
    }

    Future<int> messageCount() async {
      final snap = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .get();
      return snap.docs.length;
    }

    test('returns null on success', () async {
      final err = await service.createPoll(
        groupId: 'g1',
        question: 'Best OS?',
        optionTexts: ['Linux', 'macOS'],
        identity: makeIdentity(),
      );
      expect(err, isNull);
    });

    test('writes poll document with correct fields', () async {
      await service.createPoll(
        groupId: 'g1',
        question: '  Best OS?  ',
        optionTexts: ['  Linux  ', 'macOS'],
        identity: makeIdentity(),
      );

      final poll = await firstPoll();
      expect(poll, isNotNull);
      expect(poll!['question'], 'Best OS?');
      expect(poll['creatorAnonymousId'], 'anon-1');
      expect(poll['closedAt'], isNull);

      final opts = List<Map<String, dynamic>>.from(
        (poll['options'] as List).map((o) => Map<String, dynamic>.from(o as Map)),
      );
      expect(opts.length, 2);
      expect(opts[0]['text'], 'Linux');
      expect(opts[0]['voteCount'], 0);
      expect(opts[1]['text'], 'macOS');
    });

    test('creates a poll message in the messages collection', () async {
      await service.createPoll(
        groupId: 'g1',
        question: 'Q?',
        optionTexts: ['A', 'B'],
        identity: makeIdentity(),
      );

      expect(await messageCount(), 1);

      final msgSnap = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .get();
      final msg = msgSnap.docs.first.data();
      expect(msg['type'], 'poll');
      expect(msg['text'], '');
      expect(msg['senderId'], 'anon-1');
      expect(msg['pollId'], isNotNull);
    });

    test('poll message pollId matches the created poll document', () async {
      await service.createPoll(
        groupId: 'g1',
        question: 'Q?',
        optionTexts: ['A', 'B'],
        identity: makeIdentity(),
      );

      final pollSnap = await firestore
          .collection('groups')
          .doc('g1')
          .collection('polls')
          .get();
      final msgSnap = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .get();

      expect(msgSnap.docs.first.data()['pollId'], pollSnap.docs.first.id);
    });
  });

  // ---------------------------------------------------------------------------
  // PollService.vote
  // ---------------------------------------------------------------------------

  group('PollService.vote — success', () {
    late FakeFirebaseFirestore firestore;
    late PollService service;
    late String pollId;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = PollService(firestore: firestore);
      pollId = await seedPoll(firestore);
    });

    Future<Map<String, dynamic>> pollData() async {
      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('polls')
          .doc(pollId)
          .get();
      return doc.data()!;
    }

    test('returns null on success', () async {
      final err = await service.vote(
        groupId: 'g1',
        pollId: pollId,
        optionIndex: 0,
        anonymousId: 'anon-1',
      );
      expect(err, isNull);
    });

    test('increments vote count for the chosen option', () async {
      await service.vote(
        groupId: 'g1',
        pollId: pollId,
        optionIndex: 1,
        anonymousId: 'anon-1',
      );

      final data = await pollData();
      final opts = List<Map<String, dynamic>>.from(
        (data['options'] as List).map((o) => Map<String, dynamic>.from(o as Map)),
      );
      expect(opts[0]['voteCount'], 0);
      expect(opts[1]['voteCount'], 1);
    });

    test('creates a vote document for the user', () async {
      await service.vote(
        groupId: 'g1',
        pollId: pollId,
        optionIndex: 0,
        anonymousId: 'anon-1',
      );

      final voteDoc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('polls')
          .doc(pollId)
          .collection('votes')
          .doc('anon-1')
          .get();

      expect(voteDoc.exists, isTrue);
      expect(voteDoc.data()!['optionIndex'], 0);
    });

    test('multiple users can vote independently', () async {
      await service.vote(
        groupId: 'g1',
        pollId: pollId,
        optionIndex: 0,
        anonymousId: 'anon-1',
      );
      await service.vote(
        groupId: 'g1',
        pollId: pollId,
        optionIndex: 1,
        anonymousId: 'anon-2',
      );

      final data = await pollData();
      final opts = List<Map<String, dynamic>>.from(
        (data['options'] as List).map((o) => Map<String, dynamic>.from(o as Map)),
      );
      expect(opts[0]['voteCount'], 1);
      expect(opts[1]['voteCount'], 1);
    });
  });

  group('PollService.vote — error cases', () {
    late FakeFirebaseFirestore firestore;
    late PollService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = PollService(firestore: firestore);
    });

    test('returns error when poll does not exist', () async {
      final err = await service.vote(
        groupId: 'g1',
        pollId: 'nonexistent',
        optionIndex: 0,
        anonymousId: 'anon-1',
      );
      expect(err, isNotNull);
    });

    test('returns error when poll is manually closed', () async {
      final pollId = await seedPoll(
        firestore,
        closedAt: Timestamp.now(),
      );

      final err = await service.vote(
        groupId: 'g1',
        pollId: pollId,
        optionIndex: 0,
        anonymousId: 'anon-1',
      );
      expect(err, isNotNull);
    });

    test('returns error when poll has expired (>24h)', () async {
      final pollId = await seedPoll(
        firestore,
        createdAt: Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 25)),
        ),
      );

      final err = await service.vote(
        groupId: 'g1',
        pollId: pollId,
        optionIndex: 0,
        anonymousId: 'anon-1',
      );
      expect(err, isNotNull);
    });

    test('returns error when user has already voted', () async {
      final pollId = await seedPoll(firestore);

      await service.vote(
        groupId: 'g1',
        pollId: pollId,
        optionIndex: 0,
        anonymousId: 'anon-1',
      );

      final err = await service.vote(
        groupId: 'g1',
        pollId: pollId,
        optionIndex: 1,
        anonymousId: 'anon-1',
      );
      expect(err, isNotNull);
    });

    test('second vote does not change the vote count', () async {
      final pollId = await seedPoll(firestore);

      await service.vote(
        groupId: 'g1',
        pollId: pollId,
        optionIndex: 0,
        anonymousId: 'anon-1',
      );
      await service.vote(
        groupId: 'g1',
        pollId: pollId,
        optionIndex: 1,
        anonymousId: 'anon-1',
      );

      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('polls')
          .doc(pollId)
          .get();
      final opts = List<Map<String, dynamic>>.from(
        (doc.data()!['options'] as List).map(
          (o) => Map<String, dynamic>.from(o as Map),
        ),
      );
      expect(opts[0]['voteCount'], 1);
      expect(opts[1]['voteCount'], 0);
    });
  });

  // ---------------------------------------------------------------------------
  // PollService.closePoll
  // ---------------------------------------------------------------------------

  group('PollService.closePoll', () {
    late FakeFirebaseFirestore firestore;
    late PollService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = PollService(firestore: firestore);
    });

    test('sets closedAt when called by the creator', () async {
      final pollId = await seedPoll(firestore, creatorId: 'anon-1');

      final err = await service.closePoll(
        groupId: 'g1',
        pollId: pollId,
        anonymousId: 'anon-1',
      );

      expect(err, isNull);
      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('polls')
          .doc(pollId)
          .get();
      expect(doc.data()!['closedAt'], isNotNull);
    });

    test('returns error when caller is not the creator', () async {
      final pollId = await seedPoll(firestore, creatorId: 'anon-1');

      final err = await service.closePoll(
        groupId: 'g1',
        pollId: pollId,
        anonymousId: 'anon-999',
      );
      expect(err, isNotNull);
    });

    test('returns error when poll does not exist', () async {
      final err = await service.closePoll(
        groupId: 'g1',
        pollId: 'nonexistent',
        anonymousId: 'anon-1',
      );
      expect(err, isNotNull);
    });

    test('poll isOpen becomes false after closing', () async {
      final pollId = await seedPoll(firestore, creatorId: 'anon-1');

      await service.closePoll(
        groupId: 'g1',
        pollId: pollId,
        anonymousId: 'anon-1',
      );

      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('polls')
          .doc(pollId)
          .get();
      final poll = Poll.fromFirestore(doc);
      expect(poll.isOpen, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // PollService.streamPoll
  // ---------------------------------------------------------------------------

  group('PollService.streamPoll', () {
    test('emits the poll from Firestore', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PollService(firestore: firestore);
      final pollId = await seedPoll(firestore);

      final poll = await service.streamPoll('g1', pollId).first;
      expect(poll.id, pollId);
      expect(poll.question, 'Favourite colour?');
      expect(poll.options.length, 2);
    });

    test('emits poll with non-zero vote counts when pre-seeded', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PollService(firestore: firestore);
      final pollId = await seedPoll(firestore, options: [
        {'text': 'Red', 'voteCount': 5},
        {'text': 'Blue', 'voteCount': 3},
      ]);

      final poll = await service.streamPoll('g1', pollId).first;
      expect(poll.options[0].voteCount, 5);
      expect(poll.options[1].voteCount, 3);
    });
  });

  // ---------------------------------------------------------------------------
  // PollService.streamUserVote
  // ---------------------------------------------------------------------------

  group('PollService.streamUserVote', () {
    test('emits null when user has not voted', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PollService(firestore: firestore);
      final pollId = await seedPoll(firestore);

      final vote = await service.streamUserVote('g1', pollId, 'anon-1').first;
      expect(vote, isNull);
    });

    test('emits the option index when vote document is pre-seeded', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PollService(firestore: firestore);
      final pollId = await seedPoll(firestore);

      // Seed the vote document directly (transaction propagation is tested
      // via the vote group's direct-read assertions).
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('polls')
          .doc(pollId)
          .collection('votes')
          .doc('anon-1')
          .set({'optionIndex': 1});

      final vote = await service.streamUserVote('g1', pollId, 'anon-1').first;
      expect(vote, 1);
    });
  });
}
