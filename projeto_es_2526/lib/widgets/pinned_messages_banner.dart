import 'package:flutter/material.dart';

import '../models/pinned_message.dart';
import '../utils/avatar_utils.dart';

class PinnedMessagesBanner extends StatefulWidget {
  final List<PinnedMessage> pinnedMessages;
  final bool canUnpin;
  final void Function(String messageId) onUnpin;
  final void Function(String messageId) onNavigate;

  const PinnedMessagesBanner({
    super.key,
    required this.pinnedMessages,
    required this.canUnpin,
    required this.onUnpin,
    required this.onNavigate,
  });

  @override
  State<PinnedMessagesBanner> createState() => _PinnedMessagesBannerState();
}

class _PinnedMessagesBannerState extends State<PinnedMessagesBanner> {
  bool _expanded = false;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_months[dt.month - 1]}, $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.pinnedMessages.length;
    if (count == 0) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF0F5FF),
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(count),
            if (_expanded) _buildPinnedList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.push_pin, size: 16, color: Color(0xFF185FA5)),
            const SizedBox(width: 8),
            Text(
              '$count pinned ${count == 1 ? 'message' : 'messages'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF185FA5),
              ),
            ),
            const Spacer(),
            // Show snippet of the latest pinned message when collapsed
            if (!_expanded)
              Flexible(
                child: Text(
                  widget.pinnedMessages.first.text,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: Colors.grey[500],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: widget.pinnedMessages.length,
      separatorBuilder: (context, i) =>
          Divider(height: 1, color: Colors.grey[200]),
      itemBuilder: (context, index) =>
          _buildPinnedItem(widget.pinnedMessages[index]),
    );
  }

  Widget _buildPinnedItem(PinnedMessage pinned) {
    final dt = pinned.messageTimestamp.toDate();

    return InkWell(
      onTap: () => widget.onNavigate(pinned.messageId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarUtils.buildAvatarFromAsset(
              AvatarUtils.assetForIndex(pinned.senderAvatarIndex),
              32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        pinned.senderNickname,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF185FA5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTimestamp(dt),
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pinned.text,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (widget.canUnpin)
              IconButton(
                icon: Icon(Icons.push_pin_outlined,
                    size: 18, color: Colors.grey[500]),
                tooltip: 'Unpin',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => widget.onUnpin(pinned.messageId),
              ),
          ],
        ),
      ),
    );
  }
}
