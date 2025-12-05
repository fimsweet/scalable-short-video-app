import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/blocked_users_screen.dart';

class ChatOptionsScreen extends StatefulWidget {
  final String recipientId;
  final String recipientUsername;
  final String? recipientAvatar;

  const ChatOptionsScreen({
    super.key,
    required this.recipientId,
    required this.recipientUsername,
    this.recipientAvatar,
  });

  @override
  State<ChatOptionsScreen> createState() => _ChatOptionsScreenState();
}

class _ChatOptionsScreenState extends State<ChatOptionsScreen> {
  final MessageService _messageService = MessageService();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  
  bool _isMuted = false;
  bool _isPinned = false;
  bool _isBlocked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _messageService.getConversationSettings(widget.recipientId);
      
      // Check blocked status
      final currentUser = await _authService.getCurrentUser();
      bool isBlocked = false;
      if (currentUser != null) {
        isBlocked = await _apiService.isUserBlocked(currentUser['id'].toString(), widget.recipientId);
      }
      
      if (mounted) {
        setState(() {
          _isMuted = settings['isMuted'] ?? false;
          _isPinned = settings['isPinned'] ?? false;
          _isBlocked = isBlocked;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ],
        ),
        content: Text(message, style: TextStyle(color: Colors.grey[400])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFFE84C3D))),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Lỗi', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(message, style: TextStyle(color: Colors.grey[400])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFFE84C3D))),
          ),
        ],
      ),
    );
  }

  void _viewProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: int.parse(widget.recipientId)),
      ),
    );
  }

  Future<void> _toggleMuteNotification(bool value) async {
    setState(() => _isMuted = value);
    
    try {
      await _messageService.updateConversationSettings(
        widget.recipientId,
        isMuted: value,
      );
      // No dialog - toggle already shows the state
    } catch (e) {
      // Revert on error
      setState(() => _isMuted = !value);
      _showErrorDialog('Không thể cập nhật cài đặt');
    }
  }

  Future<void> _togglePinConversation(bool value) async {
    setState(() => _isPinned = value);
    
    try {
      await _messageService.updateConversationSettings(
        widget.recipientId,
        isPinned: value,
      );
      // No dialog - toggle already shows the state
    } catch (e) {
      // Revert on error
      setState(() => _isPinned = !value);
      _showErrorDialog('Không thể cập nhật cài đặt');
    }
  }

  void _blockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Chặn người dùng', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bạn có chắc muốn chặn ${widget.recipientUsername}?\n\nHọ sẽ không thể:\n• Gửi tin nhắn cho bạn\n• Xem trang cá nhân của bạn\n• Tìm thấy bạn trong tìm kiếm',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy', style: TextStyle(color: Colors.grey[500])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _performBlockUser();
            },
            child: const Text('Chặn', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performBlockUser() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      final currentUserId = currentUser?['id']?.toString();
      await _apiService.blockUser(widget.recipientId, currentUserId: currentUserId);
      
      if (mounted) {
        setState(() {
          _isBlocked = true;
        });
        
        // Navigate back to chat screen directly after blocking
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Không thể chặn người dùng');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tùy chọn',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Profile header
                  _buildProfileHeader(),
                  
                  const SizedBox(height: 32),
                  
                  // Settings section
                  _buildSettingsSection(),
                  
                  const SizedBox(height: 16),
                  
                  // Danger zone
                  _buildDangerSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        // Avatar
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey[800],
          backgroundImage: widget.recipientAvatar != null
              ? NetworkImage(widget.recipientAvatar!)
              : null,
          child: widget.recipientAvatar == null
              ? Icon(Icons.person, color: Colors.grey[500], size: 50)
              : null,
        ),
        const SizedBox(height: 16),
        
        // Username
        Text(
          widget.recipientUsername,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        
        // View profile button
        GestureDetector(
          onTap: _viewProfile,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Xem hồ sơ',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildOptionItem(
            icon: Icons.notifications_off_outlined,
            label: 'Tắt thông báo',
            subtitle: _isMuted ? 'Đã tắt' : 'Đang bật',
            hasSwitch: true,
            switchValue: _isMuted,
            onSwitchChanged: _toggleMuteNotification,
          ),
          Divider(color: Colors.grey[800], height: 1, indent: 56),
          _buildOptionItem(
            icon: Icons.push_pin_outlined,
            label: 'Ghim lên đầu',
            subtitle: _isPinned ? 'Đã ghim' : 'Chưa ghim',
            hasSwitch: true,
            switchValue: _isPinned,
            onSwitchChanged: _togglePinConversation,
          ),
        ],
      ),
    );
  }

  Widget _buildDangerSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (_isBlocked)
            _buildOptionItem(
              icon: Icons.lock_open,
              label: 'Bỏ chặn',
              subtitle: 'Cho phép người này liên hệ với bạn',
              textColor: Colors.green,
              iconColor: Colors.green,
              onTap: _unblockUser,
            )
          else
            _buildOptionItem(
              icon: Icons.block,
              label: 'Chặn',
              subtitle: 'Chặn người dùng này',
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: _blockUser,
            ),
          Divider(color: Colors.grey[800], height: 1, indent: 56),
          _buildOptionItem(
            icon: Icons.list,
            label: 'Danh sách chặn',
            subtitle: 'Quản lý người dùng đã chặn',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
              ).then((_) => _loadSettings());
            },
          ),
        ],
      ),
    );
  }

  void _unblockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bỏ chặn người dùng', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bạn có chắc muốn bỏ chặn ${widget.recipientUsername}?\n\nHọ sẽ có thể gửi tin nhắn cho bạn.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy', style: TextStyle(color: Colors.grey[500])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performUnblockUser();
            },
            child: const Text('Bỏ chặn', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Future<void> _performUnblockUser() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      final currentUserId = currentUser?['id']?.toString();
      final success = await _apiService.unblockUser(widget.recipientId, currentUserId: currentUserId);
      
      if (success && mounted) {
        setState(() {
          _isBlocked = false;
        });
        
        _showSuccessDialog(
          title: 'Đã bỏ chặn',
          message: 'Bạn đã bỏ chặn ${widget.recipientUsername}. Họ có thể gửi tin nhắn cho bạn.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Không thể bỏ chặn người dùng');
      }
    }
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String label,
    String? subtitle,
    bool hasSwitch = false,
    bool switchValue = false,
    ValueChanged<bool>? onSwitchChanged,
    VoidCallback? onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: hasSwitch ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (iconColor ?? Colors.white).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: iconColor ?? Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor ?? Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
            if (hasSwitch)
              Switch(
                value: switchValue,
                onChanged: onSwitchChanged,
                activeColor: const Color(0xFFE84C3D),
                activeTrackColor: const Color(0xFFE84C3D).withOpacity(0.5),
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[700],
              )
            else
              Icon(Icons.chevron_right, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}
