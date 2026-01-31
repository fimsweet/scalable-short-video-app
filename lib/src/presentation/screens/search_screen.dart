import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final VideoService _videoService = VideoService();
  final ApiService _apiService = ApiService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final FollowService _followService = FollowService();
  final AuthService _authService = AuthService();
  
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  late TabController _tabController;
  
  List<dynamic> _videoResults = [];
  List<Map<String, dynamic>> _userResults = [];
  List<String> _searchHistory = [];
  List<dynamic> _suggestedVideos = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _isHistoryExpanded = false;
  
  // Track follow status
  Map<String, bool> _followStatus = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadSearchHistory();
    _loadSuggestions();
    
    // Auto focus on search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('search_history') ?? [];
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _loadSuggestions() async {
    // Load some trending/suggested videos
    final videos = await _videoService.getAllVideos();
    if (mounted) {
      setState(() {
        _suggestedVideos = videos.take(6).toList();
      });
    }
  }

  Future<void> _saveSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    _searchHistory.remove(query);
    _searchHistory.insert(0, query);
    if (_searchHistory.length > 10) {
      _searchHistory = _searchHistory.sublist(0, 10);
    }
    await prefs.setStringList('search_history', _searchHistory);
    setState(() {});
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    setState(() {
      _searchHistory = [];
    });
  }

  void _removeFromHistory(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory.removeAt(index);
    });
    await prefs.setStringList('search_history', _searchHistory);
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    _saveSearchHistory(query);
    
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      // Search in parallel
      final results = await Future.wait([
        _videoService.searchVideos(query),
        _apiService.searchUsers(query),
      ]);

      final videos = results[0] as List<dynamic>;
      final users = results[1] as List<Map<String, dynamic>>;
      
      // Check follow status for users
      if (_authService.isLoggedIn && _authService.user != null) {
        final currentUserId = _authService.user!['id'] as int;
        for (var user in users) {
          final userId = user['id'];
          if (userId != null && userId != currentUserId) {
            final isFollowing = await _followService.isFollowing(currentUserId, userId);
            _followStatus[userId.toString()] = isFollowing;
          }
        }
      }

      if (mounted) {
        setState(() {
          _videoResults = videos;
          _userResults = users;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Search error: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar header - TikTok style
            _buildSearchHeader(),
            
            // Content
            Expanded(
              child: _hasSearched
                  ? _buildSearchResults()
                  : _buildSearchSuggestions(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.chevron_left,
              color: _themeService.iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
          // Search field
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: _themeService.isLightMode 
                    ? Colors.grey[200] 
                    : Colors.grey[900],
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: _searchController.text.isEmpty 
                      ? _localeService.get('search_hint')
                      : null,
                  hintStyle: TextStyle(
                    color: _themeService.textSecondaryColor,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: _themeService.textSecondaryColor,
                    size: 18,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() {
                                  _hasSearched = false;
                                  _videoResults = [];
                                  _userResults = [];
                                });
                              },
                              child: Icon(
                                Icons.clear,
                                color: _themeService.textSecondaryColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        )
                      : null,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) {
                  setState(() {});
                },
                onSubmitted: _performSearch,
                textInputAction: TextInputAction.search,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Search button
          GestureDetector(
            onTap: () => _performSearch(_searchController.text),
            child: Text(
              _localeService.get('search'),
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    // Calculate how many history items to show
    final int maxHistoryItems = 10; // Maximum limit like Instagram/TikTok
    final int visibleHistoryCount = _isHistoryExpanded 
        ? (_searchHistory.length > maxHistoryItems ? maxHistoryItems : _searchHistory.length)
        : (_searchHistory.length > 3 ? 3 : _searchHistory.length);
    final bool canExpand = _searchHistory.length > 3;
    final bool canCollapse = _isHistoryExpanded;
    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Search history
        if (_searchHistory.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._searchHistory.take(visibleHistoryCount).map((query) => _buildHistoryItem(query)),
          if (canExpand || canCollapse)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isHistoryExpanded = !_isHistoryExpanded;
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isHistoryExpanded 
                          ? _localeService.get('see_less')
                          : _localeService.get('see_more'),
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isHistoryExpanded 
                          ? Icons.keyboard_arrow_up 
                          : Icons.keyboard_arrow_down,
                      color: _themeService.textSecondaryColor,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
        
        // Suggestions section - "Bạn có thể thích" TikTok style
        if (_suggestedVideos.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _localeService.get('suggested_for_you'),
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: _loadSuggestions,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(
                      Icons.refresh,
                      color: _themeService.textSecondaryColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _localeService.get('refresh'),
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._suggestedVideos.map((video) => _buildSuggestionItem(video)),
        ],
      ],
    );
  }

  Widget _buildHistoryItem(String query) {
    final index = _searchHistory.indexOf(query);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.history,
        color: _themeService.textSecondaryColor,
        size: 20,
      ),
      title: Text(
        query,
        style: TextStyle(
          color: _themeService.textPrimaryColor,
          fontSize: 14,
        ),
      ),
      trailing: GestureDetector(
        onTap: () => _removeFromHistory(index),
        child: Icon(
          Icons.close,
          color: _themeService.textSecondaryColor,
          size: 18,
        ),
      ),
      onTap: () {
        _searchController.text = query;
        _performSearch(query);
      },
    );
  }

  Widget _buildSuggestionItem(dynamic video) {
    final title = video['title'] ?? video['description'] ?? '';
    final thumbnailUrl = video['thumbnailUrl'] != null
        ? _videoService.getVideoUrl(video['thumbnailUrl'])
        : null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoDetailScreen(
              videos: [video],
              initialIndex: 0,
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Red dot indicator
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: ThemeService.accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Title
            Expanded(
              child: Text(
                title.toString().isEmpty ? 'Video' : title,
                style: TextStyle(
                  color: ThemeService.accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            // Search icon or Thumbnail (TikTok style: square thumbnail)
            thumbnailUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      thumbnailUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 44,
                        height: 44,
                        color: _themeService.isLightMode ? Colors.grey[200] : Colors.grey[800],
                        child: Icon(
                          Icons.play_arrow,
                          color: _themeService.textSecondaryColor,
                          size: 20,
                        ),
                      ),
                    ),
                  )
                : Icon(
                    Icons.search,
                    color: _themeService.textSecondaryColor,
                    size: 20,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Column(
      children: [
        // TikTok-style custom tabs
        _buildCustomTabBar(),
        // Results
        Expanded(
          child: _isSearching
              ? Center(
                  child: CircularProgressIndicator(
                    color: _themeService.textPrimaryColor,
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildVideoResults(),
                    _buildUserResults(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCustomTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _themeService.dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCustomTab(_localeService.get('videos_tab'), 0),
          ),
          Expanded(
            child: _buildCustomTab(_localeService.get('users_tab'), 1),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTab(String title, int index) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _tabController.animateTo(index);
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected 
                    ? _themeService.textPrimaryColor 
                    : _themeService.textSecondaryColor,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 32 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: _themeService.textPrimaryColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoResults() {
    if (_videoResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: _themeService.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              _localeService.get('no_results'),
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // TikTok-style 2-column grid
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.55, // Taller to fit info below thumbnail
        crossAxisSpacing: 8,
        mainAxisSpacing: 16,
      ),
      itemCount: _videoResults.length,
      itemBuilder: (context, index) {
        final video = _videoResults[index];
        return _buildVideoGridItem(video);
      },
    );
  }

  Widget _buildVideoGridItem(dynamic video) {
    final thumbnailUrl = video['thumbnailUrl'] != null
        ? _videoService.getVideoUrl(video['thumbnailUrl'])
        : null;
    final title = video['title'] ?? video['description'] ?? '';
    final likeCount = video['likeCount'] ?? 0;
    final user = video['user'];
    final username = user?['username'] ?? 'user';
    final avatar = user?['avatar'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoDetailScreen(
              videos: [video],
              initialIndex: 0,
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: double.infinity,
                color: _themeService.isLightMode ? Colors.grey[200] : Colors.grey[900],
                child: thumbnailUrl != null
                    ? Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: _themeService.isLightMode ? Colors.grey[200] : Colors.grey[800],
                          child: Icon(
                            Icons.video_library,
                            color: _themeService.textSecondaryColor,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.video_library,
                        color: _themeService.textSecondaryColor,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            title.toString().isEmpty ? 'Video' : title,
            style: TextStyle(
              color: _themeService.textPrimaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // User info and likes
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 10,
                backgroundColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[700],
                backgroundImage: avatar != null && _apiService.getAvatarUrl(avatar).isNotEmpty
                    ? NetworkImage(_apiService.getAvatarUrl(avatar))
                    : null,
                child: avatar == null || _apiService.getAvatarUrl(avatar).isEmpty
                    ? Icon(
                        Icons.person,
                        size: 12,
                        color: _themeService.textSecondaryColor,
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              // Username
              Expanded(
                child: Text(
                  username,
                  style: TextStyle(
                    color: _themeService.textSecondaryColor,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Like count
              Icon(
                Icons.favorite_outline,
                size: 14,
                color: _themeService.textSecondaryColor,
              ),
              const SizedBox(width: 2),
              Text(
                _formatCount(likeCount is int ? likeCount : 0),
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

  Widget _buildUserResults() {
    if (_userResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 64,
              color: _themeService.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              _localeService.get('no_results'),
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _userResults.length,
      itemBuilder: (context, index) {
        final user = _userResults[index];
        final userId = user['id'];
        final isFollowing = _followStatus[userId.toString()] ?? false;
        final currentUserId = _authService.user?['id'];
        final isOwnProfile = currentUserId != null && currentUserId == userId;

        return ListTile(
          onTap: () {
            if (userId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(userId: userId),
                ),
              );
            }
          },
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[800],
            backgroundImage: user['avatar'] != null && _apiService.getAvatarUrl(user['avatar']).isNotEmpty
                ? NetworkImage(_apiService.getAvatarUrl(user['avatar']))
                : null,
            child: user['avatar'] == null || _apiService.getAvatarUrl(user['avatar']).isEmpty
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          title: Text(
            user['username'] ?? 'user',
            style: TextStyle(
              color: _themeService.textPrimaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: user['fullName'] != null && user['fullName'].toString().isNotEmpty
              ? Text(
                  user['fullName'],
                  style: TextStyle(
                    color: _themeService.textSecondaryColor,
                  ),
                )
              : null,
          trailing: !isOwnProfile && _authService.isLoggedIn
              ? TextButton(
                  onPressed: () => _toggleFollow(userId),
                  style: TextButton.styleFrom(
                    backgroundColor: isFollowing
                        ? Colors.transparent
                        : const Color(0xFFFF2D55),
                    side: isFollowing
                        ? BorderSide(color: Colors.grey[400]!)
                        : null,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(
                    isFollowing
                        ? _localeService.get('following_status')
                        : _localeService.get('follow'),
                    style: TextStyle(
                      color: isFollowing ? _themeService.textPrimaryColor : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Future<void> _toggleFollow(int userId) async {
    if (!_authService.isLoggedIn || _authService.user == null) return;
    
    final currentUserId = _authService.user!['id'] as int;
    final result = await _followService.toggleFollow(currentUserId, userId);
    
    if (mounted) {
      setState(() {
        _followStatus[userId.toString()] = result['following'] ?? false;
      });
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
