import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';

class FollowerFollowingScreen extends StatelessWidget {
  final int initialIndex;
  const FollowerFollowingScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final username = authService.username ?? 'user';

    return DefaultTabController(
      length: 3,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(username),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Người theo dõi'),
              Tab(text: 'Đang theo dõi'),
              Tab(text: 'Bài viết'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UserList(key: const PageStorageKey('followers'), type: 'follower'),
            _UserList(key: const PageStorageKey('following'), type: 'following'),
            const _PostGrid(key: PageStorageKey('posts')),
          ],
        ),
      ),
    );
  }
}

class _UserList extends StatefulWidget {
  final String type;
  const _UserList({super.key, required this.type});

  @override
  State<_UserList> createState() => _UserListState();
}

class _UserListState extends State<_UserList> {
  final FollowService _followService = FollowService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  
  List<int> _userIds = [];
  bool _isLoading = true;
  Map<int, bool> _followStatus = {};

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
      final userIds = widget.type == 'follower'
          ? await _followService.getFollowers(userId)
          : await _followService.getFollowing(userId);

      // Check follow status for each user
      for (var id in userIds) {
        final isFollowing = await _followService.isFollowing(userId, id);
        _followStatus[id] = isFollowing;
      }

      if (mounted) {
        setState(() {
          _userIds = userIds;
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

    final currentUserId = _authService.user!['id'] as int;
    final result = await _followService.toggleFollow(currentUserId, targetUserId);

    if (mounted) {
      setState(() {
        _followStatus[targetUserId] = result['following'] ?? false;
      });

      // If unfollowed in "following" tab, remove from list
      if (widget.type == 'following' && !(result['following'] ?? false)) {
        setState(() {
          _userIds.remove(targetUserId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_userIds.isEmpty) {
      return Center(
        child: Text(
          widget.type == 'follower' 
              ? 'Chưa có người theo dõi' 
              : 'Chưa theo dõi ai',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: _userIds.length,
      itemBuilder: (context, index) {
        final userId = _userIds[index];
        return FutureBuilder<Map<String, dynamic>?>(
          future: _apiService.getUserById(userId.toString()),
          builder: (context, snapshot) {
            final userInfo = snapshot.data ?? {'username': 'user', 'avatar': null};
            final isFollowing = _followStatus[userId] ?? false;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey[700],
                backgroundImage: userInfo['avatar'] != null && userInfo['avatar'].toString().isNotEmpty
                    ? NetworkImage(_apiService.getAvatarUrl(userInfo['avatar']))
                    : null,
                child: userInfo['avatar'] == null || userInfo['avatar'].toString().isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              title: Text(
                userInfo['username'] ?? 'user',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '@${userInfo['username'] ?? 'user'}',
                style: TextStyle(color: Colors.grey[400]),
              ),
              trailing: ElevatedButton(
                onPressed: () => _toggleFollow(userId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing ? Colors.grey[800] : Colors.white,
                  foregroundColor: isFollowing ? Colors.white : Colors.black,
                ),
                child: Text(
                  isFollowing 
                      ? (widget.type == 'follower' ? 'Hủy theo dõi' : 'Đang theo dõi')
                      : 'Theo dõi',
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PostGrid extends StatelessWidget {
  const _PostGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 15, // Mock post count
      itemBuilder: (context, index) {
        return Container(
          color: Colors.grey[900],
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
        );
      },
    );
  }
}
