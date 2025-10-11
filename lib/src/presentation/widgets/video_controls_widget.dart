import 'package:flutter/material.dart';

class VideoControlsWidget extends StatelessWidget {
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onMoreTap;
  final VoidCallback onShareTap;
  final bool isLiked;
  final String likeCount;
  final String commentCount;

  const VideoControlsWidget({
    super.key,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onMoreTap,
    required this.onShareTap,
    this.isLiked = false,
    this.likeCount = '0',
    this.commentCount = '0',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIconButton(
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            label: likeCount,
            onTap: onLikeTap,
            color: isLiked ? Colors.red : Colors.white,
          ),
          const SizedBox(height: 16),
          _buildIconButton(
            icon: Icons.mode_comment_outlined,
            label: commentCount,
            onTap: onCommentTap,
          ),
          const SizedBox(height: 16),
          _buildIconButton(icon: Icons.send, label: '', onTap: onShareTap),
          const SizedBox(height: 16),
          _buildIconButton(icon: Icons.more_horiz, label: '', onTap: onMoreTap),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ]
        ],
      ),
    );
  }
}
