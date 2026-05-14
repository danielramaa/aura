import 'package:flutter/material.dart';

const List<String> kPickerEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

class EmojiPickerSheet extends StatelessWidget {
  final String? currentEmoji;
  final ValueChanged<String> onEmojiSelected;

  const EmojiPickerSheet({
    super.key,
    required this.currentEmoji,
    required this.onEmojiSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
        children: kPickerEmojis.map((emoji) {
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
