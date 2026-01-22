import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/screens/login_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/follower_following_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/edit_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/user_video_grid.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/hidden_video_grid.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/saved_video_grid.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/liked_video_grid.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';
import 'package:scalable_short_video_app/src/services/notification_service.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/like_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/notifications_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/inbox_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_settings_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/help_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  final FollowService _followService = FollowService();
  final NotificationService _notificationService = NotificationService();
  final MessageService _messageService = MessageService();
  final LikeService _likeService = LikeService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  
  // Animation controller for message icon - Changed from late to nullable to fix Hot Reload error
  AnimationController? _messageIconController;
  Animation<double>? _messageIconScale;

  bool _isUploading = false;
  int _followerCount = 0;
  int _followingCount = 0;
  int _unreadCount = 0;
  int _unreadMessageCount = 0;
  int _likedCount = 0;
  int _videoGridKey = 0; // Key to force rebuild video grid

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    
    _initAnimations();

    _loadFollowStats();
    _loadLikedCount();
    
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
      
      // Load unread message count
      _loadUnreadMessageCount(userId);
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

  Future<void> _loadUnreadMessageCount(String userId) async {
    try {
      final count = await _messageService.getUnreadCount(userId);
      if (mounted) {
        setState(() {
          _unreadMessageCount = count;
        });
      }
    } catch (e) {
      debugPrint('Error loading unread message count: $e');
    }
  }

  void _initAnimations() {
    if (_messageIconController != null) return;
    
    _messageIconController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _messageIconScale = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _messageIconController!, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationService.stopPolling();
    _messageIconController?.dispose(); // Safe dispose
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Force rebuild video grid when screen is rebuilt
    setState(() {
      _videoGridKey++;
    });
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
    _loadLikedCount();
    _initAnimations();
    // Screen is rebuilt by MainScreen when auth state changes
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        title: Text(_localeService.get('logout'), style: TextStyle(color: _themeService.textPrimaryColor)),
        content: Text(_localeService.get('logout_confirm'), style: TextStyle(color: _themeService.textSecondaryColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_localeService.get('cancel'), style: TextStyle(color: _themeService.textSecondaryColor)),
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
                  _likedCount = 0;
                });
                
                print('🔄 Logout successful - rebuilding UI');
              }
            },
            child: Text(_localeService.get('logout'), style: const TextStyle(color: Colors.red)),
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

  void _showLanguageDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _themeService.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: _themeService.textSecondaryColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _localeService.get('language'),
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildLanguageOption(
              title: 'Tiếng Việt',
              value: 'vi',
              isSelected: _localeService.currentLocale == 'vi',
            ),
            _buildLanguageOption(
              title: 'English',
              value: 'en',
              isSelected: _localeService.currentLocale == 'en',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required String title,
    required String value,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        _localeService.setLocale(value);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected 
                      ? ThemeService.accentColor 
                      : _themeService.textSecondaryColor,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: ThemeService.accentColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check,
                color: ThemeService.accentColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
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
            SnackBar(content: Text(_localeService.get('please_login_again'))),
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

  Future<void> _loadLikedCount() async {
    if (_authService.isLoggedIn && _authService.user != null) {
      try {
        final userIdValue = _authService.user!['id'];
        if (userIdValue == null) {
          if (mounted) {
            setState(() {
              _likedCount = 0;
            });
          }
          return;
        }
        
        final userId = userIdValue.toString();
        final videos = await _likeService.getUserLikedVideos(userId);
        
        if (mounted) {
          setState(() {
            _likedCount = videos.length;
          });
          print('✅ Liked count: ${videos.length}');
        }
      } catch (e) {
        print('❌ Error loading liked count: $e');
        if (mounted) {
          setState(() {
            _likedCount = 0;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _likedCount = 0;
        });
      }
    }
  }

  void _onMessageIconTap() async {
    // Play animation if available (don't block navigation if animation is null)
    if (_messageIconController != null) {
      await _messageIconController!.forward();
      await _messageIconController!.reverse();
    }

    // Always navigate
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InboxScreen()),
      );
      
      // Refresh unread message count after returning from inbox
      if (_authService.isLoggedIn && _authService.user != null) {
        final userId = _authService.user!['id'].toString();
        _loadUnreadMessageCount(userId);
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
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        elevation: 0,
        title: Text(_localeService.get('profile'), style: TextStyle(color: _themeService.textPrimaryColor)),
        // No actions - login button is in the body
      ),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline, size: 80, color: _themeService.textSecondaryColor),
                  const SizedBox(height: 24),
                  Text(_localeService.get('login_to_view_profile'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _themeService.textPrimaryColor)),
                  const SizedBox(height: 12),
                  Text(
                    _localeService.get('follow_others_like_videos'),
                    style: TextStyle(color: _themeService.textSecondaryColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 200,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _themeService.isLightMode ? Colors.black : Colors.white,
                        foregroundColor: _themeService.isLightMode ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _navigateToLogin,
                      child: Text(_localeService.get('login'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Language toggle button at bottom left
          Positioned(
            left: 16,
            bottom: 16,
            child: _buildLanguageToggleButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageToggleButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showLanguageDialog,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _themeService.isLightMode 
                  ? Colors.grey[400]! 
                  : Colors.grey[600]!,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.language,
                size: 16,
                color: _themeService.textSecondaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                _localeService.isVietnamese ? 'VI' : 'EN',
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
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
      length: 4,
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
          backgroundColor: _themeService.backgroundColor,
          appBar: AppBar(
            backgroundColor: _themeService.appBarBackground,
            elevation: 0,
            title: Text(
              _localeService.get('my_profile'),
              style: TextStyle(fontWeight: FontWeight.bold, color: _themeService.textPrimaryColor),
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
                    Icon(
                      Icons.notifications_outlined,
                      size: 28,
                      color: _themeService.iconColor,
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
              // Inbox/Messages icon - UPDATED with badge
              GestureDetector(
                onTap: _onMessageIconTap,
                child: _messageIconScale != null ? AnimatedBuilder(
                  animation: _messageIconScale!,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _messageIconScale!.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        color: Colors.transparent, // Hit test area
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              Icons.mail_outline,
                              size: 30,
                              color: _themeService.iconColor,
                            ),
                            if (_unreadMessageCount > 0)
                              Positioned(
                                right: -6,
                                top: -4,
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
                                    _unreadMessageCount > 99 ? '99+' : _unreadMessageCount.toString(),
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
                      ),
                    );
                  },
                ) : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.mail_outline, color: _themeService.iconColor, size: 30),
                    if (_unreadMessageCount > 0)
                      Positioned(
                        right: -6,
                        top: -4,
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
                            _unreadMessageCount > 99 ? '99+' : _unreadMessageCount.toString(),
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
              ),
              
              PopupMenuButton<String>(
                icon: Icon(Icons.menu, color: _themeService.iconColor),
                splashRadius: 0.1,
                onSelected: (v) {
                  if (v == 'logout') _showLogoutDialog();
                  if (v == 'settings') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UserSettingsScreen()),
                    );
                  }
                  if (v == 'help') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpScreen()),
                    );
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'settings',
                    child: Row(children: [Icon(Icons.settings, color: _themeService.textPrimaryColor), const SizedBox(width: 12), Text(_localeService.get('settings'), style: TextStyle(color: _themeService.textPrimaryColor))]),
                  ),
                  PopupMenuItem(
                    value: 'help',
                    child: Row(children: [Icon(Icons.help, color: _themeService.textPrimaryColor), const SizedBox(width: 12), Text(_localeService.get('help'), style: TextStyle(color: _themeService.textPrimaryColor))]),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(children: [const Icon(Icons.logout, color: Colors.red), const SizedBox(width: 12), Text(_localeService.get('logout'), style: const TextStyle(color: Colors.red))]),
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
                                        color: _themeService.isLightMode ? Colors.white70 : Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _themeService.textPrimaryColor,
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
                                _ProfileStat(count: _likedCount.toString(), label: _localeService.get('likes'), onTap: null),
                                _ProfileStat(count: _followerCount.toString(), label: _localeService.get('followers'), onTap: () => _navigateToFollowerFollowing(0)),
                                _ProfileStat(count: _followingCount.toString(), label: _localeService.get('following'), onTap: () => _navigateToFollowerFollowing(1)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_authService.username ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: _themeService.textPrimaryColor)),
                      const SizedBox(height: 4),
                      // Bio section with character limit
                      if (_authService.bio != null && _authService.bio!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            _authService.bio!.length > 150 
                                ? '${_authService.bio!.substring(0, 150)}...' 
                                : _authService.bio!,
                            style: TextStyle(
                              color: _themeService.textPrimaryColor,
                              fontSize: 14,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                        Expanded(child: _ActionButton(text: _localeService.get('edit'), onTap: _navigateToEditProfile)),
                          const SizedBox(width: 8),
                          Expanded(child: _ActionButton(text: _localeService.get('share_profile'))),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
            body: Column(
              children: [
                TabBar(
                  indicatorColor: _themeService.isLightMode ? Colors.black : Colors.white,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 1.5,
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: const MaterialStatePropertyAll(Colors.transparent),
                  labelColor: _themeService.textPrimaryColor,
                  unselectedLabelColor: _themeService.textSecondaryColor,
                  dividerColor: Colors.transparent, // Remove gray divider line
                  dividerHeight: 0, // Remove divider height
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on)),
                    Tab(icon: Icon(Icons.lock_outline)),
                    Tab(icon: Icon(Icons.bookmark_border)),
                    Tab(icon: Icon(Icons.favorite_border)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      UserVideoGrid(key: ValueKey('user_videos_$_videoGridKey')),
                      HiddenVideoGrid(key: ValueKey('hidden_videos_$_videoGridKey')),
                      const SavedVideoGrid(),
                      const LikedVideoGrid(),
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
      
      return CircleAvatar(
        radius: 40,
        backgroundColor: _themeService.isLightMode ? Colors.white : Colors.grey[700],
        child: ClipOval(
          child: Image.network(
            fullUrl,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print('❌ Error loading avatar: $error');
              return Icon(Icons.person, size: 40, color: _themeService.textPrimaryColor);
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

    return CircleAvatar(
      radius: 40,
      backgroundColor: _themeService.isLightMode ? Colors.white : Colors.grey[700],
      child: Icon(Icons.person, size: 40, color: _themeService.textPrimaryColor),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String count;
  final String label;
  final VoidCallback? onTap;
  const _ProfileStat({required this.count, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    return GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Text(count, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeService.textPrimaryColor)),
            Text(label, style: TextStyle(color: themeService.textSecondaryColor)),
          ],
        ),
      );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isFilled;
  const _ActionButton({required this.text, this.onTap, this.isFilled = false});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    
    // Filled variant for "Chia sẻ trang cá nhân" button
    if (isFilled) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: themeService.isLightMode ? const Color(0xFFF1F1F2) : Colors.grey[700],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: themeService.textPrimaryColor,
              ),
            ),
          ),
        ),
      );
    }
    
    // Default outline variant
    return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: themeService.isLightMode ? Colors.white : Colors.grey[800],
            border: themeService.isLightMode ? Border.all(color: const Color(0xFFE0E0E0), width: 1) : null,
            borderRadius: BorderRadius.circular(8)
          ),
          child: Center(child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: themeService.textPrimaryColor))),
        ),
      );
  }
}

