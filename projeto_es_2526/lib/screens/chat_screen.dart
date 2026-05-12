import 'package:flutter/material.dart';

import '../controllers/chat_controller.dart';
import '../models/message.dart';

// ---------------------------------------------------------------------------
// Emojis available in the picker
// ---------------------------------------------------------------------------
const List<String> _kPickerEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

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

  // ---------------------------------------------------------------------------
  // Mentions
  // ---------------------------------------------------------------------------

  void _onTextChanged() {
    final text = _messageController.text;
    final cursor = _messageController.selection.baseOffset;
    if (cursor < 0) return;

    final textBeforeCursor = text.substring(0, cursor);
    final match = RegExp(r'@(\w*)$').firstMatch(textBeforeCursor);

    if (match != null) {
      final query = match.group(1)!.toLowerCase();
      final suggestions = _controller.roomNicknames
          .where((n) => n.toLowerCase().startsWith(query))
          .toList();
      setState(() => _mentionSuggestions = suggestions);
    } else {
      setState(() => _mentionSuggestions = []);
    }
  }

  void _applyMention(String nickname) {
    final text = _messageController.text;
    final cursor = _messageController.selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursor);
    final newTextBefore =
        textBeforeCursor.replaceAll(RegExp(r'@\w*$'), '@$nickname ');
    final newText = newTextBefore + text.substring(cursor);
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newTextBefore.length),
    );
    setState(() => _mentionSuggestions = []);
  }

  // ---------------------------------------------------------------------------
  // Reactions
  // ---------------------------------------------------------------------------

  /// A1: Opens the emoji picker as a modal bottom sheet on long-press.
  void _showEmojiPicker(BuildContext context, Message message) {
    final identity = _controller.anonymousIdentity;
    if (identity == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmojiPickerSheet(
        currentEmoji: message.userReaction(identity.anonymousId),
        onEmojiSelected: (emoji) {
          Navigator.pop(context);
          _controller.toggleReaction(message.id, emoji);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reply
  // ---------------------------------------------------------------------------

  void _startReply(Message message) {
    setState(() => _replyingTo = message);
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  // ---------------------------------------------------------------------------
  // Send
  // ---------------------------------------------------------------------------

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
        const SnackBar(content: Text('Erro ao enviar mensagem. Tente novamente.')),
      );
    }

    if (_controller.error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_controller.error!)));
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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
                  fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.memberCount} members',
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.normal),
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
              _buildInputRow(),
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
        final isOwn = message.anonymousId ==
            _controller.anonymousIdentity?.anonymousId;
        return _MessageBubble(
          message: message,
          isOwn: isOwn,
          currentAnonymousId:
              _controller.anonymousIdentity?.anonymousId ?? '',
          hasReactionError: _controller.hasReactionError(message.id),
          isRetryingReaction: _controller.isRetryingReaction(message.id),
          onLongPress: () => _showEmojiPicker(context, message),
          onReply: () => _startReply(message),
          onRetryReaction: (emoji) =>
              _controller.retryReaction(message.id, emoji),
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
                fontStyle: FontStyle.italic),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FB),
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                    left: BorderSide(color: Color(0xFF185FA5), width: 3)),
              ),
              child: Text(
                _replyingTo!.text,
                style:
                    const TextStyle(fontSize: 12, color: Colors.black87),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFFDCE9F7),
                    child: Icon(Icons.person,
                        size: 16, color: Color(0xFF185FA5)),
                  ),
                  const SizedBox(width: 10),
                  Text('@$nickname',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF185FA5))),
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20),
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

// ---------------------------------------------------------------------------
// Emoji Picker Sheet  (A1)
// ---------------------------------------------------------------------------

class _EmojiPickerSheet extends StatelessWidget {
  final String? currentEmoji;
  final ValueChanged<String> onEmojiSelected;

  const _EmojiPickerSheet({
    required this.currentEmoji,
    required this.onEmojiSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _kPickerEmojis.map((emoji) {
          final isSelected = emoji == currentEmoji;
          return GestureDetector(
            onTap: () => onEmojiSelected(emoji),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFDCE9F7)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message Bubble  (A2, A3, B1, B2)
// ---------------------------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isOwn;
  final String currentAnonymousId;
  final bool hasReactionError;
  final bool isRetryingReaction;
  final VoidCallback onLongPress;
  final VoidCallback onReply;
  final ValueChanged<String> onRetryReaction;

  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.currentAnonymousId,
    required this.hasReactionError,
    required this.isRetryingReaction,
    required this.onLongPress,
    required this.onReply,
    required this.onRetryReaction,
  });

  Widget _buildMessageText(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'@(\w+)');
    int lastEnd = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF185FA5),
            fontWeight: FontWeight.bold),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }

  /// A2: Reaction bar shown below the message content.
  Widget _buildReactionBar(BuildContext context) {
    final summary = message.reactionSummary;
    if (summary.isEmpty && !hasReactionError) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          // A2/A3: each emoji chip
          ...summary.map((entry) {
            final emoji = entry.key;
            final count = entry.value;
            final isMine = message.userReaction(currentAnonymousId) == emoji;

            return GestureDetector(
              onTap: () {
                // A3: tapping own reaction removes it; tapping another replaces
                final ctrl = context
                    .findAncestorStateOfType<_ChatScreenState>()
                    ?._controller;
                ctrl?.toggleReaction(message.id, emoji);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isMine
                      ? const Color(0xFFDCE9F7)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isMine
                        ? const Color(0xFF185FA5)
                        : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  '$emoji $count',
                  style: TextStyle(
                    fontSize: 13,
                    color: isMine
                        ? const Color(0xFF185FA5)
                        : Colors.black87,
                    fontWeight: isMine
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }),

          // B1/B2: discrete error chip with "Tentar novamente"
          if (hasReactionError)
            GestureDetector(
              onTap: isRetryingReaction
                  ? null
                  : () {
                      final lastEmoji =
                          message.userReaction(currentAnonymousId) ??
                              _kPickerEmojis.first;
                      onRetryReaction(lastEmoji);
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isRetryingReaction)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.red),
                      )
                    else
                      Icon(Icons.wifi_off,
                          size: 13, color: Colors.red[400]),
                    const SizedBox(width: 4),
                    Text(
                      isRetryingReaction
                          ? 'A tentar...'
                          : 'Tentar novamente',
                      style: TextStyle(
                          fontSize: 12, color: Colors.red[600]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress, // A1: opens emoji picker
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isOwn ? const Color(0xFFDCE9F7) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isOwn)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    message.senderNickname,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF185FA5)),
                  ),
                ),
              if (message.replyToText != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                        left: BorderSide(
                            color: Colors.grey[400]!, width: 3)),
                  ),
                  child: Text(
                    message.replyToText!,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              _buildMessageText(message.text),
              // A2: reaction bar
              _buildReactionBar(context),
            ],
          ),
        ),
      ),
    );
  }
}