import 'package:cloud_firestore/cloud_firestore.dart';

class PollOption {
  final String text;
  final int voteCount;

  const PollOption({required this.text, this.voteCount = 0});

  Map<String, dynamic> toMap() => {'text': text, 'voteCount': voteCount};

  factory PollOption.fromMap(Map<String, dynamic> map) => PollOption(
    text: map['text'] as String? ?? '',
    voteCount: (map['voteCount'] as num?)?.toInt() ?? 0,
  );
}

class Poll {
  final String id;
  final String question;
  final List<PollOption> options;
  final String creatorAnonymousId;
  final Timestamp createdAt;
  // null means not manually closed yet
  final Timestamp? closedAt;

  const Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.creatorAnonymousId,
    required this.createdAt,
    this.closedAt,
  });

  /// Poll is open when not manually closed and within 24 hours of creation.
  bool get isOpen {
    if (closedAt != null) return false;
    final expiry = createdAt.toDate().add(const Duration(hours: 24));
    return DateTime.now().isBefore(expiry);
  }

  int get totalVotes => options.fold(0, (acc, o) => acc + o.voteCount);

  factory Poll.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawOptions = data['options'] as List<dynamic>? ?? [];
    return Poll(
      id: doc.id,
      question: data['question'] as String? ?? '',
      options: rawOptions
          .map((o) => PollOption.fromMap(Map<String, dynamic>.from(o as Map)))
          .toList(),
      creatorAnonymousId: data['creatorAnonymousId'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      closedAt: data['closedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'question': question,
    'options': options.map((o) => o.toMap()).toList(),
    'creatorAnonymousId': creatorAnonymousId,
    'createdAt': createdAt,
    'closedAt': closedAt,
  };
}
