import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../controllers/chat_controller.dart';
import '../models/message.dart';
import '../widgets/emoji_picker_sheet.dart';
import '../widgets/message_bubble.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Message? _replyingTo;
  List<String> _mentionSuggestions = [];

  @override
  void initState() {
    super.initState();
    _controller = ChatController(groupId: widget.groupId);
    _controller.addListener(_handleControllerChanges);
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanges);
    _controller.dispose();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleControllerChanges() {
    if (mounted) setState(() {});
  }

  void _onTextChanged() {
    final text = _messageController.text;
    final cursor = _messageController.selection.baseOffset;
    if (cursor < 0) return;

    final textBeforeCursor = text.substring(0, cursor);
    final match = RegExp(r'@(\w*)$').firstMatch(textBeforeCursor);

    if (match != null) {
      final query = match.group(1)!.toLowerCase();
      if (query.isEmpty) {
        _controller.refreshRoomNicknames().then((_) {
          if (mounted) {
            setState(() => _mentionSuggestions = _controller.roomNicknames);
          }
        });
      }
      setState(
        () => _mentionSuggestions = _controller.roomNicknames
            .where((n) => n.toLowerCase().startsWith(query))
            .toList(),
      );
    } else {
      setState(() => _mentionSuggestions = []);
    }
  }

  void _applyMention(String nickname) {
    final text = _messageController.text;
    final cursor = _messageController.selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursor);
    final newTextBefore = textBeforeCursor.replaceAll(
      RegExp(r'@\w*$'),
      '@$nickname ',
    );
    final newText = newTextBefore + text.substring(cursor);
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newTextBefore.length),
    );
    setState(() => _mentionSuggestions = []);
  }

  void _showEmojiPicker(BuildContext context, Message message) {
    final identity = _controller.anonymousIdentity;
    if (identity == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => EmojiPickerSheet(
        currentEmoji: message.userReaction(identity.anonymousId),
        onEmojiSelected: (emoji) {
          Navigator.pop(context);
          _controller.toggleReaction(message.id, emoji);
        },
      ),
    );
  }

  void _startReply(Message message) {
    setState(() => _replyingTo = message);
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  Future<bool> _processLeaveGroup() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    try {
      final userIdentityRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('anonymousIdentities')
          .doc(widget.groupId);

      final userIdentityDoc = await userIdentityRef.get();
      if (!userIdentityDoc.exists) return true;

      final data = userIdentityDoc.data()!;
      final anonymousId = data['anonymousId'] as String?;
      final nickname = data['nickname'] as String?;

      // Decrement first while identity still exists (required by Firestore rule).
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({'memberCount': FieldValue.increment(-1)});

      await userIdentityRef.delete();

      if (anonymousId != null) {
        await FirebaseFirestore.instance
            .collection('anonymousIdentities')
            .doc(anonymousId)
            .delete();
      }

      if (nickname != null) {
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('takenNicknames')
            .doc(nickname)
            .delete();
      }

      return true;
    } catch (e) {
      debugPrint('Error leaving group: $e');
      return false;
    }
  }

  void _showLeaveConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Leave Group',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to leave this conversation? You will no longer receive notifications from this group.',
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50],
                elevation: 0,
              ),
              child: const Text(
                'Leave',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Leaving group...'),
                    duration: Duration(seconds: 1),
                  ),
                );

                final success = await _processLeaveGroup();

                if (!context.mounted) return;
                if (success) {
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to leave group. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;

    try {
      await _controller.send(text, replyToText: _replyingTo?.text);
      _messageController.clear();
      setState(() {
        _replyingTo = null;
        _mentionSuggestions = [];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao enviar mensagem. Tente novamente.'),
        ),
      );
    }

    if (_controller.error != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_controller.error!)));
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
                builder: (infoContext) => AlertDialog(
                  title: Text(widget.groupName),
                  content: Text(widget.groupDescription),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(infoContext);
                        _showLeaveConfirmation(context);
                      },
                      child: const Text(
                        'Leave Group',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(infoContext),
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
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.error != null &&
              _controller.anonymousIdentity == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Não foi possível carregar o chat. Tente novamente mais tarde.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(child: _buildBody()),
              _buildTypingIndicator(),
              _buildReplyPreview(),
              _buildMentionSuggestions(),
              SafeArea(top: false, child: _buildInputRow()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    final messages = _controller.messages;
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'Sem mensagens ainda.\nSeja o primeiro a escrever!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isOwn =
            message.anonymousId == _controller.anonymousIdentity?.anonymousId;
        return MessageBubble(
          message: message,
          isOwn: isOwn,
          currentAnonymousId: _controller.anonymousIdentity?.anonymousId ?? '',
          hasReactionError: _controller.hasReactionError(message.id),
          isRetryingReaction: _controller.isRetryingReaction(message.id),
          onLongPress: () => _showEmojiPicker(context, message),
          onReply: () => _startReply(message),
          onToggleReaction: (emoji) =>
              _controller.toggleReaction(message.id, emoji),
          onRetryReaction: () => _controller.retryReaction(message.id),
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<List<String>>(
      stream: _controller.typingNamesStream,
      builder: (context, snapshot) {
        final names = snapshot.data ?? [];
        if (names.isEmpty) return const SizedBox.shrink();
        final label = names.length == 1
            ? '${names.first} is typing...'
            : '${names.join(', ')} are typing...';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplyPreview() {
    if (_replyingTo == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FB),
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                  left: BorderSide(color: Color(0xFF185FA5), width: 3),
                ),
              ),
              child: Text(
                _replyingTo!.text,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildMentionSuggestions() {
    if (_mentionSuggestions.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _mentionSuggestions.length,
        itemBuilder: (context, index) {
          final nickname = _mentionSuggestions[index];
          return InkWell(
            onTap: () => _applyMention(nickname),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFFDCE9F7),
                    child: Icon(
                      Icons.person,
                      size: 16,
                      color: Color(0xFF185FA5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '@$nickname',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF185FA5),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
              onChanged: (_) => _controller.notifyTyping(),
              decoration: InputDecoration(
                hintText: 'Escreva uma mensagem...',
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
}
