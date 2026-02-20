import 'package:flutter/material.dart';
import '../../services/follow_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../services/locale_service.dart';
import 'user_profile_screen.dart';

class FollowRequestsScreen extends StatefulWidget {
  const FollowRequestsScreen({super.key});

  @override
  State<FollowRequestsScreen> createState() => _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends State<FollowRequestsScreen> {
  final FollowService _followService = FollowService();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();

  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  bool _hasMore = false;
  int _offset = 0;
  final int _limit = 20;

  // Track processing state for each request
  final Set<int> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _loadRequests();
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadRequests({bool loadMore = false}) async {
    if (!_authService.isLoggedIn || _authService.user == null) return;

    if (!loadMore) {
      setState(() => _isLoading = true);
      _offset = 0;
    }

    final userId = _authService.user!['id'] as int;
    final result = await _followService.getPendingRequests(
      userId,
      limit: _limit,
      offset: _offset,
    );

    if (mounted) {
      setState(() {
        if (loadMore) {
          _requests.addAll(List<Map<String, dynamic>>.from(result['data'] ?? []));
        } else {
          _requests = List<Map<String, dynamic>>.from(result['data'] ?? []);
        }
        _hasMore = result['hasMore'] ?? false;
        _isLoading = false;
      });
    }
  }

  Future<void> _approveRequest(int followerId) async {
    if (_processingIds.contains(followerId)) return;
    
    final userId = _authService.user!['id'] as int;
    setState(() => _processingIds.add(followerId));

    final success = await _followService.approveFollowRequest(followerId, userId);

    if (mounted) {
      setState(() {
        _processingIds.remove(followerId);
        if (success) {
          _requests.removeWhere((r) => r['userId'] == followerId);
        }
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localeService.isVietnamese 
                ? 'Đã chấp nhận yêu cầu theo dõi' 
                : 'Follow request accepted'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(int followerId) async {
    if (_processingIds.contains(followerId)) return;
    
    final userId = _authService.user!['id'] as int;
    setState(() => _processingIds.add(followerId));

    final success = await _followService.rejectFollowRequest(followerId, userId);

    if (mounted) {
      setState(() {
        _processingIds.remove(followerId);
        if (success) {
          _requests.removeWhere((r) => r['userId'] == followerId);
        }
      });
    }
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
        title: Text(
          _localeService.isVietnamese ? 'Yêu cầu theo dõi' : 'Follow Requests',
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: _themeService.textPrimaryColor,
              ),
            )
          : _requests.isEmpty
              ? _buildEmptyState()
              : _buildRequestsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_add_disabled_outlined,
            size: 64,
            color: _themeService.textSecondaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _localeService.isVietnamese 
                ? 'Không có yêu cầu theo dõi nào' 
                : 'No follow requests',
            style: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200 &&
            _hasMore &&
            !_isLoading) {
          _offset += _limit;
          _loadRequests(loadMore: true);
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _loadRequests,
        color: const Color(0xFFFF2D55),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _requests.length,
          itemBuilder: (context, index) {
            final request = _requests[index];
            return _buildRequestItem(request);
          },
        ),
      ),
    );
  }

  Widget _buildRequestItem(Map<String, dynamic> request) {
    final userId = request['userId'] as int;
    final username = request['username'] ?? 'user';
    final fullName = request['fullName'] as String?;
    final avatar = request['avatar'] as String?;
    final isProcessing = _processingIds.contains(userId);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: userId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
              backgroundImage: avatar != null && avatar.isNotEmpty && _apiService.getAvatarUrl(avatar).isNotEmpty
                  ? NetworkImage(_apiService.getAvatarUrl(avatar))
                  : null,
              child: avatar == null || avatar.isEmpty || _apiService.getAvatarUrl(avatar).isEmpty
                  ? Icon(Icons.person, color: _themeService.textSecondaryColor, size: 24)
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
                      color: _themeService.textPrimaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (fullName != null && fullName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      fullName,
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Approve / Reject buttons
            if (isProcessing)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Approve button
                  GestureDetector(
                    onTap: () => _approveRequest(userId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2D55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _localeService.isVietnamese ? 'Chấp nhận' : 'Accept',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Reject button
                  GestureDetector(
                    onTap: () => _rejectRequest(userId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _themeService.isLightMode ? Colors.grey[200] : Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _localeService.isVietnamese ? 'Từ chối' : 'Reject',
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
