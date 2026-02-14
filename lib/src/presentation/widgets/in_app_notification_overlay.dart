import 'dart:async';
import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/in_app_notification_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';

/// Overlay widget that displays in-app notification banners at the top of the screen.
/// Inspired by TikTok/Instagram — small, non-intrusive, auto-dismiss with swipe-to-dismiss.
class InAppNotificationOverlay extends StatefulWidget {
  final Widget child;
  final void Function(InAppNotification notification)? onTap;

  const InAppNotificationOverlay({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  State<InAppNotificationOverlay> createState() =>
      InAppNotificationOverlayState();
}

class InAppNotificationOverlayState extends State<InAppNotificationOverlay> {
  final InAppNotificationService _service = InAppNotificationService();
  StreamSubscription<InAppNotification>? _subscription;
  
  // Currently showing notification
  InAppNotification? _currentNotification;
  
  // Animation
  final GlobalKey<_BannerWidgetState> _bannerKey = GlobalKey<_BannerWidgetState>();

  @override
  void initState() {
    super.initState();
    _subscription = _service.notificationStream.listen(_onNotification);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onNotification(InAppNotification notification) {
    if (!mounted) return;
    
    // If a banner is already showing, dismiss it first
    if (_currentNotification != null) {
      _bannerKey.currentState?.dismiss();
      // Small delay to let dismiss animation play
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() => _currentNotification = notification);
        }
      });
    } else {
      setState(() => _currentNotification = notification);
    }
  }

  void _onDismissed() {
    if (mounted) {
      setState(() => _currentNotification = null);
    }
  }

  void _onBannerTap() {
    if (_currentNotification != null) {
      widget.onTap?.call(_currentNotification!);
      _bannerKey.currentState?.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentNotification != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _BannerWidget(
              key: _bannerKey,
              notification: _currentNotification!,
              onDismissed: _onDismissed,
              onTap: _onBannerTap,
            ),
          ),
      ],
    );
  }
}

/// The actual banner widget with slide-in/out animation
class _BannerWidget extends StatefulWidget {
  final InAppNotification notification;
  final VoidCallback onDismissed;
  final VoidCallback onTap;

  const _BannerWidget({
    super.key,
    required this.notification,
    required this.onDismissed,
    required this.onTap,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;
  final ApiService _apiService = ApiService();

  /// Auto-dismiss duration (like TikTok — short, non-intrusive)
  static const Duration _displayDuration = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Animate in
    _controller.forward();
    
    // Auto-dismiss after delay
    _autoDismissTimer = Timer(_displayDuration, dismiss);
  }

  void dismiss() {
    _autoDismissTimer?.cancel();
    if (_controller.isAnimating || !mounted) return;
    _controller.reverse().then((_) {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  IconData _getIcon() {
    switch (widget.notification.type) {
      case InAppNotificationType.like:
        return Icons.favorite;
      case InAppNotificationType.comment:
        return Icons.chat_bubble;
      case InAppNotificationType.follow:
        return Icons.person_add;
      case InAppNotificationType.mention:
        return Icons.alternate_email;
      case InAppNotificationType.message:
        return Icons.mail;
    }
  }

  Color _getIconColor() {
    switch (widget.notification.type) {
      case InAppNotificationType.like:
        return const Color(0xFFFF2D55);
      case InAppNotificationType.comment:
        return const Color(0xFF5AC8FA);
      case InAppNotificationType.follow:
        return const Color(0xFF34C759);
      case InAppNotificationType.mention:
        return const Color(0xFFFF9500);
      case InAppNotificationType.message:
        return ThemeService.accentColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final topPadding = MediaQuery.of(context).padding.top;
    final isDark = !themeService.isLightMode;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          onVerticalDragEnd: (details) {
            // Swipe up to dismiss (like TikTok)
            if (details.velocity.pixelsPerSecond.dy < -100) {
              dismiss();
            }
          },
          child: Container(
            padding: EdgeInsets.only(top: topPadding + 4),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2C2C2E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // Avatar or icon
                        _buildLeading(isDark),
                        const SizedBox(width: 12),
                        // Text content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.notification.title,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.notification.body,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Type indicator icon (small, subtle)
                        Icon(
                          _getIcon(),
                          color: _getIconColor(),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(bool isDark) {
    final avatarUrl = widget.notification.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    if (hasAvatar) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
        child: null,
      );
    }

    // Fallback: icon with colored background
    return CircleAvatar(
      radius: 20,
      backgroundColor: _getIconColor().withValues(alpha: 0.15),
      child: Icon(
        _getIcon(),
        color: _getIconColor(),
        size: 20,
      ),
    );
  }
}
