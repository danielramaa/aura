import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controllers/chat_controller.dart';
import '../models/message.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
class ChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String memberCount;
  final String groupDescription;

  const ChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.memberCount,
    required this.groupDescription,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController _controller;
  late final String _currentUserId;
  final TextEditingController _messageController = TextEditingController();
  Timer? _typingTimer;
 late final String _nickname;

  @override
  void initState() {
    super.initState();
    _controller = ChatController(groupId: widget.groupId);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _currentUserId = '';
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).pop());
    } else {
      _currentUserId = currentUser.uid;
    }
    _nickname = "User_${_currentUserId.substring(0, 5)}";
  }

  @override
  void dispose() {
    _controller.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text;
    try {
      await _controller.send(text);
      if (_controller.error != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_controller.error!)),
        );
        return;
      }
      _messageController.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${widget.memberCount} members',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(widget.groupName),
                  content: Text(widget.groupDescription),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Column(
            children: [
              Expanded(child: _buildBody()),
              _buildTypingIndicator(),
              _buildInputRow(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final messages = _controller.messages;
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet. Say hi!',
          style: TextStyle(color: Colors.grey[500], fontSize: 14),
        ),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        return _MessageBubble(
          message: message,
          isOwn: message.senderId == _currentUserId,
        );
      },
    );
  }

  Widget _buildInputRow() {
    final isSending = _controller.isSending;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !isSending,
              onChanged: (_) => _onTyping(),
              decoration: InputDecoration(
                hintText: 'Type and send a message',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF185FA5),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
  void _onTyping() {
  FirebaseFirestore.instance
      .collection('groups')
      .doc(widget.groupId)
      .collection('typing')
      .doc(_currentUserId)
      .set({
    'nickname': _nickname,
    'timestamp': FieldValue.serverTimestamp(),
  });

  _typingTimer?.cancel();
  _typingTimer = Timer(const Duration(seconds: 3), () {
    FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('typing')
        .doc(_currentUserId)
        .delete();
  });
}
Widget _buildTypingIndicator() {
  return StreamBuilder(
    stream: FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('typing')
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox();

      final docs = snapshot.data!.docs;
      final others = docs.where((d) => d.id != _currentUserId).toList();

      if (others.isEmpty) return const SizedBox();

      final names = others.map((d) => d['nickname']).toList();

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text("${names.join(', ')} is typing..."),
      );
    },
  );
}
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isOwn;

  const _MessageBubble({required this.message, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOwn ? const Color(0xFFDCE9F7) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.text,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
