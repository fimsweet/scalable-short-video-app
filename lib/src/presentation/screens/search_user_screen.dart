import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'chat_screen.dart';

class SearchUserScreen extends StatefulWidget {
  const SearchUserScreen({super.key});

  @override
  State<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends State<SearchUserScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ApiService _apiService = ApiService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _suggestedUsers = [];
  bool _isLoading = false;
  bool _isLoadingSuggestions = true;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _loadSuggestedUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
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

  Future<void> _loadSuggestedUsers() async {
    setState(() => _isLoadingSuggestions = true);
    
    try {
      final currentUserId = _authService.user?['id'];
      if (currentUserId == null) {
        setState(() => _isLoadingSuggestions = false);
        return;
      }

      // Get following list as suggested users
      final following = await _apiService.getFollowing(currentUserId.toString());
      
      if (mounted) {
        setState(() {
          _suggestedUsers = following;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      print('Error loading suggested users: $e');
      if (mounted) {
        setState(() => _isLoadingSuggestions = false);
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await _apiService.searchUsers(query);
      if (mounted) {
        // Filter out current user
        final currentUserId = _authService.user?['id']?.toString();
        final filteredResults = results
            .where((user) => user['id'].toString() != currentUserId)
            .toList();
        
        setState(() {
          _searchResults = filteredResults.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error searching users: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToChat(Map<String, dynamic> user) {
    // Get full avatar URL if avatar exists
    final avatarUrl = user['avatar'] != null 
        ? _apiService.getAvatarUrl(user['avatar']) 
        : null;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          recipientId: user['id'].toString(),
          recipientUsername: user['username'] ?? 'User',
          recipientAvatar: avatarUrl,
        ),
      ),
    );
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
          _localeService.get('new_message'),
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                style: TextStyle(color: _themeService.textPrimaryColor),
                decoration: InputDecoration(
                  hintText: _localeService.get('search_username'),
                  hintStyle: TextStyle(
                    color: _themeService.textSecondaryColor,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: _themeService.textSecondaryColor,
                    size: 22,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: _themeService.textSecondaryColor,
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _searchUsers('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {});
                  // Debounce search
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (_searchController.text == value) {
                      _searchUsers(value);
                    }
                  });
                },
              ),
            ),
          ),

          // Results or Suggestions
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: _themeService.textPrimaryColor,
                    ),
                  )
                : _hasSearched
                    ? _searchResults.isEmpty
                        ? _buildNoResultsState()
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              return _buildUserTile(user);
                            },
                          )
                    : _buildSuggestionsSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsSection() {
    if (_isLoadingSuggestions) {
      return Center(
        child: CircularProgressIndicator(
          color: _themeService.textPrimaryColor,
        ),
      );
    }

    if (_suggestedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _themeService.isLightMode 
                    ? Colors.grey[100] 
                    : Colors.grey[850],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 48,
                color: _themeService.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _localeService.get('no_suggestions'),
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _localeService.get('follow_to_see_suggestions'),
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            _localeService.get('suggested'),
            style: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _suggestedUsers.length,
            itemBuilder: (context, index) {
              final user = _suggestedUsers[index];
              return _buildUserTile(user);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoResultsState() {
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
            _localeService.get('no_users_found'),
            style: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    return ListTile(
      onTap: () => _navigateToChat(user),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: _themeService.isLightMode ? Colors.grey[200] : Colors.grey[800],
        backgroundImage: user['avatar'] != null && _apiService.getAvatarUrl(user['avatar']).isNotEmpty
            ? NetworkImage(_apiService.getAvatarUrl(user['avatar']))
            : null,
        child: user['avatar'] == null || _apiService.getAvatarUrl(user['avatar']).isEmpty
            ? Icon(Icons.person, color: _themeService.textSecondaryColor)
            : null,
      ),
      title: Text(
        user['username'] ?? 'User',
        style: TextStyle(
          color: _themeService.textPrimaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chat_bubble_outline,
        color: _themeService.textSecondaryColor,
        size: 20,
      ),
    );
  }
}
