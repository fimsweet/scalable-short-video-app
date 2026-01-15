import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';

class FollowerFollowingScreen extends StatefulWidget {
  final int initialIndex;
  const FollowerFollowingScreen({super.key, this.initialIndex = 0});

  @override
  State<FollowerFollowingScreen> createState() => _FollowerFollowingScreenState();
}

class _FollowerFollowingScreenState extends State<FollowerFollowingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username = _authService.username ?? 'user';

    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: _themeService.iconColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          username,
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _themeService.dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: _themeService.textPrimaryColor,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: _themeService.textPrimaryColor,
              unselectedLabelColor: _themeService.textSecondaryColor,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              splashFactory: NoSplash.splashFactory,
              overlayColor: MaterialStateProperty.all(Colors.transparent),
              tabs: const [
                Tab(text: 'Người theo dõi'),
                Tab(text: 'Đang theo dõi'),
                Tab(text: 'Bài viết'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ModernUserList(key: const PageStorageKey('followers'), type: 'follower', themeService: _themeService),
          _ModernUserList(key: const PageStorageKey('following'), type: 'following', themeService: _themeService),
          _ModernPostGrid(key: const PageStorageKey('posts'), themeService: _themeService),
        ],
      ),
    );
  }
}

class _ModernUserList extends StatefulWidget {
  final String type;
  final ThemeService themeService;
  const _ModernUserList({super.key, required this.type, required this.themeService});

  @override
  State<_ModernUserList> createState() => _ModernUserListState();
}

class _ModernUserListState extends State<_ModernUserList> {
  final FollowService _followService = FollowService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  
  List<Map<String, dynamic>> _users = []; // Changed to include mutual status
  bool _isLoading = true;
  Map<int, bool> _followStatus = {};
  Map<int, bool> _mutualStatus = {}; // NEW: Track mutual status
  Map<int, bool> _isProcessing = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final userId = _authService.user!['id'] as int;

    try {
      // Use new API that includes mutual status
      final users = widget.type == 'follower'
          ? await _followService.getFollowersWithStatus(userId)
          : await _followService.getFollowingWithStatus(userId);

      for (var user in users) {
        final id = user['userId'] as int;
        final isMutual = user['isMutual'] as bool? ?? false;
        
        _mutualStatus[id] = isMutual;
        // In "following" tab, user is always following. In "follower" tab, check if following back
        _followStatus[id] = widget.type == 'following' ? true : isMutual;
      }

      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFollow(int targetUserId) async {
    if (!_authService.isLoggedIn || _authService.user == null) return;
    if (_isProcessing[targetUserId] == true) return;

    setState(() {
      _isProcessing[targetUserId] = true;
    });

    final currentUserId = _authService.user!['id'] as int;
    final result = await _followService.toggleFollow(currentUserId, targetUserId);

    if (mounted) {
      final newFollowing = result['following'] ?? false;
      
      // Check mutual status after toggle
      final isMutual = newFollowing 
          ? await _followService.isMutualFollow(currentUserId, targetUserId)
          : false;
      
      setState(() {
        _followStatus[targetUserId] = newFollowing;
        _mutualStatus[targetUserId] = isMutual;
        _isProcessing[targetUserId] = false;

        // REMOVED: Don't remove user from list when unfollowing
        // Keep user in list so they can re-follow if they accidentally unfollowed
        // if (widget.type == 'following' && !newFollowing) {
        //   _users.removeWhere((u) => u['userId'] == targetUserId);
        // }
      });
    }
  }

  void _navigateToProfile(int userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: widget.themeService.textPrimaryColor, strokeWidth: 2),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.type == 'follower' ? Icons.people_outline : Icons.person_add_outlined,
              size: 64,
              color: widget.themeService.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              widget.type == 'follower' ? 'Chưa có người theo dõi' : 'Chưa theo dõi ai',
              style: TextStyle(color: widget.themeService.textSecondaryColor, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final userId = user['userId'] as int;
        final isFollowing = _followStatus[userId] ?? false;
        final isMutual = _mutualStatus[userId] ?? false;
        
        return _UserListItem(
          userId: userId,
          apiService: _apiService,
          themeService: widget.themeService,
          isFollowing: isFollowing,
          isMutual: isMutual, // NEW
          isProcessing: _isProcessing[userId] ?? false,
          listType: widget.type,
          onToggleFollow: () => _toggleFollow(userId),
          onTap: () => _navigateToProfile(userId), // NEW
        );
      },
    );
  }
}

class _UserListItem extends StatelessWidget {
  final int userId;
  final ApiService apiService;
  final ThemeService themeService;
  final bool isFollowing;
  final bool isMutual; // NEW
  final bool isProcessing;
  final String listType;
  final VoidCallback onToggleFollow;
  final VoidCallback onTap; // NEW

  const _UserListItem({
    required this.userId,
    required this.apiService,
    required this.themeService,
    required this.isFollowing,
    required this.isMutual, // NEW
    required this.isProcessing,
    required this.listType,
    required this.onToggleFollow,
    required this.onTap, // NEW
  });

  String _getButtonText() {
    if (isMutual) {
      return 'Bạn bè';
    } else if (isFollowing) {
      return 'Đang theo dõi';
    } else {
      return 'Theo dõi';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: apiService.getUserById(userId.toString()),
      builder: (context, snapshot) {
        final userInfo = snapshot.data ?? {'username': 'user', 'avatar': null};
        final username = userInfo['username'] ?? 'user';
        final avatar = userInfo['avatar'];

        return InkWell(
          onTap: onTap, // Navigate to profile on tap
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: themeService.isLightMode ? Colors.grey[300] : Colors.grey[850],
                  backgroundImage: avatar != null && avatar.toString().isNotEmpty
                      ? NetworkImage(apiService.getAvatarUrl(avatar))
                      : null,
                  child: avatar == null || avatar.toString().isEmpty
                      ? Icon(Icons.person, color: themeService.textSecondaryColor, size: 24)
                      : null,
                ),
                const SizedBox(width: 14),
                
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: TextStyle(
                          color: themeService.textPrimaryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: TextStyle(color: themeService.textSecondaryColor, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                
                // Follow button
                GestureDetector(
                  onTap: isProcessing ? null : onToggleFollow,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMutual && themeService.isLightMode
                          ? const Color(0xFFFF2D55) // Red background for "Bạn bè" in light mode
                          : (isMutual || isFollowing 
                              ? Colors.transparent
                              : const Color(0xFFFF2D55)),
                      border: Border.all(
                        color: isMutual && themeService.isLightMode
                            ? Colors.transparent
                            : (isMutual || isFollowing 
                                ? (themeService.isLightMode ? Colors.grey[400]! : Colors.grey[700]!)
                                : Colors.transparent),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _getButtonText(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModernPostGrid extends StatelessWidget {
  final ThemeService themeService;
  const _ModernPostGrid({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.grid_on_outlined, size: 64, color: themeService.textSecondaryColor),
          const SizedBox(height: 16),
          Text(
            'Chưa có bài viết',
            style: TextStyle(color: themeService.textSecondaryColor, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
