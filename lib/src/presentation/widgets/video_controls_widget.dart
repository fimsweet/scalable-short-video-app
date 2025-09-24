import 'package:flutter/material.dart';

class VideoControlsWidget extends StatelessWidget {
  final VoidCallback onCommentTap;
  final VoidCallback onMoreTap;
  final VoidCallback onShareTap;

  const VideoControlsWidget({
    super.key,
    required this.onCommentTap,
    required this.onMoreTap,
    required this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIconButton(icon: Icons.favorite, label: '4.820'),
          const SizedBox(height: 16),
          _buildIconButton(
              icon: Icons.comment_bank, label: '306', onTap: onCommentTap),
          const SizedBox(height: 16),
          _buildIconButton(icon: Icons.send, label: '9.438', onTap: onShareTap),
          const SizedBox(height: 16),
          _buildIconButton(icon: Icons.more_horiz, label: '', onTap: onMoreTap),
        ],
      ),
    );
  }

  Widget _buildIconButton(
      {required IconData icon,
      required String label,
      VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 32),
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
