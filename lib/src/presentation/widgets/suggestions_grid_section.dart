import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/config/app_config.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';

/// Instagram-style horizontal grid suggestions section
class SuggestionsGridSection extends StatefulWidget {
  final VoidCallback? onSeeAll;
  
  const SuggestionsGridSection({super.key, this.onSeeAll});

  @override
  State<SuggestionsGridSection> createState() => _SuggestionsGridSectionState();
}

class _SuggestionsGridSectionState extends State<SuggestionsGridSection> {
  final FollowService _followService = FollowService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final AuthService _authService = AuthService();

  List<SuggestedUser> _suggestions = [];
  Set<int> _followedIds = {};
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

    setState(() {
      if (isFollowed) {
        _followedIds.remove(user.id);
      } else {
        _followedIds.add(user.id);
      }
    });

    try {
      await _followService.toggleFollow(myId, user.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          if (isFollowed) {
            _followedIds.add(user.id);
          } else {
            _followedIds.remove(user.id);
          }
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: user.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleSuggestions = _suggestions
        .where((s) => !_dismissedIds.contains(s.id))
        .toList();

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _themeService.textSecondaryColor,
            ),
          ),
        ),
      );
    }

    if (visibleSuggestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            _localeService.get('no_suggestions'),
            style: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: "Khám phá mọi người" + "Xem tất cả"
        // No horizontal padding here - parent already has padding: 16
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _localeService.get('discover_people'),
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: widget.onSeeAll,
                child: Text(
                  _localeService.get('see_all'),
                  style: TextStyle(
                    color: ThemeService.accentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal scrollable cards - negative margin to extend to edges
        Transform.translate(
          offset: const Offset(-16, 0),
          child: SizedBox(
            width: MediaQuery.of(context).size.width + 16,
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(left: 16, right: 16),
              itemCount: visibleSuggestions.length,
              itemBuilder: (context, index) {
                final user = visibleSuggestions[index];
                return _SuggestionCard(
                  user: user,
                  isFollowed: _followedIds.contains(user.id),
                  onFollow: () => _toggleFollow(user),
                  onDismiss: () => _dismissSuggestion(user.id),
                  onTap: () => _navigateToProfile(user),
                  themeService: _themeService,
                  localeService: _localeService,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Instagram-style suggestion card
class _SuggestionCard extends StatelessWidget {
  final SuggestedUser user;
  final bool isFollowed;
  final VoidCallback onFollow;
  final VoidCallback onDismiss;
  final VoidCallback onTap;
  final ThemeService themeService;
  final LocaleService localeService;

  const _SuggestionCard({
    required this.user,
    required this.isFollowed,
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
      width: 170,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: themeService.isLightMode 
            ? Colors.grey[100] 
            : const Color(0xFF262626),
        borderRadius: BorderRadius.circular(12),
        border: themeService.isLightMode
            ? Border.all(color: Colors.grey[300]!, width: 0.5)
            : null,
      ),
      child: Stack(
        children: [
          // Main content
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Avatar
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: themeService.isLightMode
                              ? Colors.grey[300]!
                              : Colors.grey[600]!,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: themeService.isLightMode
                            ? Colors.grey[200]
                            : Colors.grey[700],
                        backgroundImage: user.avatar != null && user.avatar!.isNotEmpty && _getAvatarUrl(user.avatar).isNotEmpty
                            ? NetworkImage(_getAvatarUrl(user.avatar))
                            : null,
                        child: user.avatar == null || user.avatar!.isEmpty || _getAvatarUrl(user.avatar).isEmpty
                            ? Icon(
                                Icons.person,
                                size: 40,
                                color: themeService.textSecondaryColor,
                              )
                            : null,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Name
                    Text(
                      user.fullName ?? user.username,
                      style: TextStyle(
                        color: themeService.textPrimaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 2),

                    // Reason
                    Text(
                      user.getReasonText(localeService.get),
                      style: TextStyle(
                        color: themeService.textSecondaryColor,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    // Follow button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowed
                              ? (themeService.isLightMode 
                                  ? Colors.grey[200] 
                                  : Colors.grey[700])
                              : ThemeService.accentColor,
                          foregroundColor: isFollowed
                              ? themeService.textPrimaryColor
                              : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isFollowed
                              ? localeService.get('followed')
                              : localeService.get('follow'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Dismiss button (X)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onDismiss,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: themeService.textSecondaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
