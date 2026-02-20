import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_screen.dart';

class FollowerFollowingScreen extends StatefulWidget {
  final int initialIndex;
  final int? userId; // Optional: view another user's lists
  final String? username; // Optional: display name for the app bar
  const FollowerFollowingScreen({super.key, this.initialIndex = 0, this.userId, this.username});

  @override
  State<FollowerFollowingScreen> createState() => _FollowerFollowingScreenState();
}

class _FollowerFollowingScreenState extends State<FollowerFollowingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final FollowService _followService = FollowService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();

  // Privacy state for viewing other user's lists
  bool _isOwnProfile = true;
  bool _followersPrivacyRestricted = false;
  bool _followingPrivacyRestricted = false;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);

    final targetUserId = widget.userId;
    final currentUserId = _authService.isLoggedIn && _authService.user != null
        ? _authService.user!['id'] as int
        : null;
    _isOwnProfile = targetUserId == null || targetUserId == currentUserId;

    // If viewing another user, only show 2 tabs (no Friends tab)
    _tabController = TabController(
      length: _isOwnProfile ? 3 : 2,
      vsync: this,
      initialIndex: widget.initialIndex.clamp(0, _isOwnProfile ? 2 : 1),
    );

    if (!_isOwnProfile && currentUserId != null && targetUserId != null) {
      _checkListPrivacy(targetUserId, currentUserId);
    }
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onLocaleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _checkListPrivacy(int targetUserId, int currentUserId) async {
    try {
      final followersCheck = await _followService.checkListPrivacy(
        targetUserId: targetUserId,
        requesterId: currentUserId,
        listType: 'followers',
      );
      final followingCheck = await _followService.checkListPrivacy(
        targetUserId: targetUserId,
        requesterId: currentUserId,
        listType: 'following',
      );
      if (mounted) {
        setState(() {
          _followersPrivacyRestricted = followersCheck['allowed'] != true;
          _followingPrivacyRestricted = followingCheck['allowed'] != true;
        });
      }
    } catch (e) {
      print('Error checking list privacy: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.username ?? _authService.username ?? 'user';
    final targetUserId = widget.userId;

    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: _themeService.iconColor, size: 28),
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
          child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
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
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              tabs: [
                Tab(text: _localeService.get('followers')),
                Tab(text: _localeService.get('following')),
                if (_isOwnProfile)
                  Tab(text: _localeService.get('friends')),
              ],
            ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Followers tab
          _followersPrivacyRestricted
              ? _buildPrivacyGate()
              : _ModernUserList(
                  key: const PageStorageKey('followers'),
                  type: 'follower',
                  themeService: _themeService,
                  localeService: _localeService,
                  targetUserId: targetUserId,
                ),
          // Following tab
          _followingPrivacyRestricted
              ? _buildPrivacyGate()
              : _ModernUserList(
                  key: const PageStorageKey('following'),
                  type: 'following',
                  themeService: _themeService,
                  localeService: _localeService,
                  targetUserId: targetUserId,
                ),
          // Friends tab (own profile only)
          if (_isOwnProfile)
            _FriendsList(
              key: const PageStorageKey('friends'),
              themeService: _themeService,
              localeService: _localeService,
            ),
        ],
      ),
    );
  }

  Widget _buildPrivacyGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _themeService.textSecondaryColor.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 32,
                color: _themeService.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _localeService.get('list_privacy_restricted'),
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _localeService.get('list_privacy_restricted_desc'),
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernUserList extends StatefulWidget {
  final String type;
  final ThemeService themeService;
  final LocaleService localeService;
  final int? targetUserId; // Optional: view another user's lists
  const _ModernUserList({super.key, required this.type, required this.themeService, required this.localeService, this.targetUserId});

  @override
  State<_ModernUserList> createState() => _ModernUserListState();
}

