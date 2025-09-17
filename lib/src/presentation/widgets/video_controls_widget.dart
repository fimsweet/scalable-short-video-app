import 'package:flutter/material.dart';

class VideoControlsWidget extends StatelessWidget {
  final VoidCallback onCommentTap;
  final VoidCallback onMoreTap;

  const VideoControlsWidget({
    super.key,
    required this.onCommentTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ControlButton(icon: Icons.favorite, label: '4.820'),
          const SizedBox(height: 20),
          _ControlButton(
            icon: Icons.comment,
            label: '306',
            onTap: onCommentTap,
          ),
          const SizedBox(height: 20),
          const _ControlButton(icon: Icons.send, label: '9.438'),
          const SizedBox(height: 20),
          _ControlButton(
            icon: Icons.more_horiz,
            onTap: onMoreTap,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 35),
          if (label != null) ...[
            const SizedBox(height: 5),
            Text(
              label!,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}
