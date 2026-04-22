import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/message.dart';
import '../services/chat_service.dart';

class ChatController extends ChangeNotifier {
  final String groupId;
  final ChatServiceInterface _service;
  late final StreamSubscription<List<Message>> _subscription;

  static const int maxMessageLength = 2000;

  List<Message> _messages = const [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  ChatController({
    required this.groupId,
    ChatServiceInterface? service,
  }) : _service = service ?? ChatService() {
    _subscription = _service.streamMessages(groupId).listen(
      (messages) {
        _messages = messages;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _isLoading = false;
        _error = 'Failed to load messages.';
        notifyListeners();
      },
    );
  }

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;
    if (trimmed.length > maxMessageLength) {
      _error = 'Message cannot exceed $maxMessageLength characters.';
      notifyListeners();
      return;
    }
    _error = null;
    _isSending = true;
    notifyListeners();
    try {
      await _service.sendMessage(groupId: groupId, text: trimmed);
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
