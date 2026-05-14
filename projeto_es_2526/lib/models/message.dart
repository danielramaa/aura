import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/avatar_utils.dart';

class Message {
  final String id;
  final String text;
  final String anonymousId;
  final String senderNickname;
  final int senderAvatarIndex;
  final Timestamp timestamp;
  final String? replyToText;
  final List<String> mentions;
  // reactions: { emoji: [anonymousId, ...] }
  final Map<String, List<String>> reactions;

  String get senderAvatarAssetPath =>
      AvatarUtils.assetForIndex(senderAvatarIndex);

  Message({
    required this.id,
    required this.text,
    required this.anonymousId,
    required this.senderNickname,
    required this.senderAvatarIndex,
    required this.timestamp,
    this.replyToText,
    this.mentions = const [],
    this.reactions = const {},
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

    // Fall back to hash-based index for messages sent before this field existed.
    final nickname = data['senderNickname'] as String? ?? '';
    final fallbackIndex =
        nickname.codeUnits.fold(0, (acc, c) => acc + c) % AvatarUtils.count;

    return Message(
      id: doc.id,
      text: data['text'] ?? '',
      anonymousId: data['senderId'] ?? '',
      senderNickname: nickname.isEmpty ? 'Anonymous' : nickname,
      senderAvatarIndex: data['senderAvatarIndex'] as int? ?? fallbackIndex,
      timestamp:
          data['timestamp'] as Timestamp? ??
          data['createdAt'] as Timestamp? ??
          Timestamp.now(),
      replyToText: data['replyToText'] as String?,
      mentions: List<String>.from(data['mentions'] ?? []),
      reactions: parsedReactions,
    );
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
