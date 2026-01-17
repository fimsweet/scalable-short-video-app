import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/share_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

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
  final LocaleService _localeService = LocaleService();
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
      
      // Load followers and blocked users in parallel
      final results = await Future.wait([
        _apiService.getFollowers(userId),
        _apiService.getBlockedUsers(userId),
      ]);
      
      final followers = results[0] as List<dynamic>;
      final blockedUsers = results[1] as List<dynamic>;
      
      // Get set of blocked user IDs for fast lookup
      final blockedUserIds = blockedUsers
          .map((u) => u['blockedUserId']?.toString() ?? u['id']?.toString())
          .whereType<String>()
          .toSet();
      
      // Filter out blocked users from followers list
      final filteredList = followers
          .where((user) => !blockedUserIds.contains(user['id']?.toString()))
          .toList();
      
      if (mounted) {
        setState(() {
          _followers = List<Map<String, dynamic>>.from(filteredList);
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
        SnackBar(
          content: Text(_localeService.get('please_select_at_least_one')),
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
        
        // Get the root overlay BEFORE popping the sheet
        final overlay = Overlay.of(context, rootOverlay: true);
        
        Navigator.pop(context); // Close sheet
        
        // Show floating toast using root overlay
        late OverlayEntry overlayEntry;
        overlayEntry = OverlayEntry(
          builder: (context) => _AnimatedShareToast(
            message: '${LocaleService().get('shared_to_x_people')} $successCount ${LocaleService().get('people')}',
            onDismiss: () {
              overlayEntry.remove();
            },
          ),
        );
        overlay.insert(overlayEntry);
      }
    } catch (e) {
      print('❌ Error sharing video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localeService.get('cannot_share_video')),
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
                      ? '${_localeService.get('selected_x_people')} ${_selectedUserIds.length} ${_localeService.get('people')}'
                      : _localeService.get('share_to'),
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
                        _localeService.get('clear'),
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
                hintText: _localeService.get('search'),
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
                                  ? _localeService.get('no_followers_yet')
                                  : _localeService.get('no_results_found'),
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
                            '${_localeService.get('send')} (${_selectedUserIds.length})',
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
      displayNames = '${userNames.take(3).join(', ')} ${LocaleService().get('and_x_others')} ${userNames.length - 3} ${LocaleService().get('others')}';
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
            Text(
              LocaleService().get('confirm_share'),
              style: const TextStyle(
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
                '${LocaleService().get('share_video_to')} $displayNames?',
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
                        child: Text(
                          LocaleService().get('cancel'),
                          style: const TextStyle(
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
                        child: Text(
                          LocaleService().get('send'),
                          style: const TextStyle(
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

// Animated floating toast widget
class _AnimatedShareToast extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _AnimatedShareToast({
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_AnimatedShareToast> createState() => _AnimatedShareToastState();
}

class _AnimatedShareToastState extends State<_AnimatedShareToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Slide from bottom up (positive to 0)
    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    
    _controller.forward();
    
    // Auto dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 100,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3C), // Dark grey color
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
