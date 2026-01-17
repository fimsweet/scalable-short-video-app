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
  
  // Track follow status
  Map<String, bool> _followStatus = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSearchHistory();
    _loadSuggestions();
    
    // Auto focus on search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
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
      print('❌ Search error: $e');
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
              Icons.arrow_back_ios,
              color: _themeService.iconColor,
              size: 22,
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
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
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Search history
        if (_searchHistory.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._searchHistory.take(5).map((query) => _buildHistoryItem(query)),
          if (_searchHistory.length > 5)
            Center(
              child: TextButton(
                onPressed: () {},
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _localeService.get('see_more'),
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: _themeService.textSecondaryColor,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
        
        // Suggestions section - "Bạn có thể thích"
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

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        title.toString().isEmpty ? 'Video' : title,
        style: TextStyle(
          color: Colors.red,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: thumbnailUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                thumbnailUrl,
                width: 50,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 50,
                  height: 70,
                  color: Colors.grey[800],
                ),
              ),
            )
          : null,
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
    );
  }

  Widget _buildSearchResults() {
    return Column(
      children: [
        // Tabs
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _themeService.dividerColor,
                width: 0.5,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: _themeService.textPrimaryColor,
            unselectedLabelColor: _themeService.textSecondaryColor,
            indicatorColor: _themeService.textPrimaryColor,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: _localeService.get('videos_tab')),
              Tab(text: _localeService.get('users_tab')),
            ],
          ),
        ),
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
                  children: [
                    _buildVideoResults(),
                    _buildUserResults(),
                  ],
                ),
        ),
      ],
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

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 9 / 16,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _videoResults.length,
      itemBuilder: (context, index) {
        final video = _videoResults[index];
        final thumbnailUrl = video['thumbnailUrl'] != null
            ? _videoService.getVideoUrl(video['thumbnailUrl'])
            : null;
        final viewCount = video['viewCount'] ?? 0;

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
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumbnailUrl != null)
                  Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.video_library, color: Colors.white54),
                    ),
                  )
                else
                  Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.video_library, color: Colors.white54),
                  ),
                // View count
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Row(
                    children: [
                      const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        _formatCount(viewCount is int ? viewCount : 0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            backgroundImage: user['avatar'] != null
                ? NetworkImage(_apiService.getAvatarUrl(user['avatar']))
                : null,
            child: user['avatar'] == null
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
