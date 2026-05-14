import 'package:flutter/material.dart';

import '../models/message.dart';

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
    required this.currentAnonymousId,
    required this.hasReactionError,
    required this.isRetryingReaction,
    required this.onLongPress,
    required this.onReply,
    required this.onToggleReaction,
    required this.onRetryReaction,
  });

  Widget _buildMessageText(String text, List<String> mentions) {
    return RichText(
      text: TextSpan(
        children: buildMentionSpans(text, mentions),
      ),
    );
  }

  Widget _buildPoll() {
    final poll = message.pollData;

    if (poll == null) {
      return const Text('Poll unavailable');
    }

    final hasVoted = poll.voterIds.contains(currentAnonymousId);

    final isClosed = poll.isClosed || poll.hasExpired;

    final totalVotes = poll.options.fold<int>(
      0,
      (sum, option) => sum + option.votes,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          poll.question,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        ...poll.options.map((option) {
          final percent = totalVotes == 0
              ? 0
              : ((option.votes / totalVotes) * 100).round();

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: (!hasVoted && !isClosed)
                  ? () => onToggleReaction(option.id)
                  : null,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.text,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    if (hasVoted || isClosed)
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        Text(
          isClosed
              ? 'Poll closed'
              : hasVoted
                  ? 'Vote submitted'
                  : 'Tap to vote',
          style: TextStyle(
            fontSize: 12,
            color: isClosed
                ? Colors.red
                : const Color(0xFF185FA5),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildReactionBar(BuildContext context) {
    if (message.type == MessageType.poll) {
      return const SizedBox.shrink();
    }

    final summary = message.reactionSummary;

    if (summary.isEmpty && !hasReactionError) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          ...summary.map((entry) {
            final emoji = entry.key;
            final count = entry.value;

            final isMine =
                message.userReaction(currentAnonymousId) == emoji;

            return GestureDetector(
              onTap: () => onToggleReaction(emoji),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
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

          if (hasReactionError)
            GestureDetector(
              onTap: isRetryingReaction ? null : onRetryReaction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.shade300,
                  ),
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
                      Icon(
                        Icons.wifi_off,
                        size: 13,
                        color: Colors.red[400],
                      ),
                    const SizedBox(width: 4),
                    Text(
                      isRetryingReaction
                          ? 'A tentar...'
                          : 'Tentar novamente',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[600],
                      ),
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
      onDoubleTap: message.type == MessageType.text
          ? onLongPress
          : null,
      onLongPress: message.type == MessageType.text
          ? onReply
          : null,
      child: Align(
        alignment: isOwn
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isOwn
                ? const Color(0xFFDCE9F7)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isOwn)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message.senderNickname,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF185FA5),
                    ),
                  ),
                ),

              if (message.type == MessageType.text &&
                  message.replyToText != null)
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

              message.type == MessageType.poll
                  ? _buildPoll()
                  : _buildMessageText(
                      message.text,
                      message.mentions,
                    ),

              _buildReactionBar(context),
            ],
          ),
        ),
      ),
    );
  }
}