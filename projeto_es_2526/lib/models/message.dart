import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  poll,
}

MessageType messageTypeFromString(String type) {
  switch (type) {
    case 'poll':
      return MessageType.poll;
    case 'text':
    default:
      return MessageType.text;
  }
}

String messageTypeToString(MessageType type) {
  switch (type) {
    case MessageType.poll:
      return 'poll';
    case MessageType.text:
      return 'text';
  }
}

class PollOption {
  final String id;
  final String text;
  final int votes;

  PollOption({
    required this.id,
    required this.text,
    required this.votes,
  });

  factory PollOption.fromMap(Map<String, dynamic> map) {
    return PollOption(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      votes: map['votes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'votes': votes,
    };
  }
}

class PollData {
  final String question;
  final List<PollOption> options;
  final bool isClosed;
  final Timestamp expiresAt;
  final List<String> voterIds;

  PollData({
    required this.question,
    required this.options,
    required this.isClosed,
    required this.expiresAt,
    required this.voterIds,
  });

  factory PollData.fromMap(Map<String, dynamic> map) {
    return PollData(
      question: map['question'] ?? '',
      options: (map['options'] as List<dynamic>? ?? [])
          .map((o) => PollOption.fromMap(Map<String, dynamic>.from(o)))
          .toList(),
      isClosed: map['isClosed'] ?? false,
      expiresAt: map['expiresAt'] as Timestamp? ?? Timestamp.now(),
      voterIds: List<String>.from(map['voterIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options.map((o) => o.toMap()).toList(),
      'isClosed': isClosed,
      'expiresAt': expiresAt,
      'voterIds': voterIds,
    };
  }

  bool get hasExpired => DateTime.now().isAfter(expiresAt.toDate());
}

class Message {
  final String id;
  final String text;
  final String anonymousId;
  final String senderNickname;
  final Timestamp timestamp;
  final String? replyToText;
  final List<String> mentions;

  // reactions: { emoji: [anonymousId, ...] }
  final Map<String, List<String>> reactions;

  // NEW
  final MessageType type;
  final PollData? pollData;

  Message({
    required this.id,
    required this.text,
    required this.anonymousId,
    required this.senderNickname,
    required this.timestamp,
    this.replyToText,
    this.mentions = const [],
    this.reactions = const {},
    this.type = MessageType.text,
    this.pollData,
  });

  factory Message.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    Map<String, List<String>> parsedReactions = {};
    if (data['reactions'] != null) {
      final raw = Map<String, dynamic>.from(data['reactions'] as Map);
      raw.forEach((emoji, users) {
        parsedReactions[emoji] = List<String>.from(users as List);
      });
    }

    return Message(
      id: doc.id,
      text: data['text'] ?? '',
      anonymousId: data['senderId'] ?? '',
      senderNickname: data['senderNickname'] ?? 'Anonymous',
      timestamp:
          data['timestamp'] as Timestamp? ??
          data['createdAt'] as Timestamp? ??
          Timestamp.now(),
      replyToText: data['replyToText'] as String?,
      mentions: List<String>.from(data['mentions'] ?? []),
      reactions: parsedReactions,
      type: messageTypeFromString(data['type'] ?? 'text'),
      pollData: data['pollData'] != null
          ? PollData.fromMap(Map<String, dynamic>.from(data['pollData']))
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'senderId': anonymousId,
      'senderNickname': senderNickname,
      'timestamp': timestamp,
      'replyToText': replyToText,
      'mentions': mentions,
      'reactions': reactions,
      'type': messageTypeToString(type),
      'pollData': pollData?.toMap(),
    };
  }

  /// Emoji reacted by [anonymousId], or null if none.
  String? userReaction(String anonymousId) {
    for (final entry in reactions.entries) {
      if (entry.value.contains(anonymousId)) return entry.key;
    }
    return null;
  }

  /// Sorted list of (emoji, count) for display, excluding empty entries.
  List<MapEntry<String, int>> get reactionSummary {
    return reactions.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => MapEntry(e.key, e.value.length))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }
}
