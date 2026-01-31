import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_media_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/pinned_messages_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_search_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/report_user_screen.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/app_snackbar.dart';

// Chat theme colors
class ChatThemeColor {
  final String id;
  final String name;
  final Color primaryColor;
  final Color lightColor;
  
  const ChatThemeColor({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.lightColor,
  });
}

class ChatOptionsScreen extends StatefulWidget {
  final String recipientId;
  final String recipientUsername;
  final String? recipientAvatar;
  final Function(Color?)? onThemeColorChanged;
  final Function(String?)? onNicknameChanged;

  const ChatOptionsScreen({
    super.key,
    required this.recipientId,
    required this.recipientUsername,
    this.recipientAvatar,
    this.onThemeColorChanged,
    this.onNicknameChanged,
  });

  @override
  State<ChatOptionsScreen> createState() => _ChatOptionsScreenState();
}

class _ChatOptionsScreenState extends State<ChatOptionsScreen> with SingleTickerProviderStateMixin {
  final MessageService _messageService = MessageService();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  
  bool _isMuted = false;
  bool _isBlocked = false;
  bool _isLoading = true;
  bool _isRecipientOnline = false;
  
  // Chat customization
  Color? _selectedThemeColor;
  String? _nickname;
  
  // Animation controller for staggered animations
  late AnimationController _animationController;
  
