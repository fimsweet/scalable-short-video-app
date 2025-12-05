import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        final users = await _apiService.getBlockedUsers(currentUser['id'].toString());
        if (mounted) {
          setState(() {
            _blockedUsers = users;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading blocked users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _unblockUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bỏ chặn người dùng', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bạn có chắc muốn bỏ chặn ${user['username']}?\n\nHọ sẽ có thể gửi tin nhắn cho bạn.',
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
              await _performUnblock(user);
            },
            child: const Text('Bỏ chặn', style: TextStyle(color: Color(0xFFE84C3D))),
          ),
        ],
      ),
    );
  }

  Future<void> _performUnblock(Map<String, dynamic> user) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      final currentUserId = currentUser?['id']?.toString();
      final success = await _apiService.unblockUser(user['id'].toString(), currentUserId: currentUserId);
      
      if (success && mounted) {
        setState(() {
          _blockedUsers.removeWhere((u) => u['id'] == user['id']);
        });
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text('Đã bỏ chặn', style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
            content: Text(
              'Bạn đã bỏ chặn ${user['username']}',
              style: TextStyle(color: Colors.grey[400]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Color(0xFFE84C3D))),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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
            content: Text(
              'Không thể bỏ chặn người dùng',
              style: TextStyle(color: Colors.grey[400]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Color(0xFFE84C3D))),
              ),
            ],
          ),
        );
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
          'Danh sách chặn',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _blockedUsers.isEmpty
              ? _buildEmptyState()
              : _buildBlockedList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, size: 80, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Không có người dùng nào bị chặn',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Khi bạn chặn ai đó, họ sẽ xuất hiện ở đây',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _blockedUsers.length,
      itemBuilder: (context, index) {
        final user = _blockedUsers[index];
        return _buildBlockedUserItem(user);
      },
    );
  }

  Widget _buildBlockedUserItem(Map<String, dynamic> user) {
    final avatarUrl = user['avatarUrl'] as String?;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[800],
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Icon(Icons.person, color: Colors.grey[500], size: 24)
              : null,
        ),
        title: Text(
          user['username'] ?? 'Unknown',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          'Đã chặn',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 13,
          ),
        ),
        trailing: TextButton(
          onPressed: () => _unblockUser(user),
          style: TextButton.styleFrom(
            backgroundColor: Colors.grey[800],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text(
            'Bỏ chặn',
            style: TextStyle(
              color: Color(0xFFE84C3D),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
