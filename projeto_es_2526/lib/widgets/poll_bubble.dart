import 'package:flutter/material.dart';

import '../models/message.dart';
import '../models/poll.dart';
import '../services/poll_service.dart';
import '../utils/avatar_utils.dart';

class PollBubble extends StatefulWidget {
  final Message message;
  final bool isOwn;
  final String currentAnonymousId;
  final PollService pollService;
  final String groupId;

  const PollBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.currentAnonymousId,
    required this.pollService,
    required this.groupId,
  });

  @override
  State<PollBubble> createState() => _PollBubbleState();
}

class _PollBubbleState extends State<PollBubble> {
  int? _pendingVote;
  bool _isClosing = false;

  Future<void> _vote(Poll poll, int optionIndex) async {
    if (!poll.isOpen) return;
    setState(() => _pendingVote = optionIndex);

    final error = await widget.pollService.vote(
      groupId: widget.groupId,
      pollId: poll.id,
      optionIndex: optionIndex,
      anonymousId: widget.currentAnonymousId,
    );

    if (!mounted) return;
    setState(() => _pendingVote = null);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _closePoll(Poll poll) async {
    setState(() => _isClosing = true);

    final error = await widget.pollService.closePoll(
      groupId: widget.groupId,
      pollId: poll.id,
      anonymousId: widget.currentAnonymousId,
    );

    if (!mounted) return;
    setState(() => _isClosing = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  String _timeLabel(Poll poll) {
    if (!poll.isOpen) return 'Poll closed';
    final expiry = poll.createdAt.toDate().add(const Duration(hours: 24));
    final remaining = expiry.difference(DateTime.now());
    if (remaining.inHours >= 1) {
      return 'Closes in ${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
    }
    return 'Closes in ${remaining.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Poll>(
      stream: widget.pollService.streamPoll(
        widget.groupId,
        widget.message.pollId!,
      ),
      builder: (context, pollSnap) {
        if (!pollSnap.hasData) return const SizedBox.shrink();
        final poll = pollSnap.data!;

        return StreamBuilder<int?>(
          stream: widget.pollService.streamUserVote(
            widget.groupId,
            poll.id,
            widget.currentAnonymousId,
          ),
          builder: (context, voteSnap) {
            final userVote = voteSnap.data;
            final hasVoted = userVote != null;
            return _PollCard(
              message: widget.message,
              poll: poll,
              isOwn: widget.isOwn,
              currentAnonymousId: widget.currentAnonymousId,
              hasVoted: hasVoted,
              userVote: userVote,
              pendingVote: _pendingVote,
              isClosing: _isClosing,
              timeLabel: _timeLabel(poll),
              onVote: (i) => _vote(poll, i),
              onClose: () => _closePoll(poll),
            );
          },
        );
      },
    );
  }
}

class _PollCard extends StatelessWidget {
  final Message message;
  final Poll poll;
  final bool isOwn;
  final String currentAnonymousId;
  final bool hasVoted;
  final int? userVote;
  final int? pendingVote;
  final bool isClosing;
  final String timeLabel;
  final ValueChanged<int> onVote;
  final VoidCallback onClose;

  const _PollCard({
    required this.message,
    required this.poll,
    required this.isOwn,
    required this.currentAnonymousId,
    required this.hasVoted,
    required this.userVote,
    required this.pendingVote,
    required this.isClosing,
    required this.timeLabel,
    required this.onVote,
    required this.onClose,
  });

  Widget _buildAvatar() {
    final avatar = AvatarUtils.buildAvatarFromAsset(
      message.senderAvatarAssetPath,
      32,
    );
    return Padding(
      padding: isOwn
          ? const EdgeInsets.only(left: 8)
          : const EdgeInsets.only(right: 8),
      child: avatar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCreator = poll.creatorAnonymousId == currentAnonymousId;
    final canVote = poll.isOpen && !hasVoted;
    final total = poll.totalVotes;

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isOwn) _buildAvatar(),
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.82,
                ),
                decoration: BoxDecoration(
                  color: isOwn ? const Color(0xFFDCE9F7) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isOwn)
                            Text(
                              message.senderNickname,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF185FA5),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.poll_outlined,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Anonymous Poll',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const Spacer(),
                              if (!poll.isOpen)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Closed',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            poll.question,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    // Options
                    ...List.generate(poll.options.length, (i) {
                      final option = poll.options[i];
                      final isVoted = userVote == i;
                      final isPending = pendingVote == i;
                      final pct = total == 0 ? 0.0 : option.voteCount / total;

                      return _OptionTile(
                        option: option,
                        index: i,
                        isVoted: isVoted,
                        isPending: isPending,
                        showResults: hasVoted || !poll.isOpen,
                        canVote: canVote && pendingVote == null,
                        percentage: pct,
                        onVote: () => onVote(i),
                      );
                    }),
                    // Footer
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                      child: Row(
                        children: [
                          Text(
                            '$total vote${total == 1 ? '' : 's'} · $timeLabel',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          const Spacer(),
                          if (isCreator && poll.isOpen)
                            _CloseButton(
                              isClosing: isClosing,
                              onClose: onClose,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isOwn) _buildAvatar(),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final PollOption option;
  final int index;
  final bool isVoted;
  final bool isPending;
  final bool showResults;
  final bool canVote;
  final double percentage;
  final VoidCallback onVote;

  const _OptionTile({
    required this.option,
    required this.index,
    required this.isVoted,
    required this.isPending,
    required this.showResults,
    required this.canVote,
    required this.percentage,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final pctLabel = '${(percentage * 100).round()}%';

    return InkWell(
      onTap: canVote ? onVote : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    option.text,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight: isVoted ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (isPending)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (isVoted)
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Color(0xFF185FA5),
                  )
                else if (showResults)
                  Text(
                    pctLabel,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
            if (showResults) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 5,
                  backgroundColor: Colors.grey[300],
                  color: isVoted ? const Color(0xFF185FA5) : Colors.grey[500],
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final bool isClosing;
  final VoidCallback onClose;

  const _CloseButton({required this.isClosing, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isClosing ? null : onClose,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: isClosing
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            : Text(
                'Close poll',
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
      ),
    );
  }
}
