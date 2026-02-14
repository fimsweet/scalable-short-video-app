import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:intl/intl.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final VideoService _videoService = VideoService();
  
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 1;
  String _currentFilter = 'all';
  final ScrollController _scrollController = ScrollController();
  final Set<String> _expandedDates = {};
  static const int _initialShowCount = 3;

  final List<Map<String, dynamic>> _filters = [
    {'key': 'all', 'icon': Icons.grid_view_rounded},
    {'key': 'videos', 'icon': Icons.videocam_outlined},
    {'key': 'social', 'icon': Icons.people_alt_outlined},
    {'key': 'comments', 'icon': Icons.chat_bubble_outline},
  ];

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _scrollController.addListener(_onScroll);
    _loadActivities();
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMoreActivities();
      }
    }
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });

    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        final result = await _apiService.getActivityHistory(
          currentUser['id'].toString(),
          page: 1,
          limit: 20,
          filter: _currentFilter,
        );

        if (mounted) {
          setState(() {
            _activities = List<Map<String, dynamic>>.from(result['activities'] ?? []);
            _hasMore = result['hasMore'] ?? false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading activities: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreActivities() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);

    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        _currentPage++;
        final result = await _apiService.getActivityHistory(
          currentUser['id'].toString(),
          page: _currentPage,
          limit: 20,
          filter: _currentFilter,
        );

        if (mounted) {
          setState(() {
            _activities.addAll(List<Map<String, dynamic>>.from(result['activities'] ?? []));
            _hasMore = result['hasMore'] ?? false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading more activities: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentPage--;
        });
      }
    }
  }

  void _onFilterChanged(String filter) {
    if (filter != _currentFilter) {
      setState(() {
        _currentFilter = filter;
        _activities.clear();
        _expandedDates.clear();
      });
      _loadActivities();
    }
  }

  void _navigateToActivity(Map<String, dynamic> activity) async {
    final actionType = activity['actionType'] as String? ?? '';
    final targetId = activity['targetId'] as String?;
    final targetType = activity['targetType'] as String?;

    if (targetType == 'video' && targetId != null) {
      // Fetch video details first
      final videoData = await _videoService.getVideoById(targetId);
      if (videoData != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoDetailScreen(
              videos: [videoData],
              initialIndex: 0,
              openCommentsOnLoad: actionType == 'comment',
            ),
          ),
        );
      }
    } else if (targetType == 'user' && targetId != null) {
      // Navigate to user profile
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(
            userId: int.tryParse(targetId) ?? 0,
          ),
        ),
      );
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
          _localeService.get('activity_history'),
          style: TextStyle(color: _themeService.textPrimaryColor, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (_activities.isNotEmpty)
            IconButton(
              icon: Icon(Icons.more_vert, color: _themeService.iconColor),
              onPressed: _showManageMenu,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(
            child: _isLoading && _activities.isEmpty
                ? Center(child: CircularProgressIndicator(color: ThemeService.accentColor))
                : _activities.isEmpty
                    ? _buildEmptyState()
                    : _buildActivityList(),
          ),
        ],
      ),
    );
  }

  void _showManageMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: _themeService.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _themeService.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.manage_history,
                        color: ThemeService.accentColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _localeService.isVietnamese ? 'Quản lý lịch sử' : 'Manage History',
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Section: Delete by time range
                _buildSectionHeader(
                  _localeService.isVietnamese ? 'Xóa theo thời gian' : 'Delete by Time',
                  Icons.schedule,
                ),
                _buildManageOption(
                  icon: Icons.today,
                  title: _localeService.isVietnamese ? 'Xóa hoạt động hôm nay' : 'Delete today\'s activities',
                  subtitle: _localeService.isVietnamese
                      ? 'Chỉ xóa hoạt động trong ngày hôm nay'
                      : 'Only delete activities from today',
                  color: Colors.teal,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteByTimeRangeDialog('today');
                  },
                ),
                _buildManageOption(
                  icon: Icons.date_range,
                  title: _localeService.isVietnamese ? 'Xóa hoạt động 7 ngày qua' : 'Delete last 7 days',
                  subtitle: _localeService.isVietnamese
                      ? 'Xóa hoạt động trong tuần qua'
                      : 'Delete activities from the past week',
                  color: Colors.indigo,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteByTimeRangeDialog('week');
                  },
                ),
                _buildManageOption(
                  icon: Icons.calendar_month,
                  title: _localeService.isVietnamese ? 'Xóa hoạt động 30 ngày qua' : 'Delete last 30 days',
                  subtitle: _localeService.isVietnamese
                      ? 'Xóa hoạt động trong tháng qua'
                      : 'Delete activities from the past month',
                  color: Colors.deepPurple,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteByTimeRangeDialog('month');
                  },
                ),

                const SizedBox(height: 8),
                Divider(color: _themeService.dividerColor, height: 1),
                const SizedBox(height: 8),

                // Section: Delete by type
                _buildSectionHeader(
                  _localeService.isVietnamese ? 'Xóa theo loại' : 'Delete by Type',
                  Icons.category_outlined,
                ),
                _buildManageOption(
                  icon: Icons.favorite_outline,
                  title: _localeService.isVietnamese ? 'Xóa lịch sử thích' : 'Delete like history',
                  subtitle: _localeService.isVietnamese
                      ? 'Xóa tất cả hoạt động thích video'
                      : 'Remove all video like activities',
                  color: Colors.pink,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteByTypeDialog('likes');
                  },
                ),
                _buildManageOption(
                  icon: Icons.chat_bubble_outline,
                  title: _localeService.isVietnamese ? 'Xóa lịch sử bình luận' : 'Delete comment history',
                  subtitle: _localeService.isVietnamese
                      ? 'Xóa tất cả hoạt động bình luận'
                      : 'Remove all comment activities',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteByTypeDialog('comments');
                  },
                ),
                _buildManageOption(
                  icon: Icons.person_add_outlined,
                  title: _localeService.isVietnamese ? 'Xóa lịch sử theo dõi' : 'Delete follow history',
                  subtitle: _localeService.isVietnamese
                      ? 'Xóa tất cả hoạt động theo dõi'
                      : 'Remove all follow activities',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteByTypeDialog('follows');
                  },
                ),

                const SizedBox(height: 8),
                Divider(color: _themeService.dividerColor, height: 1),
                const SizedBox(height: 8),

                // Section: Danger zone
                _buildSectionHeader(
                  _localeService.isVietnamese ? 'Vùng nguy hiểm' : 'Danger Zone',
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                ),
                _buildManageOption(
                  icon: Icons.delete_forever_outlined,
                  title: _localeService.isVietnamese ? 'Xóa tất cả lịch sử' : 'Delete all history',
                  subtitle: _localeService.isVietnamese
                      ? 'Xóa toàn bộ lịch sử hoạt động vĩnh viễn'
                      : 'Permanently remove all activity history',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteAll();
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: color ?? _themeService.textSecondaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color ?? _themeService.textSecondaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManageOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: _themeService.textPrimaryColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: _themeService.textSecondaryColor,
          fontSize: 12,
        ),
      ),
      onTap: onTap,
    );
  }

  String _getFilterName(String filter) {
    switch (filter) {
      case 'videos': return _localeService.isVietnamese ? 'video' : 'videos';
      case 'social': return _localeService.isVietnamese ? 'xã hội' : 'social';
      case 'comments': return _localeService.isVietnamese ? 'bình luận' : 'comments';
      case 'likes': return _localeService.isVietnamese ? 'lượt thích' : 'likes';
      case 'follows': return _localeService.isVietnamese ? 'theo dõi' : 'follows';
      default: return filter;
    }
  }

  String _getTimeRangeName(String timeRange) {
    switch (timeRange) {
      case 'today': return _localeService.isVietnamese ? 'hôm nay' : 'today';
      case 'week': return _localeService.isVietnamese ? '7 ngày qua' : 'last 7 days';
      case 'month': return _localeService.isVietnamese ? '30 ngày qua' : 'last 30 days';
      case 'all': return _localeService.isVietnamese ? 'tất cả' : 'all time';
      default: return timeRange;
    }
  }

  // Show delete by time range dialog with count preview
  void _showDeleteByTimeRangeDialog(String timeRange) async {
    final userId = _authService.userId?.toString();
    if (userId == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ThemeService.accentColor,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              _localeService.isVietnamese ? 'Đang kiểm tra...' : 'Checking...',
              style: TextStyle(color: _themeService.textPrimaryColor),
            ),
          ],
        ),
      ),
    );

    // Get count
    final result = await _apiService.getActivityCount(userId, timeRange, filter: _currentFilter);
    final count = result['count'] as int? ?? 0;

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    // Show confirmation dialog with count
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_sweep, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _localeService.isVietnamese ? 'Xác nhận xóa' : 'Confirm Delete',
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _themeService.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: ThemeService.accentColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _localeService.isVietnamese
                          ? 'Tìm thấy $count hoạt động'
                          : 'Found $count activities',
                      style: TextStyle(
                        color: _themeService.textPrimaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _localeService.isVietnamese
                  ? 'Bạn có chắc muốn xóa tất cả hoạt động ${_getTimeRangeName(timeRange)}${_currentFilter != 'all' ? ' (${_getFilterName(_currentFilter)})' : ''}?'
                  : 'Are you sure you want to delete all activities from ${_getTimeRangeName(timeRange)}${_currentFilter != 'all' ? ' (${_getFilterName(_currentFilter)})' : ''}?',
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _localeService.isVietnamese
                  ? '⚠️ Hành động này không thể hoàn tác.'
                  : '⚠️ This action cannot be undone.',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _localeService.isVietnamese ? 'Hủy' : 'Cancel',
              style: TextStyle(color: _themeService.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: count > 0 ? () {
              Navigator.pop(context);
              _deleteByTimeRange(timeRange);
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              disabledBackgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              _localeService.isVietnamese ? 'Xóa $count hoạt động' : 'Delete $count activities',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // Show delete by type dialog with count preview
  void _showDeleteByTypeDialog(String type) async {
    final userId = _authService.userId?.toString();
    if (userId == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ThemeService.accentColor,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              _localeService.isVietnamese ? 'Đang kiểm tra...' : 'Checking...',
              style: TextStyle(color: _themeService.textPrimaryColor),
            ),
          ],
        ),
      ),
    );

    // Get count
    final result = await _apiService.getActivityCount(userId, 'all', filter: type);
    final count = result['count'] as int? ?? 0;

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    // Get icon and color for type
    IconData typeIcon;
    Color typeColor;
    switch (type) {
      case 'likes':
        typeIcon = Icons.favorite;
        typeColor = Colors.pink;
        break;
      case 'comments':
        typeIcon = Icons.chat_bubble;
        typeColor = Colors.blue;
        break;
      case 'follows':
        typeIcon = Icons.person_add;
        typeColor = Colors.purple;
        break;
      default:
        typeIcon = Icons.history;
        typeColor = Colors.grey;
    }

    // Show confirmation dialog with count
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(typeIcon, color: typeColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _localeService.isVietnamese 
                    ? 'Xóa lịch sử ${_getFilterName(type)}'
                    : 'Delete ${_getFilterName(type)} history',
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _themeService.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: typeColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _localeService.isVietnamese
                          ? 'Tìm thấy $count hoạt động ${_getFilterName(type)}'
                          : 'Found $count ${_getFilterName(type)} activities',
                      style: TextStyle(
                        color: _themeService.textPrimaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _localeService.isVietnamese
                  ? 'Xóa tất cả lịch sử ${_getFilterName(type)} của bạn?'
                  : 'Delete all your ${_getFilterName(type)} history?',
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _localeService.isVietnamese
                  ? '⚠️ Hành động này không thể hoàn tác.'
                  : '⚠️ This action cannot be undone.',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _localeService.isVietnamese ? 'Hủy' : 'Cancel',
              style: TextStyle(color: _themeService.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: count > 0 ? () {
              Navigator.pop(context);
              _deleteByType(type);
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: typeColor,
              disabledBackgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              _localeService.isVietnamese ? 'Xóa $count hoạt động' : 'Delete $count',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteByTimeRange(String timeRange) async {
    final userId = _authService.userId?.toString();
    if (userId == null) return;

    final result = await _apiService.deleteActivitiesByTimeRange(
      userId, 
      timeRange, 
      filter: _currentFilter != 'all' ? _currentFilter : null,
    );
    
    if (result['success'] == true && mounted) {
      final deletedCount = result['deletedCount'] as int? ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _localeService.isVietnamese 
                      ? 'Đã xóa $deletedCount hoạt động'
                      : 'Deleted $deletedCount activities',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      _refreshActivities();
    }
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Text(
              _localeService.isVietnamese ? 'Cảnh báo' : 'Warning',
              style: TextStyle(color: _themeService.textPrimaryColor),
            ),
          ],
        ),
        content: Text(
          _localeService.isVietnamese 
              ? 'Bạn có chắc muốn xóa TẤT CẢ lịch sử hoạt động? Hành động này không thể hoàn tác!'
              : 'Are you sure you want to delete ALL activity history? This action cannot be undone!',
          style: TextStyle(color: _themeService.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _localeService.isVietnamese ? 'Hủy' : 'Cancel',
              style: TextStyle(color: _themeService.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAll();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              _localeService.isVietnamese ? 'Xóa tất cả' : 'Delete All',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteByType(String type) async {
    final userId = _authService.userId?.toString();
    if (userId == null) return;

    final result = await _apiService.deleteActivitiesByType(userId, type);
    if (result['success'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _localeService.isVietnamese 
                ? 'Đã xóa ${result['deletedCount']} hoạt động'
                : 'Deleted ${result['deletedCount']} activities',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _refreshActivities();
    }
  }

  Future<void> _deleteAll() async {
    final userId = _authService.userId?.toString();
    if (userId == null) return;

    final result = await _apiService.deleteAllActivities(userId);
    if (result['success'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _localeService.isVietnamese 
                ? 'Đã xóa ${result['deletedCount']} hoạt động'
                : 'Deleted ${result['deletedCount']} activities',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _refreshActivities();
    }
  }

  Future<void> _deleteActivity(int activityId) async {
    final userId = _authService.userId?.toString();
    if (userId == null) return;

    final result = await _apiService.deleteActivity(userId, activityId);
    if (result['success'] == true && mounted) {
      setState(() {
        _activities.removeWhere((a) => a['id'] == activityId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _localeService.isVietnamese ? 'Đã xóa hoạt động' : 'Activity deleted',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _refreshActivities() {
    setState(() {
      _activities = [];
      _currentPage = 1;
      _hasMore = true;
      _expandedDates.clear();
    });
    _loadActivities();
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _themeService.cardColor,
        border: Border(
          bottom: BorderSide(
            color: _themeService.dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _currentFilter == filter['key'];
          return Expanded(
            child: GestureDetector(
              onTap: () => _onFilterChanged(filter['key']),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? ThemeService.accentColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected 
                        ? ThemeService.accentColor
                        : _themeService.dividerColor,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      filter['icon'] as IconData,
                      color: isSelected 
                          ? ThemeService.accentColor
                          : _themeService.textSecondaryColor,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _localeService.get('activity_filter_${filter['key']}'),
                      style: TextStyle(
                        color: isSelected 
                            ? ThemeService.accentColor
                            : _themeService.textSecondaryColor,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history,
              size: 60,
              color: _themeService.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _localeService.get('no_activity'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _themeService.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _localeService.get('no_activity_desc'),
            style: TextStyle(
              fontSize: 14,
              color: _themeService.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    // Group activities by date
    final Map<String, List<Map<String, dynamic>>> groupedActivities = {};
    
    for (var activity in _activities) {
      final date = DateTime.tryParse(activity['createdAt'] ?? '') ?? DateTime.now();
      final dateKey = _getDateKey(date);
      groupedActivities.putIfAbsent(dateKey, () => []);
      groupedActivities[dateKey]!.add(activity);
    }

    return RefreshIndicator(
      onRefresh: _loadActivities,
      color: ThemeService.accentColor,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: groupedActivities.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == groupedActivities.length) {
            return _isLoading
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ThemeService.accentColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _localeService.isVietnamese ? 'Đang tải thêm...' : 'Loading more...',
                            style: TextStyle(
                              color: _themeService.textSecondaryColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink();
          }

          final dateKey = groupedActivities.keys.elementAt(index);
          final activities = groupedActivities[dateKey]!;
          final isExpanded = _expandedDates.contains(dateKey);
          final hasMore = activities.length > _initialShowCount;
          final visibleActivities = isExpanded
              ? activities
              : activities.take(_initialShowCount).toList();
          final remainingCount = activities.length - _initialShowCount;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header with count — tappable to toggle expand/collapse
              GestureDetector(
                onTap: hasMore ? () {
                  setState(() {
                    if (isExpanded) {
                      _expandedDates.remove(dateKey);
                    } else {
                      _expandedDates.add(dateKey);
                    }
                  });
                } : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        dateKey,
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _themeService.isLightMode
                              ? Colors.grey[200]
                              : Colors.grey[800],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${activities.length}',
                          style: TextStyle(
                            color: _themeService.textSecondaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (hasMore) ...[
                        const Spacer(),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 20,
                          color: _themeService.textSecondaryColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Activity items
              ...visibleActivities.map((activity) => _buildActivityItem(activity)),
              // "Show more" button
              if (hasMore && !isExpanded)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _expandedDates.add(dateKey);
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _themeService.isLightMode
                          ? Colors.grey[100]
                          : Colors.grey[850],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _themeService.isLightMode
                            ? Colors.grey[300]!
                            : Colors.grey[700]!,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.expand_more,
                          size: 18,
                          color: ThemeService.accentColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _localeService.isVietnamese
                              ? 'Xem thêm $remainingCount hoạt động'
                              : 'Show $remainingCount more',
                          style: TextStyle(
                            color: ThemeService.accentColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (index < groupedActivities.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Divider(
                    color: _themeService.dividerColor.withValues(alpha: 0.3),
                    thickness: 0.5,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final activityId = activity['id'] as int?;
    final actionType = activity['actionType'] as String? ?? 'unknown';
    final createdAt = DateTime.tryParse(activity['createdAt'] ?? '') ?? DateTime.now();
    final metadata = activity['metadata'] as Map<String, dynamic>? ?? {};
    final targetType = activity['targetType'] as String?;
    
    final activityInfo = _getActivityInfo(actionType);
    final detailText = _getDetailText(actionType, metadata);
    final thumbnailUrl = _getThumbnailUrl(actionType, metadata, targetType);

    return Dismissible(
      key: Key('activity_${activityId ?? DateTime.now().millisecondsSinceEpoch}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade500,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text(
              'Xóa',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _themeService.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              _localeService.isVietnamese ? 'Xóa hoạt động?' : 'Delete activity?',
              style: TextStyle(color: _themeService.textPrimaryColor, fontSize: 17),
            ),
            content: Text(
              _localeService.isVietnamese 
                  ? 'Hoạt động này sẽ bị xóa khỏi lịch sử.'
                  : 'This activity will be removed from history.',
              style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  _localeService.isVietnamese ? 'Hủy' : 'Cancel',
                  style: TextStyle(color: _themeService.textSecondaryColor),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Xóa',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        if (activityId != null) {
          _deleteActivity(activityId);
        }
      },
      child: GestureDetector(
        onTap: () => _navigateToActivity(activity),
        onLongPress: () => _showActivityOptions(activity),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: _themeService.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _themeService.isLightMode 
                ? Colors.grey.shade200 
                : Colors.grey.shade800,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _themeService.isLightMode
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
              if (_themeService.isLightMode)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _navigateToActivity(activity),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Activity icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (activityInfo['color'] as Color).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        activityInfo['icon'] as IconData,
                        color: activityInfo['color'] as Color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _localeService.get('activity_$actionType'),
                            style: TextStyle(
                              color: _themeService.textPrimaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (detailText.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              detailText,
                              style: TextStyle(
                                color: _themeService.textSecondaryColor,
                                fontSize: 13,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            _formatRelativeTime(createdAt),
                            style: TextStyle(
                              color: _themeService.textSecondaryColor.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Thumbnail or avatar
                    if (thumbnailUrl != null) ...[
                      const SizedBox(width: 12),
                      _buildThumbnail(thumbnailUrl, targetType, activityInfo['color'] as Color),
                    ],
                    // Arrow indicator
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: _themeService.textSecondaryColor.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showActivityOptions(Map<String, dynamic> activity) {
    final activityId = activity['id'] as int?;
    if (activityId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _themeService.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _themeService.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                ),
                title: Text(
                  _localeService.isVietnamese ? 'Xóa hoạt động này' : 'Delete this activity',
                  style: TextStyle(
                    color: _themeService.textPrimaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  _localeService.isVietnamese 
                      ? 'Xóa khỏi lịch sử hoạt động'
                      : 'Remove from activity history',
                  style: TextStyle(
                    color: _themeService.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteSingle(activityId);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteSingle(int activityId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _localeService.isVietnamese ? 'Xóa hoạt động?' : 'Delete activity?',
          style: TextStyle(color: _themeService.textPrimaryColor, fontSize: 17),
        ),
        content: Text(
          _localeService.isVietnamese 
              ? 'Hoạt động này sẽ bị xóa khỏi lịch sử.'
              : 'This activity will be removed from history.',
          style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _localeService.isVietnamese ? 'Hủy' : 'Cancel',
              style: TextStyle(color: _themeService.textSecondaryColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteActivity(activityId);
            },
            child: const Text(
              'Xóa',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(String url, String? targetType, Color accentColor) {
    final isUser = targetType == 'user';
    final fullUrl = isUser 
        ? _apiService.getAvatarUrl(url) 
        : _videoService.getVideoUrl(url);

    if (isUser) {
      // Circular avatar for user
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: accentColor.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: Image.network(
            fullUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: _themeService.inputBackground,
                child: Icon(Icons.person, color: _themeService.textSecondaryColor, size: 24),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              color: _themeService.inputBackground,
              child: Icon(Icons.person, color: _themeService.textSecondaryColor, size: 24),
            ),
          ),
        ),
      );
    } else {
      // Rounded rectangle for video thumbnail
      return Container(
        width: 56,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _themeService.dividerColor,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.network(
            fullUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: _themeService.inputBackground,
                child: Icon(Icons.play_arrow, color: _themeService.textSecondaryColor, size: 24),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              color: _themeService.inputBackground,
              child: Icon(Icons.play_arrow, color: _themeService.textSecondaryColor, size: 24),
            ),
          ),
        ),
      );
    }
  }

  String _getDetailText(String actionType, Map<String, dynamic> metadata) {
    switch (actionType) {
      case 'like':
      case 'unlike':
        final title = metadata['videoTitle'] as String?;
        if (title != null && title.isNotEmpty) {
          return title;
        }
        // Default text when no metadata
        return _localeService.isVietnamese 
            ? 'Nhấn để xem video' 
            : 'Tap to view video';
      
      case 'comment':
        final content = metadata['content'] as String?;
        if (content != null && content.isNotEmpty) {
          return '"$content"';
        }
        final videoTitle = metadata['videoTitle'] as String?;
        if (videoTitle != null && videoTitle.isNotEmpty) {
          return videoTitle;
        }
        return _localeService.isVietnamese 
            ? 'Nhấn để xem bình luận' 
            : 'Tap to view comment';
      
      case 'comment_deleted':
        return _localeService.isVietnamese ? 'Bình luận đã bị xóa' : 'Comment was deleted';
      
      case 'follow':
      case 'unfollow':
        final username = metadata['targetUsername'] as String?;
        final fullName = metadata['targetFullName'] as String?;
        if (username != null) {
          return '@$username${fullName != null ? ' • $fullName' : ''}';
        }
        return _localeService.isVietnamese 
            ? 'Nhấn để xem trang cá nhân' 
            : 'Tap to view profile';
      
      case 'video_posted':
        final title = metadata['title'] as String?;
        return title ?? (_localeService.isVietnamese ? 'Đã đăng video mới' : 'Posted a new video');
      
      case 'video_deleted':
        return _localeService.isVietnamese ? 'Video đã bị xóa' : 'Video was deleted';
      
      case 'video_hidden':
        return _localeService.isVietnamese ? 'Video đã ẩn' : 'Video is now private';
      
      default:
        return '';
    }
  }

  String? _getThumbnailUrl(String actionType, Map<String, dynamic> metadata, String? targetType) {
    if (targetType == 'user') {
      // For follow/unfollow, show user avatar
      return metadata['targetAvatar'] as String?;
    } else if (targetType == 'video') {
      // For video actions, show thumbnail
      return metadata['videoThumbnail'] as String?;
    }
    return null;
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    final isVi = _localeService.isVietnamese;

    if (diff.inMinutes < 1) {
      return isVi ? 'Vừa xong' : 'Just now';
    } else if (diff.inMinutes < 60) {
      return isVi ? '${diff.inMinutes} phút trước' : '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return isVi ? '${diff.inHours} giờ trước' : '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return isVi ? '${diff.inDays} ngày trước' : '${diff.inDays}d ago';
    } else {
      return DateFormat('HH:mm').format(dateTime);
    }
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return _localeService.get('activity_today');
    } else if (dateOnly == yesterday) {
      return _localeService.get('activity_yesterday');
    } else {
      return DateFormat(_localeService.isVietnamese ? 'dd/MM/yyyy' : 'MMM dd, yyyy').format(date);
    }
  }

  Map<String, dynamic> _getActivityInfo(String actionType) {
    switch (actionType) {
      case 'video_posted':
        return {'icon': Icons.upload_outlined, 'color': Colors.green};
      case 'video_deleted':
        return {'icon': Icons.delete_outline, 'color': Colors.red};
      case 'video_hidden':
        return {'icon': Icons.visibility_off_outlined, 'color': Colors.orange};
      case 'like':
        return {'icon': Icons.favorite, 'color': Colors.pink};
      case 'unlike':
        return {'icon': Icons.favorite_border, 'color': Colors.grey};
      case 'comment':
        return {'icon': Icons.chat_bubble, 'color': Colors.blue};
      case 'comment_deleted':
        return {'icon': Icons.chat_bubble_outline, 'color': Colors.grey};
      case 'follow':
        return {'icon': Icons.person_add, 'color': Colors.purple};
      case 'unfollow':
        return {'icon': Icons.person_remove, 'color': Colors.grey};
      default:
        return {'icon': Icons.history, 'color': ThemeService.accentColor};
    }
  }
}
