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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final IdentityService _identityService = IdentityService();
  final _auth = FirebaseAuth.instance;

  late final String _userId;
  AnonymousIdentity? _anonymousIdentity;

  List<Message> _messages = [];
  StreamSubscription? _messagesSubscription;

  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  ChatController({required this.groupId}) {
    final user = _auth.currentUser;
    if (user != null) {
      _userId = user.uid;
      _initialize();
    } else {
      _error = "Sessão expirada ou não iniciada (FirebaseAuth.instance.currentUser é null).";
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

      final messagesRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .orderBy('timestamp', descending: true);

      _messagesSubscription = messagesRef.snapshots().listen((snapshot) {
        _messages = snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        _error = "Erro ao carregar mensagens:\n$e";
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _error = "Erro técnico no Firebase:\n$e";
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
    } catch (e) {
      _error = e.toString();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    super.dispose();
  }
}