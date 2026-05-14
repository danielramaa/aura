import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/anonymous_identity.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/identity_service.dart';

class ChatController extends ChangeNotifier {
  static const int maxMessageLength = 2000;

  final String groupId;
  final FirebaseFirestore _firestore;
  final IdentityService _identityService;
  final FirebaseAuth _auth;

  late final ChatServiceInterface _chatService;
  late final String _userId;
  AnonymousIdentity? _anonymousIdentity;
  String? _groupName;

  List<Message> _messages = [];
  List<String> _roomNicknames = [];
  StreamSubscription? _messagesSubscription;

  bool _isDisposed = false;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  Timer? _typingTimer;
  bool _isTyping = false;
  late final Stream<List<String>> typingNamesStream;

  // Maps messageId → the emoji that failed, so retry knows what to re-send.
  final Map<String, String> _reactionErrors = {};
  final Set<String> _reactionRetrying = {};

  ChatController({
    required this.groupId,
    FirebaseFirestore? firestore,
    IdentityService? identityService,
    FirebaseAuth? auth,
    ChatServiceInterface? chatService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _identityService = identityService ?? IdentityService(),
       _auth = auth ?? FirebaseAuth.instance {
    _chatService = chatService ?? ChatService(firestore: _firestore);
    typingNamesStream = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('typing')
        .snapshots()
        .map(_toTypingNames);

    final user = _auth.currentUser;
    if (user != null) {
      _userId = user.uid;
      _initialize();
    } else {
      _error = "Sessão expirada. Por favor, volta a iniciar sessão.";
      _isLoading = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  List<Message> get messages => _messages;
  List<String> get roomNicknames => _roomNicknames;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  AnonymousIdentity? get anonymousIdentity => _anonymousIdentity;

  bool hasReactionError(String messageId) =>
      _reactionErrors.containsKey(messageId);
  bool isRetryingReaction(String messageId) =>
      _reactionRetrying.contains(messageId);

  // ---------------------------------------------------------------------------
  // Typing
  // ---------------------------------------------------------------------------

  List<String> _toTypingNames(QuerySnapshot<Map<String, dynamic>> snap) {
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(seconds: 10)),
    );
    return snap.docs
        .where((d) => d.id != _anonymousIdentity?.anonymousId)
        .where((d) {
          final ts = d.data()['timestamp'] as Timestamp?;
          return ts != null && ts.compareTo(cutoff) >= 0;
        })
        .map((d) => d.data()['nickname'] as String)
        .toList();
  }

  void notifyTyping() {
    if (_anonymousIdentity == null || _isDisposed) return;

    if (!_isTyping) {
      _isTyping = true;
      unawaited(
        _firestore
            .collection('groups')
            .doc(groupId)
            .collection('typing')
            .doc(_anonymousIdentity!.anonymousId)
            .set({
              'nickname': _anonymousIdentity!.nickname,
              'timestamp': FieldValue.serverTimestamp(),
            }),
      );
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), _clearTypingStatus);
  }

  void _clearTypingStatus() {
    _isTyping = false;
    if (_anonymousIdentity == null) return;
    unawaited(
      _firestore
          .collection('groups')
          .doc(groupId)
          .collection('typing')
          .doc(_anonymousIdentity!.anonymousId)
          .delete(),
    );
  }

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

  Future<void> _initialize() async {
    try {
      _anonymousIdentity = await _identityService.getOrCreateIdentity(
        _userId,
        groupId,
      );

      if (_isDisposed) return;

      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      _groupName = groupDoc.data()?['name'] as String? ?? 'Community';

      if (_isDisposed) return;

      // Fire-and-forget: nicknames are refreshed lazily on each @ trigger,
      // so there's no need to block the message stream on this read.
      unawaited(_loadRoomNicknames());

      _messagesSubscription = _chatService
          .streamMessages(groupId)
          .listen(
            (messages) {
              if (_isDisposed) return;
              _messages = messages;
              _isLoading = false;
              notifyListeners();
            },
            onError: (e) {
              if (_isDisposed) return;
              _error = "Não foi possível carregar as mensagens.";
              _isLoading = false;
              notifyListeners();
            },
          );
    } catch (e) {
      if (_isDisposed) return;
      _error = "Não foi possível inicializar o chat.";
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reloads the nickname list from Firestore so recently joined members
  /// appear in autocomplete suggestions.
  Future<void> refreshRoomNicknames() async {
    await _loadRoomNicknames();
    if (!_isDisposed) notifyListeners();
  }

  Future<void> _loadRoomNicknames() async {
    try {
      final snap = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('takenNicknames')
          .get();

      _roomNicknames = snap.docs
          .map((d) => d.id)
          .where((n) => n != _anonymousIdentity?.nickname)
          .toList();
    } catch (e) {
      debugPrint('Failed to load room nicknames: $e');
      _roomNicknames = [];
    }
  }

  // ---------------------------------------------------------------------------
  // Send
  // ---------------------------------------------------------------------------

  List<String> _extractMentions(String text) {
    final regex = RegExp(r'@(\w+)');
    return regex
        .allMatches(text)
        .map((m) => m.group(1)!)
        .where((nickname) => _roomNicknames.contains(nickname))
        .toList();
  }

  Future<void> leaveGroup() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('Not authenticated');
    await _identityService.leaveGroup(userId, groupId);
  }

  Future<void> send(String text, {String? replyToText}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending || _anonymousIdentity == null) return;
    if (trimmed.length > maxMessageLength) {
      _error = 'A mensagem não pode exceder $maxMessageLength caracteres.';
      notifyListeners();
      return;
    }

    _clearTypingStatus();
    _isSending = true;
    notifyListeners();

    try {
      final mentions = _extractMentions(trimmed);

      final sendError = await _chatService.sendMessage(
        groupId: groupId,
        text: trimmed,
        identity: _anonymousIdentity!,
        replyToText: replyToText,
        mentions: mentions,
      );
      if (sendError != null) {
        _error = sendError;
      } else {
        _error = null;
        unawaited(_createNotification(mentions: mentions));
      }
    } catch (_) {
      _error = "Não foi possível enviar a mensagem.";
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Reactions
  // ---------------------------------------------------------------------------

  Future<void> toggleReaction(String messageId, String emoji) async {
    final identity = _anonymousIdentity;
    if (identity == null) return;

    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final message = _messages[idx];

    final existingEmoji = message.userReaction(identity.anonymousId);
    final isRemoving = existingEmoji == emoji;

    _reactionErrors.remove(messageId);
    notifyListeners();

    String? err;
    if (isRemoving) {
      err = await _chatService.removeReaction(
        groupId: groupId,
        messageId: messageId,
        emoji: emoji,
        anonymousId: identity.anonymousId,
      );
    } else {
      err = await _chatService.addReaction(
        groupId: groupId,
        messageId: messageId,
        emoji: emoji,
        anonymousId: identity.anonymousId,
      );
    }

    if (_isDisposed) return;

    if (err != null) {
      _reactionErrors[messageId] = emoji;
    }
    notifyListeners();
  }

  Future<void> retryReaction(String messageId) async {
    final emoji = _reactionErrors[messageId];
    if (emoji == null) return;

    _reactionErrors.remove(messageId);
    _reactionRetrying.add(messageId);
    notifyListeners();

    await toggleReaction(messageId, emoji);

    _reactionRetrying.remove(messageId);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  Future<void> _createNotification({List<String> mentions = const []}) async {
    try {
      final groupName = _groupName ?? 'Community';

      await _firestore.collection('notifications').add({
        'groupId': groupId,
        'groupName': groupName,
        'description': 'Nova mensagem no grupo "$groupName".',
        'senderId': _userId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'message',
        'isRead': false,
      });

      for (final nickname in mentions) {
        final identitySnap = await _firestore
            .collection('anonymousIdentities')
            .where('nickname', isEqualTo: nickname)
            .where('groupId', isEqualTo: groupId)
            .limit(1)
            .get();

        if (identitySnap.docs.isEmpty) continue;

        final mentionedUserId =
            identitySnap.docs.first.data()['userId'] as String?;
        if (mentionedUserId == null) continue;

        await _firestore.collection('notifications').add({
          'groupId': groupId,
          'groupName': groupName,
          'description':
              '${_anonymousIdentity!.nickname} mencionou-te em "$groupName".',
          'senderId': _userId,
          'recipientId': mentionedUserId,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'mention',
          'isRead': false,
        });
      }
    } catch (e) {
      debugPrint('Failed to create notification for group "$groupId": $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _typingTimer?.cancel();
    _clearTypingStatus();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
