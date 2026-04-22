import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/message.dart';
import '../services/chat_service.dart';

class ChatController extends ChangeNotifier {
  final String groupId;
  final ChatService _service;
  late final StreamSubscription<List<Message>> _subscription;

  List<Message> _messages = const [];
  bool _isLoading = true;
  bool _isSending = false;

  ChatController({
    required this.groupId,
    ChatService? service,
  }) : _service = service ?? ChatService() {
    _subscription = _service.streamMessages(groupId).listen((messages) {
      _messages = messages;
      _isLoading = false;
      notifyListeners();
    });
  }

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;
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
