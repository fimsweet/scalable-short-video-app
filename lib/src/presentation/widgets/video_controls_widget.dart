import 'package:flutter/material.dart';

class VideoControlsWidget extends StatefulWidget {
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onSaveTap;
  final VoidCallback onShareTap;
  final bool isLiked;
  final bool isSaved;
  final String likeCount;
  final String commentCount;
  final String saveCount;
  final String shareCount; // NEW

  const VideoControlsWidget({
    super.key,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onSaveTap,
    required this.onShareTap,
    this.isLiked = false,
    this.isSaved = false,
    this.likeCount = '0',
    this.commentCount = '0',
    this.saveCount = '0',
    this.shareCount = '0', // NEW
  });

  @override
  State<VideoControlsWidget> createState() => _VideoControlsWidgetState();
}

class _VideoControlsWidgetState extends State<VideoControlsWidget>
    with TickerProviderStateMixin {
  late AnimationController _likeController;
  late AnimationController _saveController;
  late Animation<double> _likeScaleAnimation;
  late Animation<double> _saveScaleAnimation;

  @override
  void initState() {
    super.initState();
    _likeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _saveController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _likeScaleAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
      ],
    ).animate(CurvedAnimation(
      parent: _likeController,
      curve: Curves.easeInOut,
    ));

    _saveScaleAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
      ],
    ).animate(CurvedAnimation(
      parent: _saveController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _likeController.dispose();
    _saveController.dispose();
    super.dispose();
  }

  void _onLikeTap() {
    _likeController.forward(from: 0);
    widget.onLikeTap();
  }

  void _onSaveTap() {
    _saveController.forward(from: 0);
    widget.onSaveTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Like button with animation
            _buildAnimatedIconButton(
              animation: _likeScaleAnimation,
              icon: widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              label: widget.likeCount,
              onTap: _onLikeTap,
              color: widget.isLiked ? const Color(0xFFFF2D55) : Colors.white,
              isActive: widget.isLiked,
            ),
            const SizedBox(height: 20),
            // Comment button
            _buildIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: widget.commentCount,
              onTap: widget.onCommentTap,
            ),
            const SizedBox(height: 20),
            // Save button with animation - NOW WITH COUNT
            _buildAnimatedIconButton(
              animation: _saveScaleAnimation,
              icon: widget.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              label: widget.saveCount,
              onTap: _onSaveTap,
              color: widget.isSaved ? const Color(0xFFFFC107) : Colors.white,
              isActive: widget.isSaved,
            ),
            const SizedBox(height: 20),
            // Share button - NOW WITH COUNT
            _buildIconButton(
              icon: Icons.send_rounded,
              label: widget.shareCount, // Changed from ''
              onTap: widget.onShareTap,
              rotationAngle: -0.4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedIconButton({
    required Animation<double> animation,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Transform.scale(
                scale: animation.value,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: child,
                    );
                  },
                  child: Icon(
                    icon,
                    key: ValueKey('$icon-$isActive'),
                    color: color,
                    size: 34,
                    shadows: const [
                      Shadow(
                        blurRadius: 8.0,
                        color: Colors.black54,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    blurRadius: 8.0,
                    color: Colors.black87,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color color = Colors.white,
    double rotationAngle = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: rotationAngle,
            child: Icon(
              icon,
              color: color,
              size: 32,
              shadows: const [
                Shadow(
                  blurRadius: 8.0,
                  color: Colors.black54,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    blurRadius: 8.0,
                    color: Colors.black87,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
