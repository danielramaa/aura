import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controllers/chat_controller.dart';
import '../models/message.dart';
import '../models/message_search_result.dart';
import '../models/user_role.dart';
import '../services/user_service.dart';
import '../utils/avatar_utils.dart';
import '../widgets/create_poll_sheet.dart';
import '../widgets/emoji_picker_sheet.dart';
import '../widgets/message_bubble.dart';
import '../widgets/medications_dialog.dart';
import '../widgets/poll_bubble.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();

  Message? _replyingTo;
  Timer? _searchDebounce;
  Timer? _highlightTimer;
  List<String> _mentionSuggestions = [];
  UserRole _currentUserRole = UserRole.user;
  StreamSubscription<UserRole>? _roleSub;
  bool _isSearchOpen = false;
  String? _highlightedMessageId;

  @override
  void initState() {
    super.initState();
    _controller = ChatController(groupId: widget.groupId);
    _controller.addListener(_handleControllerChanges);
    _messageController.addListener(_onTextChanged);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _roleSub = UserService().streamRole(uid).listen((role) {
        if (mounted) setState(() => _currentUserRole = role);
      });
    }
  }

  @override
  void dispose() {
    _roleSub?.cancel();
    _controller.removeListener(_handleControllerChanges);
    _controller.dispose();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _searchDebounce?.cancel();
    _highlightTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
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

  void _showMessageOptions(BuildContext context, Message message) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: const Text('React'),
              onTap: () {
                Navigator.pop(context);
                _showEmojiPicker(context, message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete message',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _controller.deleteMessage(message.id);
              },
            ),
          ],
        ),
      ),
    );
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

  void _showCreatePollSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CreatePollSheet(
        onPublish: (question, options) =>
            _controller.createPoll(question, options),
      ),
    );
  }

  void _openSearch() {
    setState(() => _isSearchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _controller.clearMessageSearch();
    setState(() => _isSearchOpen = false);
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _controller.searchMessages(query);
    });
  }

  Future<void> _jumpToSearchResult(MessageSearchResult result) async {
    final index = _controller.indexOfMessage(result.message.id);
    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensagem não encontrada no chat.')),
      );
      return;
    }

    _closeSearch();
    setState(() => _highlightedMessageId = result.message.id);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_scrollController.hasClients) return;
      final maxOffset = _scrollController.position.maxScrollExtent;
      final targetOffset = (index * 92.0).clamp(0.0, maxOffset).toDouble();
      await _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });

    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _highlightedMessageId = null);
    });
  }

  Future<bool> _processLeaveGroup() async {
    try {
      await _controller.leaveGroup();
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
                    SnackBar(
                      content: const Text('Failed to leave group.'),
                      backgroundColor: Colors.red,
                      action: SnackBarAction(
                        label: 'Try Again',
                        textColor: Colors.white,
                        onPressed: () async {
                          final retry = await _processLeaveGroup();
                          if (retry && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
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
      await _controller.send(
        text,
        replyToText: _replyingTo?.text,
        senderRole: _currentUserRole,
      );
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
            icon: Icon(_isSearchOpen ? Icons.close : Icons.search),
            tooltip: _isSearchOpen ? 'Fechar pesquisa' : 'Pesquisar mensagens',
            onPressed: _isSearchOpen ? _closeSearch : _openSearch,
          ),
          IconButton(
            icon: const Icon(Icons.medical_services_outlined),
            tooltip: 'Medications',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => MedicationsDialog(
                  groupId: widget.groupId,
                  userRole: _currentUserRole,
                ),
              );
            },
          ),
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
              if (_isSearchOpen) _buildSearchPanel(),
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

        if (message.type == MessageType.poll && message.pollId != null) {
          return PollBubble(
            message: message,
            isOwn: isOwn,
            currentAnonymousId:
                _controller.anonymousIdentity?.anonymousId ?? '',
            pollService: _controller.pollService,
            groupId: widget.groupId,
          );
        }

        return MessageBubble(
          message: message,
          isOwn: isOwn,
          isSenderMedic: _controller.medicAnonymousIds.contains(
            message.anonymousId,
          ),
          currentAnonymousId: _controller.anonymousIdentity?.anonymousId ?? '',
          hasReactionError: _controller.hasReactionError(message.id),
          isRetryingReaction: _controller.isRetryingReaction(message.id),
          isHighlighted: _highlightedMessageId == message.id,
          onLongPress: () => _currentUserRole == UserRole.admin
              ? _showMessageOptions(context, message)
              : _showEmojiPicker(context, message),
          onReply: () => _startReply(message),
          onToggleReaction: (emoji) =>
              _controller.toggleReaction(message.id, emoji),
          onRetryReaction: () => _controller.retryReaction(message.id),
        );
      },
    );
  }

  Widget _buildSearchPanel() {
    final query = _controller.messageSearchQuery;
    final results = _controller.searchResults;
    final hasQuery = query.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Pesquisar mensagens...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchDebounce?.cancel();
                            _searchController.clear();
                            _controller.clearMessageSearch();
                            setState(() {});
                          },
                        ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onChanged: (value) {
                  setState(() {});
                  _onSearchChanged(value);
                },
                onSubmitted: _controller.searchMessages,
              ),
              if (_controller.searchError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _controller.searchError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
              if (hasQuery) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: _buildSearchResultsList(results, query),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultsList(
    List<MessageSearchResult> results,
    String query,
  ) {
    if (_controller.isSearchingMessages && results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _controller.hasMoreSearchResults
                  ? 'Sem resultados nas mensagens recentes.'
                  : 'Sem resultados para "$query".',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (_controller.hasMoreSearchResults) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _controller.isSearchingMessages
                    ? null
                    : _controller.loadMoreSearchResults,
                icon: const Icon(Icons.expand_more),
                label: const Text('Pesquisar mensagens antigas'),
              ),
            ],
          ],
        ),
      );
    }

    final itemCount =
        results.length + (_controller.hasMoreSearchResults ? 1 : 0);

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: itemCount,
      separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey[200]),
      itemBuilder: (context, index) {
        if (index >= results.length) {
          return TextButton.icon(
            onPressed: _controller.isSearchingMessages
                ? null
                : _controller.loadMoreSearchResults,
            icon: _controller.isSearchingMessages
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more),
            label: const Text('Carregar mensagens antigas'),
          );
        }

        final result = results[index];
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(
            result.message.senderNickname,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  children: _buildSearchSnippetSpans(result),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatSearchTimestamp(result.message.timestamp),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          trailing: const Icon(Icons.subdirectory_arrow_left, size: 18),
          onTap: () => _jumpToSearchResult(result),
        );
      },
    );
  }

  List<TextSpan> _buildSearchSnippetSpans(MessageSearchResult result) {
    final spans = <TextSpan>[];
    final start = result.matchStart.clamp(0, result.snippet.length).toInt();
    final end = result.matchEnd.clamp(start, result.snippet.length).toInt();

    if (start > 0) {
      spans.add(TextSpan(text: result.snippet.substring(0, start)));
    }
    spans.add(
      TextSpan(
        text: result.snippet.substring(start, end),
        style: const TextStyle(
          backgroundColor: Color(0xFFFFE08A),
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    if (end < result.snippet.length) {
      spans.add(TextSpan(text: result.snippet.substring(end)));
    }

    return spans;
  }

  String _formatSearchTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
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
                  AvatarUtils.buildAvatar(nickname, 28),
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
          IconButton(
            icon: const Icon(Icons.poll_outlined),
            color: const Color(0xFF185FA5),
            tooltip: 'Create poll',
            onPressed: isSending ? null : _showCreatePollSheet,
          ),
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
