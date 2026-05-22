import 'package:cloud_firestore/cloud_firestore.dart';

import 'message.dart';

class MessageSearchResult {
  final Message message;
  final String query;
  final String snippet;
  final int matchStart;
  final int matchEnd;
  final DocumentSnapshot<Map<String, dynamic>> snapshot;

  const MessageSearchResult({
    required this.message,
    required this.query,
    required this.snippet,
    required this.matchStart,
    required this.matchEnd,
    required this.snapshot,
  });
}

class MessageSearchPage {
  final List<MessageSearchResult> results;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const MessageSearchPage({
    required this.results,
    required this.lastDocument,
    required this.hasMore,
  });
}
