import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/screens/login_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/follower_following_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/edit_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/user_video_grid.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/saved_video_grid.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';
import 'package:scalable_short_video_app/src/services/notification_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/notifications_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  final FollowService _followService = FollowService();
  final NotificationService _notificationService = NotificationService();
  bool _isUploading = false;
  int _followerCount = 0;
  int _followingCount = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFollowStats();
    
    // Start polling for notifications
    if (_authService.isLoggedIn && _authService.user != null) {
      final userId = _authService.user!['id'].toString();
      _notificationService.startPolling(userId);
      
      _notificationService.unreadCountStream.listen((count) {
        if (mounted) {
          setState(() {
            _unreadCount = count;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationService.stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload stats when app resumes
      _loadFollowStats();
    }
  }

  // Add this method to refresh when screen becomes visible
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFollowStats();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
        content: const Text('Bạn chắc chắn muốn đăng xuất?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await _authService.logout();
              
              if (mounted) {
                Navigator.pop(context); // Close dialog
                
                // Force rebuild entire screen
                setState(() {
                  _followerCount = 0;
                  _followingCount = 0;
                });
                
                print('🔄 Logout successful - rebuilding UI');
              }
            },
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _mockLogin() {
    // This function is no longer needed for real login
    // _authService.login('ten nguoi dung');
    // setState(() {});
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    ).then((result) {
      if (result == true) {
        setState(() {});
      }
    });
  }

  void _navigateToFollowerFollowing(int initialIndex) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowerFollowingScreen(initialIndex: initialIndex),
      ),
    );
    
    // Reload stats when returning from follower/following screen
    _loadFollowStats();
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const EditProfileScreen(),
      ),
    );
    
    if (result == true) {
      setState(() {});
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      final token = await _authService.getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng đăng nhập lại')),
          );
        }
        return;
      }

      // Truyền XFile trực tiếp, ApiService sẽ xử lý
      final result = await _apiService.uploadAvatar(
        token: token,
        imageFile: kIsWeb ? image : File(image.path),
      );

      if (result['success']) {
        final avatarUrl = result['data']['user']['avatar'];
        await _authService.updateAvatar(avatarUrl);

        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật ảnh đại diện thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Upload thất bại'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _loadFollowStats() async {
    if (_authService.isLoggedIn && _authService.user != null) {
      final userId = _authService.user!['id'] as int;
      final stats = await _followService.getStats(userId);
      
      if (mounted) {
        setState(() {
          _followerCount = stats['followerCount'] ?? 0;
          _followingCount = stats['followingCount'] ?? 0;
        });
        
        print('📊 Follow stats loaded: $_followerCount followers, $_followingCount following');
      }
    } else {
      // Reset counts when logged out
      if (mounted) {
        setState(() {
          _followerCount = 0;
          _followingCount = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = _authService.isLoggedIn;
    return loggedIn ? _buildLoggedIn() : _buildLoggedOut();
  }

  // Logged OUT view (giống TikTok hiển thị lời mời đăng nhập)
  Widget _buildLoggedOut() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Hồ sơ'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            color: Colors.grey[900],
            onSelected: (v) {
              if (v == 'login') _mockLogin();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'login',
                child: Row(children: [Icon(Icons.login, color: Colors.white), SizedBox(width: 12), Text('Đăng nhập', style: TextStyle(color: Colors.white))]),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline, size: 80, color: Colors.grey[700]),
              const SizedBox(height: 24),
              const Text('Đăng nhập để xem hồ sơ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                'Theo dõi người khác, thích video và tạo nội dung của riêng bạn.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 200,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, // Nút màu trắng
                    foregroundColor: Colors.black, // Chữ màu đen
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _navigateToLogin, // Dẫn tới màn hình đăng nhập
                  child: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Logged IN view
  Widget _buildLoggedIn() {
    return DefaultTabController(
      length: 3,
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          tabBarTheme: const TabBarThemeData(
            overlayColor: MaterialStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_authService.username ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Icon(Icons.keyboard_arrow_down),
                const SizedBox(width: 4),
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
              ],
            ),
            actions: [
              // Notification icon
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ).then((_) {
                    // Refresh unread count after returning
                    if (_authService.isLoggedIn && _authService.user != null) {
                      final userId = _authService.user!['id'].toString();
                      _notificationService.getUnreadCount(userId).then((count) {
                        if (mounted) {
                          setState(() {
                            _unreadCount = count;
                          });
                        }
                      });
                    }
                  });
                },
                icon: Stack(
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      size: 28,
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.alternate_email),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.add_box_outlined),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.menu),
                color: Colors.grey[900],
                splashRadius: 0.1,
                onSelected: (v) {
                  if (v == 'logout') _showLogoutDialog();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'settings',
                    child: Row(children: [Icon(Icons.settings, color: Colors.white), SizedBox(width: 12), Text('Cài đặt', style: TextStyle(color: Colors.white))]),
                  ),
                  PopupMenuItem(
                    value: 'help',
                    child: Row(children: [Icon(Icons.help, color: Colors.white), SizedBox(width: 12), Text('Trợ giúp', style: TextStyle(color: Colors.white))]),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(children: [Icon(Icons.logout, color: Colors.red), SizedBox(width: 12), Text('Đăng xuất', style: TextStyle(color: Colors.red))]),
                  ),
                ],
              ),
            ],
          ),
          body: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _pickAndUploadAvatar,
                            child: Stack(
                              children: [
                                _buildAvatar(),
                                if (_isUploading)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _ProfileStat(count: '0', label: 'bài viết', onTap: () => _navigateToFollowerFollowing(2)),
                                _ProfileStat(count: _followerCount.toString(), label: 'người theo dõi', onTap: () => _navigateToFollowerFollowing(0)),
                                _ProfileStat(count: _followingCount.toString(), label: 'đang theo dõi', onTap: () => _navigateToFollowerFollowing(1)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_authService.username ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      // Bio section with character limit
                      if (_authService.bio != null && _authService.bio!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            _authService.bio!.length > 150 
                                ? '${_authService.bio!.substring(0, 150)}...' 
                                : _authService.bio!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _ActionButton(text: 'Chỉnh sửa', onTap: _navigateToEditProfile)),
                          const SizedBox(width: 8),
                          const Expanded(child: _ActionButton(text: 'Chia sẻ trang cá nhân')),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
            body: Column(
              children: const [
                TabBar(
                  indicatorColor: Colors.white,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 1.5,
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: MaterialStatePropertyAll(Colors.transparent),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(icon: Icon(Icons.grid_on)),
                    Tab(icon: Icon(Icons.bookmark_border)), // Changed from movie to bookmark
                    Tab(icon: Icon(Icons.person_pin_outlined)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      UserVideoGrid(),
                      SavedVideoGrid(), // Changed from placeholder
                      Center(child: Text('Tagged')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = _authService.avatarUrl;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      final fullUrl = _apiService.getAvatarUrl(avatarUrl);
      print('🌐 Full avatar URL: $fullUrl');
      
      return CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey,
        child: ClipOval(
          child: Image.network(
            fullUrl,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print('❌ Error loading avatar: $error');
              return const Icon(Icons.person, size: 40, color: Colors.white);
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            },
          ),
        ),
      );
    }

    return const CircleAvatar(
      radius: 40,
      backgroundColor: Colors.grey,
      child: Icon(Icons.person, size: 40, color: Colors.white),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String count;
  final String label;
  final VoidCallback? onTap;
  const _ProfileStat({required this.count, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
}

class _ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const _ActionButton({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold))),
        ),
      );
}
