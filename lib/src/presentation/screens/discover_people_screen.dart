import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/config/app_config.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';

/// Full screen page showing all suggested users to follow
/// Implements TikTok-style discovery with slide animation
class DiscoverPeopleScreen extends StatefulWidget {
  const DiscoverPeopleScreen({super.key});

  @override
  State<DiscoverPeopleScreen> createState() => _DiscoverPeopleScreenState();
}

class _DiscoverPeopleScreenState extends State<DiscoverPeopleScreen> {
  final FollowService _followService = FollowService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final AuthService _authService = AuthService();
  final ScrollController _scrollController = ScrollController();

  List<SuggestedUser> _suggestions = [];
  final Set<int> _followedIds = {};
  final Set<int> _dismissedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _loadSuggestions();
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSuggestions() async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _authService.user!['id'] as int;
      // Get more suggestions for the full page
      final suggestions = await _followService.getSuggestions(userId, limit: 50);

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

  String _getAvatarUrl(String? avatar) {
    if (avatar == null || avatar.isEmpty) return '';
    if (avatar.startsWith('http')) return avatar;
    return '${AppConfig.userServiceUrl}$avatar';
  }

  @override
  Widget build(BuildContext context) {
    final visibleSuggestions = _suggestions
        .where((s) => !_dismissedIds.contains(s.id))
        .toList();

    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _themeService.iconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _localeService.get('discover_people'),
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: _themeService.textPrimaryColor,
                strokeWidth: 2,
              ),
            )
          : visibleSuggestions.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadSuggestions,
                  color: ThemeService.accentColor,
                  child: GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: visibleSuggestions.length,
                    itemBuilder: (context, index) {
                      final user = visibleSuggestions[index];
                      return _SuggestionGridCard(
                        user: user,
                        isFollowed: _followedIds.contains(user.id),
                        onFollow: () => _toggleFollow(user),
                        onDismiss: () => _dismissSuggestion(user.id),
                        onTap: () => _navigateToProfile(user),
                        themeService: _themeService,
                        localeService: _localeService,
                        getAvatarUrl: _getAvatarUrl,
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: _themeService.textSecondaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              _localeService.get('no_suggestions_title'),
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _localeService.get('no_suggestions_desc'),
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _loadSuggestions,
              icon: Icon(Icons.refresh, color: ThemeService.accentColor),
              label: Text(
                _localeService.get('refresh'),
                style: TextStyle(
                  color: ThemeService.accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid card for suggestion
class _SuggestionGridCard extends StatelessWidget {
  final SuggestedUser user;
  final bool isFollowed;
  final VoidCallback onFollow;
  final VoidCallback onDismiss;
  final VoidCallback onTap;
  final ThemeService themeService;
  final LocaleService localeService;
  final String Function(String?) getAvatarUrl;

  const _SuggestionGridCard({
    required this.user,
    required this.isFollowed,
    required this.onFollow,
    required this.onDismiss,
    required this.onTap,
    required this.themeService,
    required this.localeService,
    required this.getAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: themeService.isLightMode 
            ? Colors.grey[100] 
            : const Color(0xFF262626),
        borderRadius: BorderRadius.circular(16),
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
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
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
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: themeService.isLightMode
                            ? Colors.grey[200]
                            : Colors.grey[700],
                        backgroundImage: user.avatar != null && user.avatar!.isNotEmpty && getAvatarUrl(user.avatar).isNotEmpty
                            ? NetworkImage(getAvatarUrl(user.avatar))
                            : null,
                        child: user.avatar == null || user.avatar!.isEmpty || getAvatarUrl(user.avatar).isEmpty
                            ? Icon(
                                Icons.person,
                                size: 48,
                                color: themeService.textSecondaryColor,
                              )
                            : null,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Name
                    Text(
                      user.fullName ?? user.username,
                      style: TextStyle(
                        color: themeService.textPrimaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 4),

                    // Reason
                    Text(
                      user.getReasonText(localeService.get, isVietnamese: localeService.isVietnamese),
                      style: TextStyle(
                        color: themeService.textSecondaryColor,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),

                    const Spacer(),

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
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          isFollowed
                              ? localeService.get('followed')
                              : localeService.get('follow'),
                          style: const TextStyle(
                            fontSize: 14,
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
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onDismiss,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: themeService.isLightMode 
                      ? Colors.grey[200] 
                      : Colors.grey[800],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.close,
                  size: 16,
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
