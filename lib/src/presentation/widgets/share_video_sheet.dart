import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/share_service.dart';

class ShareVideoSheet extends StatefulWidget {
  final String videoId;
  final Function(int shareCount)? onShareComplete;

  const ShareVideoSheet({
    super.key,
    required this.videoId,
    this.onShareComplete,
  });

  @override
  State<ShareVideoSheet> createState() => _ShareVideoSheetState();
}

class _ShareVideoSheetState extends State<ShareVideoSheet> {
  final MessageService _messageService = MessageService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final ShareService _shareService = ShareService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _filteredFollowers = [];
  bool _isLoading = true;
  bool _isSending = false;
  
  // Selected users for multi-select
  Set<String> _selectedUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadFollowers();
    _searchController.addListener(_filterFollowers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowers() async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userId = _authService.user!['id'].toString();
      final followers = await _apiService.getFollowers(userId);
      
      if (mounted) {
        setState(() {
          _followers = List<Map<String, dynamic>>.from(followers);
          _filteredFollowers = _followers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading followers: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterFollowers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFollowers = _followers;
      } else {
        _filteredFollowers = _followers.where((user) {
          final username = user['username']?.toString().toLowerCase() ?? '';
          final fullName = user['fullName']?.toString().toLowerCase() ?? '';
          return username.contains(query) || fullName.contains(query);
        }).toList();
      }
    });
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  // Get selected users info
  List<Map<String, dynamic>> _getSelectedUsers() {
    return _followers.where((user) => 
      _selectedUserIds.contains(user['id']?.toString())
    ).toList();
  }

  // Show confirmation dialog
  Future<void> _showConfirmDialog() async {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một người'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedUsers = _getSelectedUsers();
    final userNames = selectedUsers
        .map((u) => (u['username'] ?? 'user').toString())
        .toList();
    
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ConfirmShareDialog(
        userNames: userNames,
        userCount: selectedUsers.length,
      ),
    );

    if (confirmed == true) {
      await _sendToSelectedUsers();
    }
  }

  Future<void> _sendToSelectedUsers() async {
    if (_isSending) return;
    
    setState(() => _isSending = true);

    try {
      final currentUserId = _authService.user!['id'].toString();
      _messageService.connect(currentUserId);

      final shareContent = '[VIDEO_SHARE:${widget.videoId}]';
      int successCount = 0;
      int lastShareCount = 0;

      for (var userId in _selectedUserIds) {
        try {
          // Send message
          await _messageService.sendMessage(
            recipientId: userId,
            content: shareContent,
          );

          // Record share
          final result = await _shareService.shareVideo(
            widget.videoId,
            currentUserId,
            userId,
          );
          
          lastShareCount = result['shareCount'] ?? lastShareCount;
          successCount++;
        } catch (e) {
          print('❌ Error sending to $userId: $e');
        }
      }

      if (mounted) {
        widget.onShareComplete?.call(lastShareCount);
        
        Navigator.pop(context); // Close sheet
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã chia sẻ cho $successCount người'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error sharing video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể chia sẻ video'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedUserIds.isNotEmpty;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          // Title with selection count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 50), // Balance the row
                Text(
                  hasSelection 
                      ? 'Đã chọn ${_selectedUserIds.length} người'
                      : 'Chia sẻ đến',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                // Clear selection button
                if (hasSelection)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedUserIds.clear();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(
                        'Xóa',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 50),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // User list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _filteredFollowers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 48, color: Colors.grey[600]),
                            const SizedBox(height: 12),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'Chưa có người theo dõi'
                                  : 'Không tìm thấy kết quả',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredFollowers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredFollowers[index];
                          final userId = user['id']?.toString() ?? '';
                          final isSelected = _selectedUserIds.contains(userId);
                          
                          return _UserSelectItem(
                            user: user,
                            isSelected: isSelected,
                            apiService: _apiService,
                            onTap: () => _toggleUserSelection(userId),
                          );
                        },
                      ),
          ),
          
          // Bottom send button - TikTok style
          if (hasSelection)
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                border: Border(
                  top: BorderSide(color: Colors.grey[800]!, width: 0.5),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _showConfirmDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2D55),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Gửi (${_selectedUserIds.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// User item with checkbox selection
class _UserSelectItem extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isSelected;
  final ApiService apiService;
  final VoidCallback onTap;

  const _UserSelectItem({
    required this.user,
    required this.isSelected,
    required this.apiService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.grey[800]?.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[800],
              backgroundImage: user['avatar'] != null
                  ? NetworkImage(apiService.getAvatarUrl(user['avatar']))
                  : null,
              child: user['avatar'] == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['username'] ?? 'user',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (user['fullName'] != null && user['fullName'].toString().isNotEmpty)
                    Text(
                      user['fullName'],
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            
            // Checkbox - TikTok style
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFF2D55) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? const Color(0xFFFF2D55) : Colors.grey[600]!,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// Confirmation dialog - TikTok style
class _ConfirmShareDialog extends StatelessWidget {
  final List<String> userNames;
  final int userCount;

  const _ConfirmShareDialog({
    required this.userNames,
    required this.userCount,
  });

  @override
  Widget build(BuildContext context) {
    // Show max 3 names, then "và X người khác"
    String displayNames;
    if (userNames.length <= 3) {
      displayNames = userNames.join(', ');
    } else {
      displayNames = '${userNames.take(3).join(', ')} và ${userNames.length - 3} người khác';
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D55).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Color(0xFFFF2D55),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            
            // Title
            const Text(
              'Xác nhận chia sẻ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Chia sẻ video này đến $displayNames?',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            
            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Cancel button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey[700]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Confirm button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF2D55),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Gửi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
