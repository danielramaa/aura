
import 'package:flutter/material.dart';
 

class ChatMessage {
  final String id;
  final String text;
  final String authorNickname;
  final bool isDeleted;
  final ChatMessage? replyTo;
 
  const ChatMessage({
    required this.id,
    required this.text,
    required this.authorNickname,
    this.isDeleted = false,
    this.replyTo,
  });
 
  ChatMessage copyWithDeleted() {
    return ChatMessage(
      id: id,
      text: text,
      authorNickname: authorNickname,
      isDeleted: true,
      replyTo: replyTo,
    );
  }
}
 
class ChatScreen extends StatefulWidget {
  final String groupName;
  final String memberCount;
  final String groupDescription;
 
  const ChatScreen({
    super.key,
    required this.groupName,
    required this.memberCount,
    required this.groupDescription,
  });
 
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}
 
class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
 
  final List<ChatMessage> _messages = [];
 
  
  ChatMessage? _replyingTo;
 
  
  Offset _lastTapPosition = Offset.zero;
 
  
  static const String _myNickname = 'Anónimo';
 
  
  int _idCounter = 0;
  String _nextId() => 'msg_${_idCounter++}';
 
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
 
    setState(() {
      _messages.add(ChatMessage(
        id: _nextId(),
        text: text,
        authorNickname: _myNickname,
        replyTo: _replyingTo,
      ));
      _messageController.clear();
      _replyingTo = null;
    });
 
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
 
  void _startReply(ChatMessage message) {
    setState(() => _replyingTo = message);
  }
 
  void _cancelReply() {
    setState(() => _replyingTo = null);
  }
 
  void _showContextMenu(BuildContext context, Offset position, ChatMessage message) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          onTap: () => _startReply(message),
          child: const Row(
            children: [
              Icon(Icons.reply, size: 18, color: Colors.grey),
              SizedBox(width: 8),
              Text('Responder'),
            ],
          ),
        ),
      ],
    );
  }
 
  void _scrollToMessage(String messageId) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
 
    const estimatedItemHeight = 72.0;
    _scrollController.animateTo(
      index * estimatedItemHeight,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }
 
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
 
  
  // Widgets
  
 
  Widget _buildQuotedBox({
    required String authorNickname,
    required String text,
    required bool isDeleted,
    VoidCallback? onTap,
    bool isPreview = false,
  }) {
    final displayText = isDeleted ? '[Mensagem removida]' : text;
    final color = isPreview ? const Color(0xFF185FA5) : Colors.grey[400]!;
 
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isPreview ? const Color(0xFFE8F0FB) : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: color, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              authorNickname,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              displayText,
              style: TextStyle(
                fontSize: 12,
                color: isDeleted ? Colors.grey[500] : Colors.black87,
                fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
 
  Widget _buildMessageBubble(ChatMessage message) {
    return GestureDetector(
      onTapDown: (details) => _lastTapPosition = details.globalPosition,
      onTap: () => _showContextMenu(context, _lastTapPosition, message),
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, details.globalPosition, message),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.replyTo != null)
                _buildQuotedBox(
                  authorNickname: message.replyTo!.authorNickname,
                  text: message.replyTo!.text,
                  isDeleted: message.replyTo!.isDeleted,
                  onTap: message.replyTo!.isDeleted
                      ? null
                      : () => _scrollToMessage(message.replyTo!.id),
                ),
              Text(
                message.text,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
 
  Widget _buildReplyPreview() {
    if (_replyingTo == null) return const SizedBox.shrink();
 
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildQuotedBox(
              authorNickname: _replyingTo!.authorNickname,
              text: _replyingTo!.text,
              isDeleted: _replyingTo!.isDeleted,
              isPreview: true,
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
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'Sem mensagens ainda.\nSeja o primeiro a escrever!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _buildMessageBubble(_messages[index]),
                  ),
          ),
 
          
          _buildReplyPreview(),
 
          
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
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
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}