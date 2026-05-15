import 'package:flutter/material.dart';

import '../models/message.dart';
import '../utils/avatar_utils.dart';

/// Returns RichText spans for [text], highlighting only @tokens whose word
/// part appears in [mentions] (the validated list stored on the message).
List<TextSpan> buildMentionSpans(String text, List<String> mentions) {
  final spans = <TextSpan>[];
  final regex = RegExp(r'@(\w+)');
  int lastEnd = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      );
    }
    final word = match.group(1)!;
    final isValid = mentions.contains(word);
    spans.add(
      TextSpan(
        text: match.group(0),
        style: TextStyle(
          fontSize: 14,
          color: isValid ? const Color(0xFF185FA5) : Colors.black87,
          fontWeight: isValid ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    spans.add(
      TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
    );
  }
  return spans;
}

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isOwn;
  final bool isSenderMedic;
  final String currentAnonymousId;
  final bool hasReactionError;
  final bool isRetryingReaction;
  final VoidCallback onLongPress;
  final VoidCallback onReply;
  final ValueChanged<String> onToggleReaction;
  final VoidCallback onRetryReaction;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isSenderMedic,
    required this.currentAnonymousId,
    required this.hasReactionError,
    required this.isRetryingReaction,
    required this.onLongPress,
    required this.onReply,
    required this.onToggleReaction,
    required this.onRetryReaction,
  });

  Widget _buildMessageText(String text, List<String> mentions) =>
      RichText(text: TextSpan(children: buildMentionSpans(text, mentions)));

  Widget _buildReactionBar(BuildContext context) {
    final summary = message.reactionSummary;
    if (summary.isEmpty && !hasReactionError) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          ...summary.map((entry) {
            final emoji = entry.key;
            final count = entry.value;
            final isMine = message.userReaction(currentAnonymousId) == emoji;

            return GestureDetector(
              onTap: () => onToggleReaction(emoji),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isMine ? const Color(0xFFDCE9F7) : Colors.grey[200],
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
                    color: isMine ? const Color(0xFF185FA5) : Colors.black87,
                    fontWeight: isMine ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }),
          if (hasReactionError)
            GestureDetector(
              onTap: isRetryingReaction ? null : onRetryReaction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          color: Colors.red,
                        ),
                      )
                    else
                      Icon(Icons.wifi_off, size: 13, color: Colors.red[400]),
                    const SizedBox(width: 4),
                    Text(
                      isRetryingReaction ? 'A tentar...' : 'Tentar novamente',
                      style: TextStyle(fontSize: 12, color: Colors.red[600]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Padding(
      padding: isOwn
          ? const EdgeInsets.only(left: 8.0)
          : const EdgeInsets.only(right: 8.0),
      child: AvatarUtils.buildAvatarFromAsset(
        message.senderAvatarAssetPath,
        32,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onLongPress,
      onLongPress: onReply,
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isOwn) _buildAvatar(),
              Flexible(
                child: Container(
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                message.senderNickname,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF185FA5),
                                ),
                              ),
                              if (isSenderMedic)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4.0),
                                  child: Icon(
                                    Icons.verified,
                                    size: 14,
                                    color: Color(0xFF185FA5),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (message.replyToText != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              left: BorderSide(
                                color: Colors.grey[400]!,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            message.replyToText!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      _buildMessageText(message.text, message.mentions),
                      _buildReactionBar(context),
                    ],
                  ),
                ),
              ),
              if (isOwn) _buildAvatar(),
            ],
          ),
        ),
      ),
    );
  }
}
