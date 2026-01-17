import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;
  
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final FollowService _followService = FollowService();
  final VideoService _videoService = VideoService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();

  Map<String, dynamic>? _userInfo;
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isMutual = false;
  bool _isProcessing = false;
  bool _isBlocked = false;
  int _followerCount = 0;
  int _followingCount = 0;
  List<dynamic> _userVideos = [];

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _loadUserData();
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      // Load user info
      final userInfo = await _apiService.getUserById(widget.userId.toString());
      
      // Load follow stats
      final stats = await _followService.getStats(widget.userId);
      
      // Load user videos
      final videos = await _videoService.getVideosByUserId(widget.userId.toString());

      // Check follow status and block status
      if (_authService.isLoggedIn && _authService.user != null) {
        final currentUserId = _authService.user!['id'] as int;
        final isFollowing = await _followService.isFollowing(currentUserId, widget.userId);
        final isMutual = await _followService.isMutualFollow(currentUserId, widget.userId);
        
        // Safely check blocked status with fallback
        bool isBlocked = false;
        try {
          isBlocked = await _apiService.isUserBlocked(
            currentUserId.toString(), 
            widget.userId.toString(),
          );
        } catch (e) {
          print('❌ Error checking blocked status: $e');
        }
        
        if (mounted) {
          setState(() {
            _isFollowing = isFollowing;
            _isMutual = isMutual;
            _isBlocked = isBlocked;
          });
        }
      }

      if (mounted) {
        setState(() {
          _userInfo = userInfo;
          _followerCount = stats['followerCount'] ?? 0;
          _followingCount = stats['followingCount'] ?? 0;
          _userVideos = videos;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_localeService.get('please_login_to_follow'))),
      );
      return;
    }

    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    final currentUserId = _authService.user!['id'] as int;
    final result = await _followService.toggleFollow(currentUserId, widget.userId);

    if (mounted) {
      final newFollowing = result['following'] ?? false;
      final isMutual = newFollowing 
          ? await _followService.isMutualFollow(currentUserId, widget.userId)
          : false;
      
      setState(() {
        _isFollowing = newFollowing;
        _isMutual = isMutual;
        _followerCount += newFollowing ? 1 : -1;
        _isProcessing = false;
      });
    }
  }

  void _showOptionsMenu() {
    if (!_authService.isLoggedIn) return;
    
    final username = _userInfo?['username'] ?? 'user';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _themeService.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Block/Unblock option
              _buildOptionTile(
                icon: _isBlocked ? Icons.remove_circle_outline : Icons.block_rounded,
                iconColor: _isBlocked ? Colors.green : Colors.red,
                title: _isBlocked 
                    ? _localeService.get('unblock_user')
                    : _localeService.get('block_user'),
                titleColor: _isBlocked ? Colors.green : Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _showBlockConfirmDialog(username);
                },
              ),
              
              // Report option
              _buildOptionTile(
                icon: Icons.flag_outlined,
                iconColor: Colors.orange,
                title: _localeService.get('report'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_localeService.isVietnamese 
                          ? 'Đã gửi báo cáo' 
                          : 'Report submitted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
              
              // Copy profile link
              _buildOptionTile(
                icon: Icons.link_rounded,
                title: _localeService.isVietnamese ? 'Sao chép liên kết' : 'Copy link',
                onTap: () {
                  Navigator.pop(context);
                  _copyProfileLink(username);
                },
              ),
              
              // Share profile
              _buildOptionTile(
                icon: Icons.share_outlined,
                title: _localeService.get('share_profile'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement share functionality
                },
              ),
              
              const SizedBox(height: 8),
              
              // Cancel button
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _localeService.get('cancel'),
                    style: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? _themeService.textPrimaryColor).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? _themeService.textPrimaryColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? _themeService.textPrimaryColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showBlockConfirmDialog(String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _isBlocked
              ? '${_localeService.get('unblock_confirm')} @$username?'
              : '${_localeService.get('block_confirm')} @$username?',
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          _isBlocked
              ? _localeService.get('unblock_effects')
              : _localeService.get('block_effects'),
          style: TextStyle(
            color: _themeService.textSecondaryColor,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _localeService.get('cancel'),
              style: TextStyle(color: _themeService.textSecondaryColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleBlock();
            },
            child: Text(
              _isBlocked 
                  ? _localeService.get('unblock')
                  : _localeService.get('block'),
              style: TextStyle(
                color: _isBlocked ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBlock() async {
    if (!_authService.isLoggedIn || _authService.user == null) return;
    
    final currentUserId = _authService.user!['id'].toString();
    final targetUserId = widget.userId.toString();
    
    bool success;
    if (_isBlocked) {
      success = await _apiService.unblockUser(targetUserId, currentUserId: currentUserId);
    } else {
      success = await _apiService.blockUser(targetUserId, currentUserId: currentUserId);
    }
    
    if (mounted) {
      if (success) {
        setState(() {
          _isBlocked = !_isBlocked;
          // If blocking, also unfollow
          if (_isBlocked && _isFollowing) {
            _isFollowing = false;
            _followerCount--;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isBlocked 
                ? _localeService.get('blocked_success')
                : _localeService.get('unblocked_success')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isBlocked 
                ? _localeService.get('unblock_failed')
                : _localeService.get('block_failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyProfileLink(String username) {
    final profileLink = 'https://shortvideo.app/@$username';
    Clipboard.setData(ClipboardData(text: profileLink));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_localeService.isVietnamese 
            ? 'Đã sao chép liên kết' 
            : 'Link copied'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = _authService.isLoggedIn && 
        _authService.user != null && 
        _authService.user!['id'] == widget.userId;

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
          _userInfo?['username'] ?? '...',
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz, color: _themeService.iconColor),
            onPressed: _showOptionsMenu,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _themeService.textPrimaryColor))
          : _userInfo == null
              ? Center(
                  child: Text(
                    _localeService.get('user_not_found'),
                    style: TextStyle(color: _themeService.textPrimaryColor),
                  ),
                )
              : DefaultTabController(
                  length: 1,
                  child: NestedScrollView(
                    headerSliverBuilder: (context, _) => [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            // Avatar
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _themeService.isLightMode ? Colors.grey[300]! : Colors.grey[900]!,
                                  width: 1,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 48,
                                backgroundColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[900],
                                backgroundImage: _userInfo!['avatar'] != null
                                    ? NetworkImage(_apiService.getAvatarUrl(_userInfo!['avatar']))
                                    : null,
                                child: _userInfo!['avatar'] == null
                                    ? Icon(Icons.person, size: 48, color: _themeService.textSecondaryColor)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Username
                            Text(
                              '@${_userInfo!['username'] ?? 'user'}',
                              style: TextStyle(
                                color: _themeService.textPrimaryColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Stats
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildStatItem(_followingCount.toString(), _localeService.get('following')),
                                _buildDivider(),
                                _buildStatItem(_followerCount.toString(), _localeService.get('followers')),
                                _buildDivider(),
                                _buildStatItem(_userVideos.length.toString(), _localeService.get('likes')),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // Action Buttons
                            if (!isOwnProfile)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 48),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildFollowButton(),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildMessageButton(),
                                    ),
                                  ],
                                ),
                              ),
                            
                            const SizedBox(height: 24),
                            
                            // Bio
                            if (_userInfo!['bio'] != null && _userInfo!['bio'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  _userInfo!['bio'],
                                  style: TextStyle(color: _themeService.textPrimaryColor, fontSize: 14),
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                    body: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _themeService.isLightMode ? Colors.grey[300]! : Colors.grey[900]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: TabBar(
                            indicatorColor: _themeService.textPrimaryColor,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicatorWeight: 2,
                            labelColor: _themeService.textPrimaryColor,
                            unselectedLabelColor: _themeService.textSecondaryColor,
                            tabs: const [
                              Tab(icon: Icon(Icons.grid_on)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildVideoGrid(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: _themeService.textSecondaryColor,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 16,
      width: 1,
      color: _themeService.isLightMode ? Colors.grey[400] : Colors.grey[800],
      margin: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  Widget _buildFollowButton() {
    // In light mode: white background with border (like Edit button)
    // In dark mode: grey background
    // For Follow (not following): always use pink color
    final isFollowingState = _isFollowing;
    
    return GestureDetector(
      onTap: _isProcessing ? null : _toggleFollow,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isFollowingState 
              ? (_themeService.isLightMode ? Colors.white : Colors.grey[800])
              : const Color(0xFFFF2D55),
          borderRadius: BorderRadius.circular(4),
          border: isFollowingState && _themeService.isLightMode
              ? Border.all(color: Colors.grey[300]!, width: 1)
              : null,
        ),
        alignment: Alignment.center,
        child: _isProcessing
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _themeService.textPrimaryColor),
              )
            : Text(
                _isMutual ? _localeService.get('friends') : (isFollowingState ? _localeService.get('following_status') : _localeService.get('follow')),
                style: TextStyle(
                  color: isFollowingState 
                      ? _themeService.textPrimaryColor 
                      : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }

  Widget _buildMessageButton() {
    return GestureDetector(
      onTap: () {
        if (_userInfo == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              recipientId: widget.userId.toString(),
              recipientUsername: _userInfo!['username'] ?? 'User',
              recipientAvatar: _userInfo!['avatar'] != null 
                  ? _apiService.getAvatarUrl(_userInfo!['avatar']) 
                  : null,
            ),
          ),
        );
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: _themeService.isLightMode ? Colors.white : Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
          border: _themeService.isLightMode
              ? Border.all(color: Colors.grey[300]!, width: 1)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          _localeService.get('message'),
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoGrid() {
    if (_userVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 64, color: _themeService.textSecondaryColor),
            const SizedBox(height: 16),
            Text(
              _localeService.get('no_videos'),
              style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: 3/4,
      ),
      itemCount: _userVideos.length,
      itemBuilder: (context, index) {
        final video = _userVideos[index];
        final thumbnailUrl = video['thumbnailUrl'] != null
            ? _videoService.getVideoUrl(video['thumbnailUrl'])
            : null;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoDetailScreen(
                  videos: _userVideos,
                  initialIndex: index,
                  onVideoDeleted: () {
                    // Refresh the profile videos when a video is deleted
                    _loadUserData();
                  },
                ),
              ),
            );
          },
          child: Container(
            color: _themeService.isLightMode ? Colors.grey[200] : Colors.grey[900],
            child: thumbnailUrl != null
                ? Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.play_arrow_rounded,
                      color: _themeService.textSecondaryColor,
                      size: 40,
                    ),
                  )
                : Icon(
                    Icons.play_arrow_rounded,
                    color: _themeService.textSecondaryColor,
                    size: 40,
                  ),
          ),
        );
      },
    );
  }
}