class _ModernUserListState extends State<_ModernUserList> {
  final FollowService _followService = FollowService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _users = []; // Changed to include mutual status
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  final int _pageSize = 20;
  Map<int, bool> _followStatus = {};
  Map<int, bool> _mutualStatus = {}; // NEW: Track mutual status
  Map<int, bool> _requestedStatus = {}; // Track pending follow requests
  Map<int, bool> _isProcessing = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUsers();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreUsers();
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoadingMore || !_hasMore) return;
    
    setState(() => _isLoadingMore = true);
    
    final userId = widget.targetUserId ?? (_authService.user!['id'] as int);
    
    try {
      final result = widget.type == 'follower'
          ? await _followService.getFollowersWithStatusPaginated(userId, limit: _pageSize, offset: _currentOffset)
          : await _followService.getFollowingWithStatusPaginated(userId, limit: _pageSize, offset: _currentOffset);
      
      final newUsers = result['data'] as List<Map<String, dynamic>>;
      
      for (var user in newUsers) {
        final id = user['userId'] as int;
        final isMutual = user['isMutual'] as bool? ?? false;
        
        _mutualStatus[id] = isMutual;
        _followStatus[id] = widget.type == 'following' ? true : isMutual;
      }
      
      if (mounted) {
        setState(() {
          _users.addAll(newUsers);
          _hasMore = result['hasMore'] ?? false;
          _currentOffset += newUsers.length;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error loading more users: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _loadUsers() async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final userId = widget.targetUserId ?? (_authService.user!['id'] as int);
    
    // Reset pagination state
    _currentOffset = 0;
    _hasMore = true;
    _users.clear();
    _followStatus.clear();
    _mutualStatus.clear();
    _requestedStatus.clear();

    try {
      // Use new paginated API
      final result = widget.type == 'follower'
          ? await _followService.getFollowersWithStatusPaginated(userId, limit: _pageSize, offset: 0)
          : await _followService.getFollowingWithStatusPaginated(userId, limit: _pageSize, offset: 0);

      final users = result['data'] as List<Map<String, dynamic>>;
      
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
          _hasMore = result['hasMore'] ?? false;
          _currentOffset = users.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading users: $e');
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
      final isRequested = result['requested'] ?? false;
      
      // Check mutual status after toggle
      final isMutual = newFollowing 
          ? await _followService.isMutualFollow(currentUserId, targetUserId)
          : false;
      
      setState(() {
        _followStatus[targetUserId] = newFollowing;
        _mutualStatus[targetUserId] = isMutual;
        _requestedStatus[targetUserId] = isRequested;
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
    // If tapping own profile, pop back to root profile
    final currentUserId = _authService.isLoggedIn && _authService.user != null
        ? _authService.user!['id'] as int
        : null;
    if (currentUserId != null && userId == currentUserId) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    // Replace current screen to avoid infinite stacking
    Navigator.pushReplacement(
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
              widget.type == 'follower' ? widget.localeService.get('no_followers') : widget.localeService.get('no_following'),
              style: TextStyle(color: widget.themeService.textSecondaryColor, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _users.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the end
        if (index == _users.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        
        final user = _users[index];
        final userId = user['userId'] as int;
        final isFollowing = _followStatus[userId] ?? false;
        final isMutual = _mutualStatus[userId] ?? false;
        final isRequested = _requestedStatus[userId] ?? false;
        
        return _UserListItem(
          userId: userId,
          apiService: _apiService,
          themeService: widget.themeService,
          localeService: widget.localeService,
          isFollowing: isFollowing,
          isMutual: isMutual,
          isRequested: isRequested,
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
  final LocaleService localeService;
  final bool isFollowing;
  final bool isMutual;
  final bool isRequested;
  final bool isProcessing;
  final String listType;
  final VoidCallback onToggleFollow;
  final VoidCallback onTap;

  const _UserListItem({
    required this.userId,
    required this.apiService,
    required this.themeService,
    required this.localeService,
    required this.isFollowing,
    required this.isMutual,
    required this.isRequested,
    required this.isProcessing,
    required this.listType,
    required this.onToggleFollow,
    required this.onTap,
  });

  String _getButtonText() {
    if (isRequested) {
      return localeService.get('requested');
    } else if (isMutual) {
      return localeService.get('friends');
    } else if (isFollowing) {
      return localeService.get('following_status');
    } else {
      return localeService.get('follow');
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
                  backgroundImage: avatar != null && avatar.toString().isNotEmpty && apiService.getAvatarUrl(avatar).isNotEmpty
                      ? NetworkImage(apiService.getAvatarUrl(avatar))
                      : null,
                  child: avatar == null || avatar.toString().isEmpty || apiService.getAvatarUrl(avatar).isEmpty
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
                      color: isRequested
                          ? Colors.transparent
                          : (isMutual && themeService.isLightMode
                              ? const Color(0xFFFF2D55)
                              : (isMutual || isFollowing 
                                  ? Colors.transparent
                                  : const Color(0xFFFF2D55))),
                      border: Border.all(
                        color: isRequested
                            ? Colors.orange
                            : (isMutual && themeService.isLightMode
                                ? Colors.transparent
                                : (isMutual || isFollowing 
                                    ? (themeService.isLightMode ? Colors.grey[400]! : Colors.grey[700]!)
                                    : Colors.transparent)),
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
                            style: TextStyle(
                              color: isRequested
                                  ? Colors.orange
                                  : ((isMutual && themeService.isLightMode) || (!isMutual && !isFollowing)
                                      ? Colors.white
                                      : (themeService.isLightMode ? Colors.grey[800]! : Colors.white)),
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

/// Friends list - shows users who follow each other (mutual follows)
class _FriendsList extends StatefulWidget {
  final ThemeService themeService;
  final LocaleService localeService;
  const _FriendsList({super.key, required this.themeService, required this.localeService});

  @override
  State<_FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends State<_FriendsList> {
  final FollowService _followService = FollowService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _friends = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFriends();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreFriends();
    }
  }

  Future<void> _loadMoreFriends() async {
    if (_isLoadingMore || !_hasMore) return;
    
    setState(() => _isLoadingMore = true);
    
    final userId = _authService.user!['id'] as int;
    
    try {
      final result = await _followService.getMutualFriendsPaginated(
        userId, 
        limit: _pageSize, 
        offset: _currentOffset
      );
      
      final newFriends = result['data'] as List<Map<String, dynamic>>;
      
      if (mounted) {
        setState(() {
          _friends.addAll(newFriends);
          _hasMore = result['hasMore'] ?? false;
          _currentOffset += newFriends.length;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error loading more friends: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _loadFriends() async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final userId = _authService.user!['id'] as int;
    
    // Reset pagination state
    _currentOffset = 0;
    _hasMore = true;
    _friends.clear();

    try {
      final result = await _followService.getMutualFriendsPaginated(
        userId, 
        limit: _pageSize, 
        offset: 0
      );

      final friends = result['data'] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _friends = friends;
          _hasMore = result['hasMore'] ?? false;
          _currentOffset = friends.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading friends: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToProfile(int userId) {
    // If tapping own profile, pop back to root profile
    final currentUserId = _authService.isLoggedIn && _authService.user != null
        ? _authService.user!['id'] as int
        : null;
    if (currentUserId != null && userId == currentUserId) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    // Push and remove follower/following screen to avoid infinite stacking
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId),
      ),
    );
  }

  void _navigateToChat(int userId, String username, String? avatar) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          recipientId: userId.toString(),
          recipientUsername: username,
          recipientAvatar: avatar,
        ),
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

    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_alt_outlined,
              size: 64,
              color: widget.themeService.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              widget.localeService.get('no_friends'),
              style: TextStyle(color: widget.themeService.textSecondaryColor, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              widget.localeService.get('follow_each_other_to_be_friends'),
              style: TextStyle(color: widget.themeService.textSecondaryColor.withOpacity(0.7), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _friends.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the end
        if (index == _friends.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        
        final friend = _friends[index];
        final userId = friend['userId'] as int;
        final username = friend['username'] as String? ?? 'user';
        final fullName = friend['fullName'] as String?;
        final avatar = friend['avatar'] as String?;
        
        return _FriendListItem(
          userId: userId,
          username: username,
          fullName: fullName,
          avatar: avatar,
          apiService: _apiService,
          themeService: widget.themeService,
          localeService: widget.localeService,
          onTap: () => _navigateToProfile(userId),
          onMessage: () => _navigateToChat(userId, username, avatar),
        );
      },
    );
  }
}

class _FriendListItem extends StatelessWidget {
  final int userId;
  final String username;
  final String? fullName;
  final String? avatar;
  final ApiService apiService;
  final ThemeService themeService;
  final LocaleService localeService;
  final VoidCallback onTap;
  final VoidCallback onMessage;

  const _FriendListItem({
    required this.userId,
    required this.username,
    this.fullName,
    this.avatar,
    required this.apiService,
    required this.themeService,
    required this.localeService,
    required this.onTap,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: themeService.isLightMode ? Colors.grey[300] : Colors.grey[850],
              backgroundImage: avatar != null && avatar!.isNotEmpty && apiService.getAvatarUrl(avatar!).isNotEmpty
                  ? NetworkImage(apiService.getAvatarUrl(avatar!))
                  : null,
              child: avatar == null || avatar!.isEmpty || apiService.getAvatarUrl(avatar!).isEmpty
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
                    fullName ?? username,
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
            
            // Message button
            GestureDetector(
              onTap: onMessage,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2D55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      localeService.get('message'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