  // Available theme colors
  final List<ChatThemeColor> _themeColors = [
    ChatThemeColor(id: 'default', name: 'Mặc định', primaryColor: Colors.blue, lightColor: Colors.blue.shade100),
    ChatThemeColor(id: 'pink', name: 'Hồng', primaryColor: Colors.pink, lightColor: Colors.pink.shade100),
    ChatThemeColor(id: 'purple', name: 'Tím', primaryColor: Colors.purple, lightColor: Colors.purple.shade100),
    ChatThemeColor(id: 'green', name: 'Xanh lá', primaryColor: Colors.green, lightColor: Colors.green.shade100),
    ChatThemeColor(id: 'orange', name: 'Cam', primaryColor: Colors.orange, lightColor: Colors.orange.shade100),
    ChatThemeColor(id: 'red', name: 'Đỏ', primaryColor: Colors.red, lightColor: Colors.red.shade100),
    ChatThemeColor(id: 'teal', name: 'Xanh ngọc', primaryColor: Colors.teal, lightColor: Colors.teal.shade100),
    ChatThemeColor(id: 'indigo', name: 'Chàm', primaryColor: Colors.indigo, lightColor: Colors.indigo.shade100),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _messageService.getConversationSettings(widget.recipientId);
      
      final currentUser = await _authService.getCurrentUser();
      bool isBlocked = false;
      if (currentUser != null) {
        isBlocked = await _apiService.isUserBlocked(currentUser['id'].toString(), widget.recipientId);
      }
      
      // Check online status
      final onlineStatus = await _apiService.getOnlineStatus(widget.recipientId);
      final isOnline = onlineStatus['isOnline'] == true;
      
      if (mounted) {
        setState(() {
          _isMuted = settings['isMuted'] ?? false;
          _isBlocked = isBlocked;
          _nickname = settings['nickname'];
          _isRecipientOnline = isOnline;
          // Parse theme color if saved
          final themeColorId = settings['themeColor'];
          if (themeColorId != null) {
            final theme = _themeColors.firstWhere(
              (t) => t.id == themeColorId,
              orElse: () => _themeColors.first,
            );
            _selectedThemeColor = theme.primaryColor;
          }
          _isLoading = false;
        });
        // Start staggered animation after loading
        _animationController.forward();
      }
    } catch (e) {
      print('Error loading settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _animationController.forward();
      }
    }
  }

  void _viewProfile() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            UserProfileScreen(userId: int.parse(widget.recipientId)),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeInOut));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _toggleMuteNotification(bool value) async {
    setState(() => _isMuted = value);
    try {
      await _messageService.updateConversationSettings(widget.recipientId, isMuted: value);
    } catch (e) {
      setState(() => _isMuted = !value);
      AppSnackBar.showError(context, _localeService.get('error_occurred'));
    }
  }

  void _showSnackBar(String message, Color color) {
    if (color == Colors.red) {
      AppSnackBar.showError(context, message);
    } else if (color == Colors.green) {
      AppSnackBar.showSuccess(context, message);
    } else {
      AppSnackBar.showInfo(context, message);
    }
  }

  void _showThemeColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _themeService.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _themeService.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _localeService.isVietnamese ? 'Chọn màu chủ đề' : 'Choose Theme Color',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _themeService.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _themeColors.map((theme) => GestureDetector(
                onTap: () {
                  setState(() => _selectedThemeColor = theme.primaryColor);
                  widget.onThemeColorChanged?.call(theme.primaryColor);
                  _messageService.updateConversationSettings(
                    widget.recipientId,
                    themeColor: theme.id,
                  );
                  Navigator.pop(context);
                  _showSnackBar(
                    _localeService.isVietnamese 
                        ? 'Đã đổi màu chủ đề' 
                        : 'Theme color changed',
                    theme.primaryColor,
                  );
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                    border: _selectedThemeColor == theme.primaryColor
                        ? Border.all(color: _themeService.textPrimaryColor, width: 3)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _selectedThemeColor == theme.primaryColor
                      ? const Icon(Icons.check, color: Colors.white, size: 28)
                      : null,
                ),
              )).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showNicknameDialog() {
    final controller = TextEditingController(text: _nickname ?? widget.recipientUsername);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _localeService.isVietnamese ? 'Đặt biệt danh' : 'Set Nickname',
          style: TextStyle(color: _themeService.textPrimaryColor),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          style: TextStyle(color: _themeService.textPrimaryColor),
          decoration: InputDecoration(
            hintText: widget.recipientUsername,
            hintStyle: TextStyle(color: _themeService.textSecondaryColor),
            filled: true,
            fillColor: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            counterStyle: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 12,
            ),
            suffixIcon: IconButton(
              icon: Icon(Icons.clear, color: _themeService.textSecondaryColor),
              onPressed: () => controller.clear(),
            ),
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
              final newNickname = controller.text.trim();
              setState(() => _nickname = newNickname.isEmpty ? null : newNickname);
              widget.onNicknameChanged?.call(_nickname);
              _messageService.updateConversationSettings(
                widget.recipientId,
                nickname: _nickname,
              );
              Navigator.pop(context);
              _showSnackBar(
                _localeService.isVietnamese 
                    ? 'Đã cập nhật biệt danh' 
                    : 'Nickname updated',
                Colors.green,
              );
            },
            child: Text(
              _localeService.isVietnamese ? 'Lưu' : 'Save',
              style: const TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchInChat() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ChatSearchScreen(
          recipientId: widget.recipientId,
          recipientUsername: _nickname ?? widget.recipientUsername,
          recipientAvatar: widget.recipientAvatar,
          onMessageTap: (messageId) {
            print('DEBUG: Search onMessageTap callback: $messageId');
            // Don't pop here, let ChatSearchScreen pop with result
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((result) {
      print('DEBUG: Search returned: $result');
      if (result != null && result is Map && result['scrollToMessageId'] != null) {
        // Pop back to chat screen with the message ID
        print('DEBUG: Popping ChatOptionsScreen with scrollToMessageId: ${result['scrollToMessageId']}');
        Navigator.pop(context, {'scrollToMessageId': result['scrollToMessageId']});
      }
    });
  }

  void _blockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.block_rounded,
                color: Colors.red,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              _localeService.isVietnamese 
                  ? 'Chặn ${widget.recipientUsername}?' 
                  : 'Block ${widget.recipientUsername}?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Warning list
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _themeService.isLightMode 
                    ? Colors.grey[100] 
                    : Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildWarningItem(
                    icon: Icons.message_outlined,
                    text: _localeService.isVietnamese 
                        ? 'Họ sẽ không thể gửi tin nhắn cho bạn'
                        : 'They won\'t be able to message you',
                  ),
                  const SizedBox(height: 10),
                  _buildWarningItem(
                    icon: Icons.visibility_off_outlined,
                    text: _localeService.isVietnamese 
                        ? 'Họ sẽ không thấy hoạt động của bạn'
                        : 'They won\'t see your activity',
                  ),
                  const SizedBox(height: 10),
                  _buildWarningItem(
                    icon: Icons.person_off_outlined,
                    text: _localeService.isVietnamese 
                        ? 'Họ sẽ không được thông báo về việc này'
                        : 'They won\'t be notified about this',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            
            // Note
            Text(
              _localeService.isVietnamese 
                  ? 'Bạn có thể bỏ chặn bất cứ lúc nào trong cài đặt.'
                  : 'You can unblock them anytime in settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _themeService.dividerColor),
                    ),
                  ),
                  child: Text(
                    _localeService.get('cancel'),
                    style: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _performBlockUser();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _localeService.get('block'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.red.shade400, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _performBlockUser() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      await _apiService.blockUser(widget.recipientId, currentUserId: currentUser?['id']?.toString());
      if (mounted) {
        setState(() => _isBlocked = true);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar(_localeService.get('error_occurred'), Colors.red);
    }
  }

  void _unblockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_localeService.get('unblock_user'), style: TextStyle(color: _themeService.textPrimaryColor)),
        content: Text(
          _localeService.isVietnamese
              ? 'Bạn có chắc muốn bỏ chặn ${widget.recipientUsername}?'
              : 'Are you sure you want to unblock ${widget.recipientUsername}?',
          style: TextStyle(color: _themeService.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_localeService.get('cancel'), style: TextStyle(color: _themeService.textSecondaryColor)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final currentUser = await _authService.getCurrentUser();
              await _apiService.unblockUser(widget.recipientId, currentUserId: currentUser?['id']?.toString());
              if (mounted) setState(() => _isBlocked = false);
            },
            child: Text(_localeService.get('unblock'), style: const TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  void _showMediaGallery() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ChatMediaScreen(
          recipientId: widget.recipientId,
          recipientUsername: _nickname ?? widget.recipientUsername,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showPinnedMessages() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PinnedMessagesScreen(
          recipientId: widget.recipientId,
          recipientUsername: _nickname ?? widget.recipientUsername,
          recipientAvatar: widget.recipientAvatar,
          onMessageTap: (messageId) {
            print('DEBUG: onMessageTap callback received: $messageId');
            // Don't pop here, let PinnedMessagesScreen pop with result
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((result) {
      print('DEBUG: PinnedMessages returned: $result');
      if (result != null && result is Map && result['scrollToMessageId'] != null) {
        // Pop back to chat screen with the message ID
        print('DEBUG: Popping ChatOptionsScreen with scrollToMessageId: ${result['scrollToMessageId']}');
        Navigator.pop(context, {'scrollToMessageId': result['scrollToMessageId']});
      }
    });
  }

  void _reportUser() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ReportUserScreen(
          reportedUserId: widget.recipientId,
          reportedUsername: _nickname ?? widget.recipientUsername,
          reportedAvatar: widget.recipientAvatar,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: _themeService.iconColor, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _themeService.textPrimaryColor, strokeWidth: 2))
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildAnimatedItem(0, _buildProfileHeader()),
                  const SizedBox(height: 24),
                  _buildAnimatedItem(1, _buildQuickActions()),
                  const SizedBox(height: 28),
                  _buildAnimatedItem(2, _buildCustomizeSection()),
                  const SizedBox(height: 16),
                  _buildAnimatedItem(3, _buildOtherActionsSection()),
                  const SizedBox(height: 16),
                  _buildAnimatedItem(4, _buildPrivacySection()),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // Animated item with staggered delay
  Widget _buildAnimatedItem(int index, Widget child) {
    // Calculate staggered interval for each item
    final double start = index * 0.1; // 10% delay between each item
    final double end = start + 0.4; // Each animation takes 40% of total time
    
    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
      ),
    );
    
    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0), curve: Curves.easeOut),
      ),
    );
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader() {
    final avatarUrl = widget.recipientAvatar != null 
        ? _apiService.getAvatarUrl(widget.recipientAvatar!)
        : null;
        
    return Column(
      children: [
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.red.shade400, Colors.pink.shade400]),
              ),
              child: CircleAvatar(
                radius: 52,
                backgroundColor: _themeService.backgroundColor,
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Icon(Icons.person, color: _themeService.textSecondaryColor, size: 48)
                      : null,
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: _isRecipientOnline 
                ? Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: _themeService.backgroundColor, width: 3),
                    ),
                  )
                : const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _nickname ?? widget.recipientUsername,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _themeService.textPrimaryColor),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickActionButton(
            icon: Icons.person_outline,
            label: _localeService.isVietnamese ? 'Trang\ncá nhân' : 'Profile',
            onTap: _viewProfile,
          ),
          _buildQuickActionButton(
            icon: _isMuted ? Icons.notifications_off_outlined : Icons.notifications_outlined,
            label: _isMuted 
                ? (_localeService.isVietnamese ? 'Bật thông\nbáo' : 'Unmute')
                : (_localeService.isVietnamese ? 'Tắt thông\nbáo' : 'Mute'),
            onTap: () => _toggleMuteNotification(!_isMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _themeService.isLightMode ? Colors.grey[200] : Colors.grey[850],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _themeService.textPrimaryColor, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _themeService.textPrimaryColor, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _themeService.textSecondaryColor)),
      ),
    );
  }

  Widget _buildCustomizeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_localeService.isVietnamese ? 'Tùy chỉnh' : 'Customize'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildMenuItem(
                icon: Icons.palette_outlined, 
                iconBgColor: _selectedThemeColor ?? Colors.deepPurple, 
                label: _localeService.isVietnamese ? 'Chủ đề' : 'Theme', 
                onTap: _showThemeColorPicker,
                showChevron: true,
              ),
              _buildDivider(),
              _buildMenuItem(
                icon: Icons.edit_outlined, 
                iconBgColor: Colors.blue, 
                label: _localeService.isVietnamese ? 'Biệt danh' : 'Nicknames', 
                onTap: _showNicknameDialog,
                trailing: Text(
                  _nickname ?? widget.recipientUsername, 
                  style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 14),
                ),
                showChevron: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtherActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_localeService.isVietnamese ? 'Hành động khác' : 'More Actions'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildMenuItem(
                icon: Icons.photo_library_outlined, 
                iconBgColor: Colors.pink, 
                label: _localeService.isVietnamese ? 'Xem file phương tiện' : 'View Media', 
                onTap: _showMediaGallery, 
                showChevron: true,
              ),
              _buildDivider(),
              _buildMenuItem(
                icon: Icons.push_pin_outlined, 
                iconBgColor: Colors.amber, 
                label: _localeService.isVietnamese ? 'Tin nhắn đã ghim' : 'Pinned Messages', 
                onTap: _showPinnedMessages, 
                showChevron: true,
              ),
              _buildDivider(),
              _buildMenuItem(
                icon: Icons.search, 
                iconBgColor: Colors.indigo, 
                label: _localeService.isVietnamese ? 'Tìm kiếm trong trò chuyện' : 'Search in Chat', 
                onTap: _showSearchInChat,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_localeService.isVietnamese ? 'Quyền riêng tư' : 'Privacy'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              if (_isBlocked)
                _buildMenuItem(
                  icon: Icons.lock_open, 
                  iconBgColor: Colors.green, 
                  label: _localeService.get('unblock'), 
                  onTap: _unblockUser, 
                  textColor: Colors.green,
                )
              else
                _buildMenuItem(
                  icon: Icons.block, 
                  iconBgColor: Colors.red.shade400, 
                  label: _localeService.get('block'), 
                  onTap: _blockUser, 
                  textColor: Colors.red,
                ),
              _buildDivider(),
              _buildMenuItem(
                icon: Icons.report_outlined, 
                iconBgColor: Colors.orange, 
                label: _localeService.isVietnamese ? 'Báo cáo' : 'Report', 
                onTap: _reportUser,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() => Divider(color: _themeService.dividerColor, height: 1, indent: 56);

  Widget _buildMenuItem({required IconData icon, required Color iconBgColor, required String label, required VoidCallback onTap, Widget? trailing, bool showChevron = false, Color? textColor}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: iconBgColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: iconBgColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: textColor ?? _themeService.textPrimaryColor, fontWeight: FontWeight.w500))),
            if (trailing != null) trailing,
            if (showChevron) Icon(Icons.chevron_right, color: _themeService.textSecondaryColor, size: 22),
          ],
        ),
      ),
    );
  }
}
