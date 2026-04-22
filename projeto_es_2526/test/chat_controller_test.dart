import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/controllers/chat_controller.dart';
import 'package:projeto_es_2526/models/message.dart';
import 'package:projeto_es_2526/services/chat_service.dart';

class _FakeChatService implements ChatServiceInterface {
  final List<String> sentTexts = [];
  Object? sendError;
  Completer<void>? sendCompleter;
  final _messagesController = StreamController<List<Message>>.broadcast();

  void emitMessages(List<Message> messages) =>
      _messagesController.add(messages);

  @override
  Stream<List<Message>> streamMessages(String groupId) =>
      _messagesController.stream;

  @override
  Future<void> sendMessage({required String groupId, required String text}) {
    if (sendError != null) return Future.error(sendError!);
    sentTexts.add(text);
    return sendCompleter?.future ?? Future.value();
  }

  void dispose() => _messagesController.close();
}

void main() {
  group('ChatController', () {
    late _FakeChatService service;
    late ChatController controller;

    setUp(() {
      service = _FakeChatService();
      controller = ChatController(groupId: 'g1', service: service);
    });

    tearDown(() {
      controller.dispose();
      service.dispose();
    });

    test('ignores empty or whitespace-only text', () async {
      await controller.send('   ');
      expect(service.sentTexts, isEmpty);
      expect(controller.error, isNull);
    });

    test('trims whitespace before sending', () async {
      await controller.send('  hello  ');
      expect(service.sentTexts, ['hello']);
    });

    test('sets error and does not send when text exceeds maxMessageLength',
        () async {
      final longText = 'a' * (ChatController.maxMessageLength + 1);
      await controller.send(longText);
      expect(service.sentTexts, isEmpty);
      expect(controller.error, isNotNull);
    });

    test('clears error on valid send', () async {
      final longText = 'a' * (ChatController.maxMessageLength + 1);
      await controller.send(longText);
      expect(controller.error, isNotNull);

      await controller.send('valid message');
      expect(controller.error, isNull);
    });

    test('isSending is true during send and false after', () async {
      final sendingStates = <bool>[];
      controller.addListener(() => sendingStates.add(controller.isSending));

      await controller.send('hello');

      expect(sendingStates, containsAllInOrder([true, false]));
    });

    test('concurrent send is blocked while isSending', () async {
      final completer = Completer<void>();
      service.sendCompleter = completer;

      // Start first send (won't complete until completer resolves)
      final first = controller.send('first');
      expect(controller.isSending, isTrue);

      // Second send should be a no-op while isSending
      await controller.send('second');
      expect(service.sentTexts, ['first']); // 'second' not yet sent

      completer.complete();
      await first;

      expect(service.sentTexts, ['first']); // 'second' was blocked
      expect(controller.isSending, isFalse);
    });

    test('messages stream is reflected in controller', () async {
      final messages = [
        Message(
          id: '1',
          text: 'hi',
          senderId: 'u1',
          createdAt: DateTime(2025),
        ),
      ];
      service.emitMessages(messages);
      await Future.microtask(() {});
      expect(controller.messages, messages);
      expect(controller.isLoading, isFalse);
    });
  });
}
