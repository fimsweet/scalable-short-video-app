import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  
  TabController? _tabController;
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  
  // Video list state
  String _sortBy = 'views'; // 'views', 'likes', 'date'
  bool _showAllVideos = false;
  static const int _initialVideoCount = 5;
  
  // Chart interaction state
  int _touchedPieIndex = -1;
  int _touchedBarIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController?.dispose();
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

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        final result = await _apiService.getAnalytics(currentUser['id'].toString());
        if (mounted && result['success'] == true) {
          setState(() {
            _analytics = result['analytics'];
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null) {
      return Scaffold(
        backgroundColor: _themeService.backgroundColor,
        body: Center(child: CircularProgressIndicator(color: ThemeService.accentColor)),
      );
    }
    
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
          _localeService.get('analytics'),
          style: TextStyle(color: _themeService.textPrimaryColor, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController!,
              indicator: BoxDecoration(
                color: ThemeService.accentColor,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: _themeService.textSecondaryColor,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              padding: const EdgeInsets.all(4),
              tabs: [
                Tab(text: _localeService.get('overview')),
                Tab(text: _localeService.get('charts')),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? _buildSkeletonLoading()
          : _analytics == null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController!,
                  children: [
                    _buildOverviewTab(),
                    _buildChartsTab(),
                  ],
                ),
    );
  }

  Widget _buildSkeletonLoading() {
    final isDark = !_themeService.isLightMode;
    final shimmerBase = isDark ? Colors.grey[850]! : Colors.grey[200]!;
    final shimmerHighlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title skeleton
          _buildShimmerBox(width: 100, height: 24, shimmerBase: shimmerBase, shimmerHighlight: shimmerHighlight),
          const SizedBox(height: 16),
          // Stats grid skeleton
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: List.generate(6, (_) => _buildStatCardSkeleton(shimmerBase, shimmerHighlight)),
          ),
          const SizedBox(height: 24),
          // Follower/Following skeleton
          Row(
            children: [
              Expanded(child: _buildShimmerBox(height: 60, shimmerBase: shimmerBase, shimmerHighlight: shimmerHighlight)),
              const SizedBox(width: 12),
              Expanded(child: _buildShimmerBox(height: 60, shimmerBase: shimmerBase, shimmerHighlight: shimmerHighlight)),
            ],
          ),
          const SizedBox(height: 24),
          // Recent section skeleton
          _buildShimmerBox(width: 80, height: 20, shimmerBase: shimmerBase, shimmerHighlight: shimmerHighlight),
          const SizedBox(height: 12),
          _buildShimmerBox(height: 100, shimmerBase: shimmerBase, shimmerHighlight: shimmerHighlight),
        ],
      ),
    );
  }

  Widget _buildShimmerBox({double? width, required double height, required Color shimmerBase, required Color shimmerHighlight}) {
    return _ShimmerWidget(
      width: width,
      height: height,
      shimmerBase: shimmerBase,
      shimmerHighlight: shimmerHighlight,
    );
  }

  Widget _buildStatCardSkeleton(Color shimmerBase, Color shimmerHighlight) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shimmerBase,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: shimmerHighlight,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const Spacer(),
          Container(
            width: 50,
            height: 24,
            decoration: BoxDecoration(
              color: shimmerHighlight,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 70,
            height: 14,
            decoration: BoxDecoration(
              color: shimmerHighlight,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 60, color: _themeService.textSecondaryColor),
          const SizedBox(height: 16),
          Text(
            _localeService.get('analytics_error'),
            style: TextStyle(color: _themeService.textSecondaryColor),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAnalytics,
            style: ElevatedButton.styleFrom(backgroundColor: ThemeService.accentColor),
            child: Text(_localeService.get('retry')),
          ),
        ],
      ),
    );
  }

  // ======================== OVERVIEW TAB ========================

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: ThemeService.accentColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewSection(),
            const SizedBox(height: 24),
            _buildRecentSection(),
            const SizedBox(height: 24),
            _buildTopVideosSection(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    final overview = _analytics!['overview'] as Map<String, dynamic>;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _localeService.get('overview'),
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Stats Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              icon: Icons.videocam_outlined,
              iconColor: Colors.purple,
              label: _localeService.get('total_videos'),
              value: _formatNumber(overview['totalVideos'] ?? 0),
            ),
            _buildStatCard(
              icon: Icons.visibility_outlined,
              iconColor: Colors.blue,
              label: _localeService.get('total_views'),
              value: _formatNumber(overview['totalViews'] ?? 0),
            ),
            _buildStatCard(
              icon: Icons.favorite_outline,
              iconColor: Colors.pink,
              label: _localeService.get('total_likes'),
              value: _formatNumber(overview['totalLikes'] ?? 0),
            ),
            _buildStatCard(
              icon: Icons.chat_bubble_outline,
              iconColor: Colors.orange,
              label: _localeService.get('total_comments'),
              value: _formatNumber(overview['totalComments'] ?? 0),
            ),
            _buildStatCard(
              icon: Icons.share_outlined,
              iconColor: Colors.green,
              label: _localeService.get('total_shares'),
              value: _formatNumber(overview['totalShares'] ?? 0),
            ),
            _buildStatCard(
              icon: Icons.trending_up,
              iconColor: ThemeService.accentColor,
              label: _localeService.get('engagement_rate'),
              value: '${overview['engagementRate'] ?? 0}%',
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Followers/Following Row
        Row(
          children: [
            Expanded(
              child: _buildFollowCard(
                icon: Icons.people_outline,
                label: _localeService.get('followers'),
                value: _formatNumber(overview['followersCount'] ?? 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFollowCard(
                icon: Icons.person_add_outlined,
                label: _localeService.get('following'),
                value: _formatNumber(overview['followingCount'] ?? 0),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.grey[50] : Colors.grey[900],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _themeService.isLightMode ? Colors.grey[200]! : Colors.grey[800]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFollowCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ThemeService.accentColor.withValues(alpha: 0.1),
            ThemeService.accentColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThemeService.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: ThemeService.accentColor, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSection() {
    final recent = _analytics!['recent'] as Map<String, dynamic>;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.blue[50] : Colors.blue[900]!.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _themeService.isLightMode ? Colors.blue[100]! : Colors.blue[800]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                _localeService.get('last_7_days'),
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _formatNumber(recent['videosLast7Days'] ?? 0),
                      style: TextStyle(
                        color: _themeService.textPrimaryColor,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _localeService.get('videos_posted'),
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: _themeService.dividerColor,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _formatNumber(recent['viewsLast7Days'] ?? 0),
                      style: TextStyle(
                        color: _themeService.textPrimaryColor,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _localeService.get('views'),
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopVideosSection() {
    final allVideos = (_analytics!['allVideos'] as List?) ?? (_analytics!['topVideos'] as List?) ?? [];
    
    if (allVideos.isEmpty) {
      return _buildEmptyVideosState();
    }
    
    // Sort videos based on selected criteria
    final sortedVideos = List<Map<String, dynamic>>.from(allVideos.map((v) => Map<String, dynamic>.from(v)));
    sortedVideos.sort((a, b) {
      switch (_sortBy) {
        case 'likes':
          return (b['likes'] ?? 0).compareTo(a['likes'] ?? 0);
        case 'date':
          final dateA = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(2000);
          final dateB = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        case 'views':
        default:
          return (b['views'] ?? 0).compareTo(a['views'] ?? 0);
      }
    });
    
    // Limit displayed videos
    final displayedVideos = _showAllVideos 
        ? sortedVideos 
        : sortedVideos.take(_initialVideoCount).toList();
    final hasMore = sortedVideos.length > _initialVideoCount;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with sort options
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _localeService.get('top_videos'),
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            _buildSortDropdown(),
          ],
        ),
        const SizedBox(height: 12),
        
        // Video list
        ...displayedVideos.asMap().entries.map((entry) {
          final index = entry.key;
          final video = entry.value;
          return _buildVideoItem(video, index + 1);
        }),
        
        // Show more/less button
        if (hasMore)
          _buildShowMoreButton(sortedVideos.length),
      ],
    );
  }
  
  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[800],
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortBy,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, color: _themeService.textSecondaryColor, size: 20),
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontSize: 13,
          ),
          dropdownColor: _themeService.isLightMode ? Colors.white : Colors.grey[850],
          items: [
            DropdownMenuItem(
              value: 'views',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility, size: 16, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(_localeService.get('sort_by_views')),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'likes',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite, size: 16, color: Colors.pink),
                  const SizedBox(width: 6),
                  Text(_localeService.get('sort_by_likes')),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'date',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Text(_localeService.get('sort_by_date')),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _sortBy = value);
            }
          },
        ),
      ),
    );
  }
  
  Widget _buildShowMoreButton(int totalCount) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: TextButton.icon(
          onPressed: () => setState(() => _showAllVideos = !_showAllVideos),
          icon: Icon(
            _showAllVideos ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: ThemeService.accentColor,
          ),
          label: Text(
            _showAllVideos 
                ? _localeService.get('show_less')
                : '${_localeService.get('show_more')} (${totalCount - _initialVideoCount} ${_localeService.get('more_videos')})',
            style: TextStyle(color: ThemeService.accentColor),
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyVideosState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.grey[50] : Colors.grey[900],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _themeService.isLightMode ? Colors.grey[200]! : Colors.grey[800]!,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.videocam_off_outlined, size: 48, color: _themeService.textSecondaryColor),
          const SizedBox(height: 12),
          Text(
            _localeService.get('no_videos_yet'),
            style: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _localeService.get('upload_first_video'),
            style: TextStyle(
              color: _themeService.textSecondaryColor.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoItem(Map<String, dynamic> video, int rank) {
    final thumbnailUrl = video['thumbnailUrl']?.toString();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.grey[50] : Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _themeService.isLightMode ? Colors.grey[200]! : Colors.grey[800]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rank <= 3 
                  ? [Colors.amber, Colors.grey[400], Colors.orange[300]][rank - 1]
                  : _themeService.dividerColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: rank <= 3 ? Colors.white : _themeService.textSecondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                ? Image.network(
                    thumbnailUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderThumbnail(),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildPlaceholderThumbnail();
                    },
                  )
                : _buildPlaceholderThumbnail(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video['title'] ?? 'Untitled',
                  style: TextStyle(
                    color: _themeService.textPrimaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.visibility, size: 14, color: _themeService.textSecondaryColor),
                    const SizedBox(width: 4),
                    Text(
                      _formatNumber(video['views'] ?? 0),
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.favorite, size: 14, color: Colors.pink.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      _formatNumber(video['likes'] ?? 0),
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Date badge
          if (video['createdAt'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _themeService.isLightMode 
                    ? Colors.grey[200] 
                    : Colors.grey[800],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatDate(video['createdAt']),
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildPlaceholderThumbnail() {
    return Container(
      width: 50,
      height: 50,
      color: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[700],
      child: Icon(Icons.video_library, color: _themeService.textSecondaryColor, size: 24),
    );
  }

  // ======================== CHARTS TAB ========================

  Widget _buildChartsTab() {
    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: ThemeService.accentColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEngagementPieChart(),
            const SizedBox(height: 24),
            _buildDailyBarChart(),
            const SizedBox(height: 24),
            _buildTrendLineChart(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementPieChart() {
    final distribution = _analytics!['distribution'] as Map<String, dynamic>?;
    final likes = (distribution?['likes'] ?? _analytics!['overview']['totalLikes'] ?? 0) as int;
    final comments = (distribution?['comments'] ?? _analytics!['overview']['totalComments'] ?? 0) as int;
    final shares = (distribution?['shares'] ?? _analytics!['overview']['totalShares'] ?? 0) as int;
    
    final total = likes + comments + shares;
    
    if (total == 0) {
      return _buildEmptyChartState(_localeService.get('engagement_distribution'));
    }
    
    final sections = [
      _ChartSection('likes', _localeService.get('likes'), likes, Colors.pink),
      _ChartSection('comments', _localeService.get('comments'), comments, Colors.orange),
      _ChartSection('shares', _localeService.get('shares'), shares, Colors.green),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.white : Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _themeService.isLightMode ? Colors.grey[200]! : Colors.grey[800]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ThemeService.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.pie_chart, color: ThemeService.accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                _localeService.get('engagement_distribution'),
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedPieIndex = -1;
                              return;
                            }
                            _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 3,
                      centerSpaceRadius: 40,
                      sections: sections.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final section = entry.value;
                        final isTouched = idx == _touchedPieIndex;
                        final percentage = total > 0 ? (section.value / total * 100) : 0.0;
                        
                        return PieChartSectionData(
                          color: section.color,
                          value: section.value.toDouble(),
                          title: isTouched ? '${percentage.toStringAsFixed(1)}%' : '',
                          radius: isTouched ? 60 : 50,
                          titleStyle: TextStyle(
                            fontSize: isTouched ? 14 : 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          badgeWidget: isTouched ? _buildBadge(section) : null,
                          badgePositionPercentageOffset: 1.3,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sections.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final section = entry.value;
                      final isTouched = idx == _touchedPieIndex;
                      final percentage = total > 0 ? (section.value / total * 100) : 0.0;
                      
                      return GestureDetector(
                        onTap: () => setState(() => _touchedPieIndex = isTouched ? -1 : idx),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isTouched 
                                ? section.color.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: section.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      section.label,
                                      style: TextStyle(
                                        color: _themeService.textPrimaryColor,
                                        fontSize: 12,
                                        fontWeight: isTouched ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                    Text(
                                      '${_formatNumber(section.value)} (${percentage.toStringAsFixed(1)}%)',
                                      style: TextStyle(
                                        color: _themeService.textSecondaryColor,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // Touched section detail - always reserve space to prevent layout shift
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 60,
            margin: const EdgeInsets.only(top: 12),
            padding: _touchedPieIndex >= 0 && _touchedPieIndex < sections.length 
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: _touchedPieIndex >= 0 && _touchedPieIndex < sections.length
                  ? sections[_touchedPieIndex].color.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: _touchedPieIndex >= 0 && _touchedPieIndex < sections.length
                  ? Border.all(
                      color: sections[_touchedPieIndex].color.withValues(alpha: 0.3),
                    )
                  : null,
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _touchedPieIndex >= 0 && _touchedPieIndex < sections.length ? 1.0 : 0.0,
              child: _touchedPieIndex >= 0 && _touchedPieIndex < sections.length
                  ? Row(
                      children: [
                        Icon(
                          _getIconForType(sections[_touchedPieIndex].type),
                          color: sections[_touchedPieIndex].color,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                sections[_touchedPieIndex].label,
                                style: TextStyle(
                                  color: _themeService.textPrimaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${_formatNumber(sections[_touchedPieIndex].value)} ${_localeService.get('total').toLowerCase()}',
                                style: TextStyle(
                                  color: _themeService.textSecondaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${(sections[_touchedPieIndex].value / total * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: sections[_touchedPieIndex].color,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(_ChartSection section) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: section.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: section.color.withValues(alpha: 0.5),
            blurRadius: 8,
          ),
        ],
      ),
      child: Icon(
        _getIconForType(section.type),
        color: Colors.white,
        size: 14,
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'likes':
        return Icons.favorite;
      case 'comments':
        return Icons.chat_bubble;
      case 'shares':
        return Icons.share;
      default:
        return Icons.circle;
    }
  }

  Widget _buildDailyBarChart() {
    final dailyStats = (_analytics!['dailyStats'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    if (dailyStats.isEmpty) {
      return _buildEmptyChartState(_localeService.get('daily_engagement'));
    }

    // Find max value for scaling
    int maxValue = 0;
    for (final stat in dailyStats) {
      final views = (stat['views'] ?? 0) as int;
      final likes = (stat['likes'] ?? 0) as int;
      final comments = (stat['comments'] ?? 0) as int;
      final total = views + likes + comments;
      if (total > maxValue) maxValue = total;
    }
    if (maxValue == 0) maxValue = 10;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.white : Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _themeService.isLightMode ? Colors.grey[200]! : Colors.grey[800]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.bar_chart, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _localeService.get('daily_engagement'),
                  style: TextStyle(
                    color: _themeService.textPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.blue, _localeService.get('views')),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.pink, _localeService.get('likes')),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.orange, _localeService.get('comments')),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue.toDouble() * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => _themeService.isLightMode 
                        ? Colors.grey[800]! 
                        : Colors.grey[200]!,
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final stat = dailyStats[group.x.toInt()];
                      final date = stat['date'] as String;
                      final values = ['views', 'likes', 'comments'];
                      final colors = [Colors.blue, Colors.pink, Colors.orange];
                      
                      return BarTooltipItem(
                        '${_formatShortDate(date)}\n',
                        TextStyle(
                          color: _themeService.isLightMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: '${values[rodIndex]}: ${stat[values[rodIndex]]}',
                            style: TextStyle(
                              color: colors[rodIndex],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          barTouchResponse == null ||
                          barTouchResponse.spot == null) {
                        _touchedBarIndex = -1;
                        return;
                      }
                      _touchedBarIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                    });
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= dailyStats.length) return const SizedBox();
                        final date = dailyStats[value.toInt()]['date'] as String;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _formatDayOnly(date),
                            style: TextStyle(
                              color: _themeService.textSecondaryColor,
                              fontSize: 10,
                              fontWeight: value.toInt() == _touchedBarIndex 
                                  ? FontWeight.bold 
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatNumber(value.toInt()),
                          style: TextStyle(
                            color: _themeService.textSecondaryColor,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxValue / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: _themeService.dividerColor,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                barGroups: dailyStats.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final stat = entry.value;
                  final isTouched = idx == _touchedBarIndex;
                  
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: (stat['views'] ?? 0).toDouble(),
                        color: isTouched ? Colors.blue : Colors.blue.withValues(alpha: 0.7),
                        width: 8,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: (stat['likes'] ?? 0).toDouble(),
                        color: isTouched ? Colors.pink : Colors.pink.withValues(alpha: 0.7),
                        width: 8,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: (stat['comments'] ?? 0).toDouble(),
                        color: isTouched ? Colors.orange : Colors.orange.withValues(alpha: 0.7),
                        width: 8,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          // Selected day detail - always reserve space to prevent layout shift
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 88,
            margin: const EdgeInsets.only(top: 16),
            padding: _touchedBarIndex >= 0 && _touchedBarIndex < dailyStats.length 
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: _touchedBarIndex >= 0 && _touchedBarIndex < dailyStats.length
                  ? Colors.blue.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _touchedBarIndex >= 0 && _touchedBarIndex < dailyStats.length ? 1.0 : 0.0,
              child: _touchedBarIndex >= 0 && _touchedBarIndex < dailyStats.length
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDayStatItem(
                          Icons.visibility,
                          Colors.blue,
                          dailyStats[_touchedBarIndex]['views'] ?? 0,
                          _localeService.get('views'),
                        ),
                        _buildDayStatItem(
                          Icons.favorite,
                          Colors.pink,
                          dailyStats[_touchedBarIndex]['likes'] ?? 0,
                          _localeService.get('likes'),
                        ),
                        _buildDayStatItem(
                          Icons.chat_bubble,
                          Colors.orange,
                          dailyStats[_touchedBarIndex]['comments'] ?? 0,
                          _localeService.get('comments'),
                        ),
                      ],
                    )
                  : const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: _themeService.textSecondaryColor,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDayStatItem(IconData icon, Color color, int value, String label) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          _formatNumber(value),
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: _themeService.textSecondaryColor,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendLineChart() {
    final dailyStats = (_analytics!['dailyStats'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    if (dailyStats.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get max views for scaling
    int maxViews = 0;
    for (final stat in dailyStats) {
      final views = (stat['views'] ?? 0) as int;
      if (views > maxViews) maxViews = views;
    }
    if (maxViews == 0) maxViews = 10;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.white : Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _themeService.isLightMode ? Colors.grey[200]! : Colors.grey[800]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.show_chart, color: Colors.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                _localeService.get('views_trend'),
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => _themeService.isLightMode 
                        ? Colors.grey[800]! 
                        : Colors.grey[200]!,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final stat = dailyStats[spot.x.toInt()];
                        return LineTooltipItem(
                          '${_formatShortDate(stat['date'])}\n',
                          TextStyle(
                            color: _themeService.isLightMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(
                              text: '${spot.y.toInt()} ${_localeService.get('views').toLowerCase()}',
                              style: TextStyle(
                                color: Colors.purple[200],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxViews / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: _themeService.dividerColor,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= dailyStats.length) return const SizedBox();
                        final date = dailyStats[value.toInt()]['date'] as String;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _formatDayOnly(date),
                            style: TextStyle(
                              color: _themeService.textSecondaryColor,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatNumber(value.toInt()),
                          style: TextStyle(
                            color: _themeService.textSecondaryColor,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (dailyStats.length - 1).toDouble(),
                minY: 0,
                maxY: maxViews.toDouble() * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: dailyStats.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        (entry.value['views'] ?? 0).toDouble(),
                      );
                    }).toList(),
                    isCurved: true,
                    color: Colors.purple,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.purple,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.withValues(alpha: 0.3),
                          Colors.purple.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChartState(String title) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.white : Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _themeService.isLightMode ? Colors.grey[200]! : Colors.grey[800]!,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: _themeService.textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Icon(Icons.insert_chart_outlined, size: 48, color: _themeService.textSecondaryColor),
          const SizedBox(height: 12),
          Text(
            _localeService.get('no_data_chart'),
            style: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ======================== UTILITIES ========================
  
  String _formatDate(dynamic dateStr) {
    try {
      final date = DateTime.parse(dateStr.toString());
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays == 0) {
        return _localeService.get('today');
      } else if (diff.inDays == 1) {
        return _localeService.get('yesterday');
      } else if (diff.inDays < 7) {
        return '${diff.inDays}${_localeService.get('days_ago_short')}';
      } else if (diff.inDays < 30) {
        return '${(diff.inDays / 7).floor()}${_localeService.get('weeks_ago_short')}';
      } else {
        return '${date.day}/${date.month}';
      }
    } catch (e) {
      return '';
    }
  }

  String _formatNumber(dynamic number) {
    final num value = number is num ? number : int.tryParse(number.toString()) ?? 0;
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  String _formatShortDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDayOnly(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final weekdays = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
      return weekdays[date.weekday % 7];
    } catch (e) {
      return '';
    }
  }
}

class _ChartSection {
  final String type;
  final String label;
  final int value;
  final Color color;

  _ChartSection(this.type, this.label, this.value, this.color);
}

/// Shimmer widget with smooth looping animation
class _ShimmerWidget extends StatefulWidget {
  final double? width;
  final double height;
  final Color shimmerBase;
  final Color shimmerHighlight;

  const _ShimmerWidget({
    this.width,
    required this.height,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  @override
  State<_ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<_ShimmerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [
                widget.shimmerBase,
                widget.shimmerHighlight,
                widget.shimmerBase,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
