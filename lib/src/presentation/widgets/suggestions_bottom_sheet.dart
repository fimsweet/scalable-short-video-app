import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/config/app_config.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';

class SuggestionsBottomSheet extends StatefulWidget {
  const SuggestionsBottomSheet({super.key});

  @override
  State<SuggestionsBottomSheet> createState() => _SuggestionsBottomSheetState();
}

class _SuggestionsBottomSheetState extends State<SuggestionsBottomSheet> {
  final FollowService _followService = FollowService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final AuthService _authService = AuthService();

  List<SuggestedUser> _suggestions = [];
  Set<int> _followedIds = {};
  Set<int> _requestedIds = {};
  Set<int> _dismissedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    if (!_authService.isLoggedIn || _authService.user == null) return;

    setState(() => _isLoading = true);

    try {
      final userId = _authService.user!['id'] as int;
      final suggestions = await _followService.getSuggestions(userId);

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading suggestions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFollow(SuggestedUser user) async {
    if (!_authService.isLoggedIn || _authService.user == null) return;

    final myId = _authService.user!['id'] as int;
    final isFollowed = _followedIds.contains(user.id);
    final wasRequested = _requestedIds.contains(user.id);

    // Optimistic update
    setState(() {
      _followedIds.remove(user.id);
      _requestedIds.remove(user.id);
      if (!isFollowed && !wasRequested) {
        _followedIds.add(user.id);
      }
    });

    try {
      final result = await _followService.toggleFollow(myId, user.id);
      if (mounted) {
        setState(() {
          _followedIds.remove(user.id);
          _requestedIds.remove(user.id);
          if (result['following'] == true) {
            _followedIds.add(user.id);
          } else if (result['requested'] == true) {
            _requestedIds.add(user.id);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _followedIds.remove(user.id);
          _requestedIds.remove(user.id);
          if (isFollowed) _followedIds.add(user.id);
          if (wasRequested) _requestedIds.add(user.id);
        });
      }
    }
  }

  void _dismissSuggestion(int userId) {
    setState(() {
      _dismissedIds.add(userId);
    });
  }

  void _navigateToProfile(SuggestedUser user) {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: user.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleSuggestions = _suggestions
        .where((s) => !_dismissedIds.contains(s.id))
        .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: _themeService.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: _themeService.textSecondaryColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  _localeService.get('discover_people'),
                  style: TextStyle(
                    color: _themeService.textPrimaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    _localeService.get('done'),
                    style: TextStyle(
                      color: ThemeService.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Suggestions list
          Flexible(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: ThemeService.accentColor),
                    ),
                  )
                : visibleSuggestions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: _themeService.textSecondaryColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _localeService.get('no_suggestions'),
                                style: TextStyle(
                                  color: _themeService.textSecondaryColor,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: visibleSuggestions.length,
                        itemBuilder: (context, index) {
                          final user = visibleSuggestions[index];
                          return _SuggestionCard(
                            user: user,
                            isFollowed: _followedIds.contains(user.id),
                            isRequested: _requestedIds.contains(user.id),
                            onFollow: () => _toggleFollow(user),
                            onDismiss: () => _dismissSuggestion(user.id),
                            onTap: () => _navigateToProfile(user),
                            themeService: _themeService,
                            localeService: _localeService,
                          );
                        },
                      ),
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final SuggestedUser user;
  final bool isFollowed;
  final bool isRequested;
  final VoidCallback onFollow;
  final VoidCallback onDismiss;
  final VoidCallback onTap;
  final ThemeService themeService;
  final LocaleService localeService;

  const _SuggestionCard({
    required this.user,
    required this.isFollowed,
    required this.isRequested,
    required this.onFollow,
    required this.onDismiss,
    required this.onTap,
    required this.themeService,
    required this.localeService,
  });

  String _getAvatarUrl(String? avatar) {
    if (avatar == null || avatar.isEmpty) return '';
    if (avatar.startsWith('http')) return avatar;
    return '${AppConfig.userServiceUrl}$avatar';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: themeService.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: themeService.isLightMode
                          ? Colors.grey[200]
                          : Colors.grey[700],
                      backgroundImage: user.avatar != null && user.avatar!.isNotEmpty && _getAvatarUrl(user.avatar).isNotEmpty
                          ? NetworkImage(_getAvatarUrl(user.avatar))
                          : null,
                      child: user.avatar == null || user.avatar!.isEmpty || _getAvatarUrl(user.avatar).isEmpty
                          ? Icon(
                              Icons.person,
                              size: 32,
                              color: themeService.textSecondaryColor,
                            )
                          : null,
                    ),
                    // Add badge for mutual friends
                    if (user.mutualFriendsCount > 0)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: ThemeService.accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: themeService.cardColor,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.people,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 12),

                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName ?? user.username,
                        style: TextStyle(
                          color: themeService.textPrimaryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${user.username}',
                        style: TextStyle(
                          color: themeService.textSecondaryColor,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.getReasonText(localeService.get, isVietnamese: localeService.isVietnamese),
                        style: TextStyle(
                          color: themeService.textSecondaryColor.withOpacity(0.8),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Follow button
                _FollowButton(
                  isFollowed: isFollowed,
                  isRequested: isRequested,
                  onPressed: onFollow,
                  themeService: themeService,
                  localeService: localeService,
                ),

                // Dismiss button
                IconButton(
                  onPressed: onDismiss,
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: themeService.textSecondaryColor,
                  ),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool isFollowed;
  final bool isRequested;
  final VoidCallback onPressed;
  final ThemeService themeService;
  final LocaleService localeService;

  const _FollowButton({
    required this.isFollowed,
    required this.isRequested,
    required this.onPressed,
    required this.themeService,
    required this.localeService,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isRequested
              ? (themeService.isLightMode ? Colors.orange[50] : Colors.orange.withValues(alpha: 0.15))
              : isFollowed
                  ? (themeService.isLightMode ? Colors.grey[200] : Colors.grey[700])
                  : ThemeService.accentColor,
          foregroundColor: isRequested
              ? Colors.orange
              : isFollowed
                  ? themeService.textPrimaryColor
                  : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: const Size(80, 36),
        ),
        child: Text(
          isRequested
              ? localeService.get('requested')
              : isFollowed
                  ? localeService.get('followed')
                  : localeService.get('follow'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
