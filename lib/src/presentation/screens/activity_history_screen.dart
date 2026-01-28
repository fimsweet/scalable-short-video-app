import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
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
  
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 1;
  String _currentFilter = 'all';
  final ScrollController _scrollController = ScrollController();

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
      });
      _loadActivities();
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
          icon: Icon(Icons.arrow_back_ios_new, color: _themeService.iconColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _localeService.get('activity_history'),
          style: TextStyle(color: _themeService.textPrimaryColor, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
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
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }

          final dateKey = groupedActivities.keys.elementAt(index);
          final activities = groupedActivities[dateKey]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  dateKey,
                  style: TextStyle(
                    color: _themeService.textSecondaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...activities.map((activity) => _buildActivityItem(activity)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final actionType = activity['actionType'] as String? ?? 'unknown';
    final createdAt = DateTime.tryParse(activity['createdAt'] ?? '') ?? DateTime.now();
    final metadata = activity['metadata'] as Map<String, dynamic>? ?? {};
    
    final activityInfo = _getActivityInfo(actionType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.grey[50] : Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _themeService.isLightMode ? Colors.grey[200]! : Colors.grey[800]!,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: activityInfo['color'].withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              activityInfo['icon'] as IconData,
              color: activityInfo['color'] as Color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
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
                if (metadata['title'] != null || metadata['content'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    metadata['title'] ?? metadata['content'] ?? '',
                    style: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  DateFormat('HH:mm').format(createdAt),
                  style: TextStyle(
                    color: _themeService.textSecondaryColor.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
