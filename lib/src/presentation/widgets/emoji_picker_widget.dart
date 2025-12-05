import 'package:flutter/material.dart';

class EmojiPickerWidget extends StatelessWidget {
  final Function(String) onEmojiSelected;
  final VoidCallback? onClose;

  const EmojiPickerWidget({
    super.key,
    required this.onEmojiSelected,
    this.onClose,
  });

  static const List<String> smileys = [
    '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂',
    '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '🤩',
    '😘', '😗', '☺️', '😚', '😙', '🥲', '😋', '😛',
    '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
  ];

  static const List<String> gestures = [
    '👍', '👎', '👊', '✊', '🤛', '🤜', '👏', '🙌',
    '👐', '🤲', '🤝', '🙏', '✌️', '🤞', '🤟', '🤘',
    '👌', '🤌', '🤏', '👈', '👉', '👆', '👇', '☝️',
    '✋', '🤚', '🖐️', '🖖', '👋', '🤙', '💪', '🦾',
  ];

  static const List<String> hearts = [
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
    '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖',
    '💘', '💝', '💟', '♥️', '🫶', '🫀', '💌', '💋',
  ];

  static const List<String> symbols = [
    '🔥', '✨', '⭐', '🌟', '💫', '🎉', '🎊', '🎁',
    '🏆', '🥇', '🥈', '🥉', '🏅', '🎯', '💯', '✅',
    '❌', '❓', '❗', '💬', '👀', '👁️', '🔔', '🔕',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Emoji tabs
          Expanded(
            child: DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  TabBar(
                    indicatorColor: Colors.blue,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey[600],
                    tabs: const [
                      Tab(icon: Icon(Icons.emoji_emotions_outlined, size: 20)),
                      Tab(icon: Icon(Icons.front_hand_outlined, size: 20)),
                      Tab(icon: Icon(Icons.favorite_outline, size: 20)),
                      Tab(icon: Icon(Icons.star_outline, size: 20)),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildEmojiGrid(smileys),
                        _buildEmojiGrid(gestures),
                        _buildEmojiGrid(hearts),
                        _buildEmojiGrid(symbols),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildEmojiGrid(List<String> emojis) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => onEmojiSelected(emojis[index]),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                emojis[index],
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
        );
      },
    );
  }
}
