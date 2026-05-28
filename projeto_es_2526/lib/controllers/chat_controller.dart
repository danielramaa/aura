import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/anonymous_identity.dart';
import '../models/message.dart';
import '../models/message_search_result.dart';
import '../models/pinned_message.dart';
import '../models/user_role.dart';
import '../services/chat_service.dart';
import '../services/identity_service.dart';
import '../services/poll_service.dart';
import '../services/report_service.dart';

class ChatController extends ChangeNotifier {
  static const int maxMessageLength = 2000;

  final String groupId;
  final FirebaseFirestore _firestore;
  final IdentityService _identityService;
  final FirebaseAuth _auth;

  late final ChatServiceInterface _chatService;
  late final PollServiceInterface _pollService;
  late final ReportServiceInterface _reportService;
  late final String _userId;
  AnonymousIdentity? _anonymousIdentity;
  String? _groupName;

  List<Message> _messages = [];
  List<MessageSearchResult> _searchResults = [];
  List<PinnedMessage> _pinnedMessages = [];
  // Mirror of the pinned message ids for O(1) isMessagePinned lookups, which
  // run once per bubble on every list rebuild.
  Set<String> _pinnedMessageIds = {};
  List<String> _roomNicknames = [];
  Set<String> _medicAnonymousIds = {};
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _pinnedMessagesSubscription;
  StreamSubscription? _medicSub;

