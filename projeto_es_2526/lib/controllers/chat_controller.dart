import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/anonymous_identity.dart';
import '../models/message.dart';
import '../services/identity_service.dart';

class ChatController extends ChangeNotifier {
  static const int maxMessageLength = 2000;

  final String groupId;
  final FirebaseFirestore _firestore;
  final IdentityService _identityService;
  final FirebaseAuth _auth;

  late final String _userId;
  AnonymousIdentity? _anonymousIdentity;
  String? _groupName;

  List<Message> _messages = [];
  StreamSubscription? _messagesSubscription;

  bool _isDisposed = false;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  ChatController({
    required this.groupId,
    FirebaseFirestore? firestore,
    IdentityService? identityService,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _identityService = identityService ?? IdentityService(),
        _auth = auth ?? FirebaseAuth.instance {
    final user = _auth.currentUser;
    if (user != null) {
      _userId = user.uid;
      _initialize();
    } else {
      _error = "Sessão expirada. Por favor, volta a iniciar sessão.";
      _isLoading = false;
    }
  }

  // Getters
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  AnonymousIdentity? get anonymousIdentity => _anonymousIdentity;

  Future<void> _initialize() async {
    try {
      _anonymousIdentity = await _identityService.getOrCreateIdentity(_userId, groupId);

      if (_isDisposed) return;

      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      _groupName = groupDoc.data()?['name'] as String? ?? 'Community';

      if (_isDisposed) return;

      final messagesRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .orderBy('timestamp', descending: true);

      _messagesSubscription = messagesRef.snapshots().listen((snapshot) {
        if (_isDisposed) return;
        _messages = snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        if (_isDisposed) return;
        _error = "Não foi possível carregar as mensagens.";
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      if (_isDisposed) return;
      _error = "Não foi possível inicializar o chat.";
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> send(String text, {String? replyToText}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending || _anonymousIdentity == null) return;
    if (trimmed.length > maxMessageLength) {
      _error = 'A mensagem não pode exceder $maxMessageLength caracteres.';
      notifyListeners();
      return;
    }

    _isSending = true;
    notifyListeners();

    try {
      final messagesRef = _firestore.collection('groups').doc(groupId).collection('messages');
      await messagesRef.add({
        'text': trimmed,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': _anonymousIdentity!.anonymousId,
        'senderNickname': _anonymousIdentity!.nickname,
        'replyToText': replyToText,
      });
      _error = null;
      unawaited(_createNotification());
    } catch (_) {
      _error = "Não foi possível enviar a mensagem.";
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> _createNotification() async {
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
    } catch (e) {
      debugPrint('Failed to create notification for group "$groupId": $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _messagesSubscription?.cancel();
    super.dispose();
  }
}