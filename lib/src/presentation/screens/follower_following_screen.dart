import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username = _authService.username ?? 'user';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          username,
          style: const TextStyle(
            color: Colors.white,
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
                  color: Colors.grey[900]!,
                  width: 0.5,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
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
          _ModernUserList(key: const PageStorageKey('followers'), type: 'follower'),
          _ModernUserList(key: const PageStorageKey('following'), type: 'following'),
          const _ModernPostGrid(key: PageStorageKey('posts')),
        ],
      ),
    );
  }
}

class _ModernUserList extends StatefulWidget {
  final String type;
  const _ModernUserList({super.key, required this.type});

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
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              widget.type == 'follower' ? 'Chưa có người theo dõi' : 'Chưa theo dõi ai',
              style: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.w500),
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
  final bool isFollowing;
  final bool isMutual; // NEW
  final bool isProcessing;
  final String listType;
  final VoidCallback onToggleFollow;
  final VoidCallback onTap; // NEW

  const _UserListItem({
    required this.userId,
    required this.apiService,
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
                  backgroundColor: Colors.grey[850],
                  backgroundImage: avatar != null && avatar.toString().isNotEmpty
                      ? NetworkImage(apiService.getAvatarUrl(avatar))
                      : null,
                  child: avatar == null || avatar.toString().isEmpty
                      ? const Icon(Icons.person, color: Colors.white54, size: 24)
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
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
                      color: isMutual || isFollowing 
                          ? Colors.transparent
                          : const Color(0xFFFF2D55),
                      border: Border.all(
                        color: isMutual || isFollowing 
                            ? Colors.grey[700]!
                            : Colors.transparent,
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
  const _ModernPostGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.grid_on_outlined, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Chưa có bài viết',
            style: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