  bool _isDisposed = false;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isSearchingMessages = false;
  bool _hasMoreSearchResults = false;
  String? _error;
  String? _searchError;
  String _messageSearchQuery = '';
  DocumentSnapshot<Map<String, dynamic>>? _lastSearchDocument;

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
    PollServiceInterface? pollService,
    ReportServiceInterface? reportService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _identityService = identityService ?? IdentityService(),
       _auth = auth ?? FirebaseAuth.instance {
    _chatService = chatService ?? ChatService(firestore: _firestore);
    _pollService = pollService ?? PollService(firestore: _firestore);
    _reportService = reportService ?? ReportService(firestore: _firestore);
    typingNamesStream = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('typing')
        .snapshots()
        .map(_toTypingNames);

    _medicSub = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('medicAnonymousIds')
        .snapshots()
        .listen((snap) {
          if (!_isDisposed) {
            _medicAnonymousIds = snap.docs.map((d) => d.id).toSet();
            notifyListeners();
          }
        });

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
  List<MessageSearchResult> get searchResults => _searchResults;
  List<PinnedMessage> get pinnedMessages => _pinnedMessages;
  List<String> get roomNicknames => _roomNicknames;
  Set<String> get medicAnonymousIds => _medicAnonymousIds;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get isSearchingMessages => _isSearchingMessages;
  bool get hasMoreSearchResults => _hasMoreSearchResults;
  String? get error => _error;
  String? get searchError => _searchError;
  String get messageSearchQuery => _messageSearchQuery;
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

      _pinnedMessagesSubscription = _chatService
          .streamPinnedMessages(groupId)
          .listen(
            (pinned) {
              if (_isDisposed) return;
              _pinnedMessages = pinned;
              _pinnedMessageIds = pinned.map((p) => p.messageId).toSet();
              notifyListeners();
            },
            onError: (e) {
              if (_isDisposed) return;
              _error = "Não foi possível carregar as mensagens fixadas.";
              _pinnedMessages = [];
              _pinnedMessageIds = {};
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

  // ---------------------------------------------------------------------------
  // Message search
  // ---------------------------------------------------------------------------

  Future<void> searchMessages(String query) async {
    final trimmed = query.trim();
    _messageSearchQuery = trimmed;
    _searchResults = [];
    _lastSearchDocument = null;
    _hasMoreSearchResults = false;
    _searchError = null;

    if (trimmed.isEmpty) {
      _isSearchingMessages = false;
      notifyListeners();
      return;
    }

    _isSearchingMessages = true;
    notifyListeners();

    try {
      final page = await _chatService.searchMessages(
        groupId: groupId,
        query: trimmed,
      );
      if (_isDisposed) return;
      if (_messageSearchQuery != trimmed) return;

      _searchResults = page.results;
      _lastSearchDocument = page.lastDocument;
      _hasMoreSearchResults = page.hasMore;
    } catch (_) {
      if (_isDisposed) return;
      if (_messageSearchQuery != trimmed) return;
      _searchError = 'Não foi possível pesquisar mensagens.';
    } finally {
      if (!_isDisposed && _messageSearchQuery == trimmed) {
        _isSearchingMessages = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreSearchResults() async {
    if (_messageSearchQuery.isEmpty ||
        _isSearchingMessages ||
        !_hasMoreSearchResults) {
      return;
    }

    final query = _messageSearchQuery;
    final startAfter = _lastSearchDocument;

    _isSearchingMessages = true;
    _searchError = null;
    notifyListeners();

    try {
      final page = await _chatService.searchMessages(
        groupId: groupId,
        query: query,
        startAfter: startAfter,
      );
      if (_isDisposed) return;
      if (_messageSearchQuery != query || _messageSearchQuery.isEmpty) return;

      _searchResults = [..._searchResults, ...page.results];
      _lastSearchDocument = page.lastDocument;
      _hasMoreSearchResults = page.hasMore;
    } catch (_) {
      if (_isDisposed) return;
      if (_messageSearchQuery != query) return;
      _searchError = 'Não foi possível carregar mensagens antigas.';
    } finally {
      if (!_isDisposed && _messageSearchQuery == query) {
        _isSearchingMessages = false;
        notifyListeners();
      }
    }
  }

  void clearMessageSearch() {
    _messageSearchQuery = '';
    _searchResults = [];
    _lastSearchDocument = null;
    _hasMoreSearchResults = false;
    _searchError = null;
    _isSearchingMessages = false;
    notifyListeners();
  }

  int indexOfMessage(String messageId) {
    return _messages.indexWhere((message) => message.id == messageId);
  }

  // ---------------------------------------------------------------------------
  // Send
  // ---------------------------------------------------------------------------

  Future<void> send(
    String text, {
    String? replyToText,
    required UserRole senderRole,
  }) async {
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
        senderRole: senderRole.name,
      );
      if (sendError != null) {
        _error = sendError;
      } else {
        _error = null;
        unawaited(_createNotification(mentions: mentions));
        if (senderRole == UserRole.medic && _anonymousIdentity != null) {
          unawaited(
            _firestore
                .collection('groups')
                .doc(groupId)
                .collection('medicAnonymousIds')
                .doc(_anonymousIdentity!.anonymousId)
                .set({'isMedic': true})
                .catchError(
                  (Object e) =>
                      debugPrint('Failed to mark anonymousId as medic: $e'),
                ),
          );
        }
      }
    } catch (_) {
      _error = "Não foi possível enviar a mensagem.";
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Polls
  // ---------------------------------------------------------------------------

  PollServiceInterface get pollService => _pollService;

  Future<String?> createPoll(String question, List<String> options) async {
    final identity = _anonymousIdentity;
    if (identity == null) return 'Not connected to the room.';
    return _pollService.createPoll(
      groupId: groupId,
      question: question,
      optionTexts: options,
      identity: identity,
    );
  }

  // ---------------------------------------------------------------------------
  // Reports
  // ---------------------------------------------------------------------------

  Future<String?> reportUser({
    required Message reportedMessage,
    required String category,
    required String reason,
    String description = '',
  }) async {
    final identity = _anonymousIdentity;
    if (identity == null) return 'Não está conectado à sala.';

    return _reportService.submitUserReport(
      groupId: groupId,
      groupName: _groupName ?? 'Comunidade',
      reporterIdentity: identity,
      reportedAnonymousId: reportedMessage.anonymousId,
      reportedNickname: reportedMessage.senderNickname,
      reportedAvatarIndex: reportedMessage.senderAvatarIndex,
      category: category,
      reason: reason,
      description: description,
    );
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

  Future<void> deleteMessage(String messageId) async {
    final err = await _chatService.deleteMessage(
      groupId: groupId,
      messageId: messageId,
    );
    if (err != null && !_isDisposed) {
      _error = err;
      notifyListeners();
    }
  }

  bool isMessagePinned(String messageId) =>
      _pinnedMessageIds.contains(messageId);

  Future<void> pinMessage(Message message) async {
    final err = await _chatService.pinMessage(
      groupId: groupId,
      message: message,
    );
    if (err != null && !_isDisposed) {
      _error = err;
      notifyListeners();
    }
  }

  Future<void> unpinMessage(String messageId) async {
    final err = await _chatService.unpinMessage(
      groupId: groupId,
      messageId: messageId,
    );
    if (err != null && !_isDisposed) {
      _error = err;
      notifyListeners();
    }
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
    _pinnedMessagesSubscription?.cancel();
    _medicSub?.cancel();
    super.dispose();
  }
}
