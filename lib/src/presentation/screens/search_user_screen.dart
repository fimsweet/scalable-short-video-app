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
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    // Auto focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
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
      print('❌ Error searching users: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToChat(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          recipientId: user['id'].toString(),
          recipientUsername: user['username'] ?? 'User',
          recipientAvatar: user['avatar'],
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
          icon: Icon(Icons.arrow_back_ios_new, color: _themeService.iconColor, size: 20),
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

          // Results
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: _themeService.textPrimaryColor,
                    ),
                  )
                : _searchResults.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          return _buildUserTile(user);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: _themeService.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              _localeService.get('search_users_to_chat'),
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 80,
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
        backgroundImage: user['avatar'] != null
            ? NetworkImage(_apiService.getAvatarUrl(user['avatar']))
            : null,
        child: user['avatar'] == null
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
      subtitle: user['bio'] != null && user['bio'].toString().isNotEmpty
          ? Text(
              user['bio'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 13,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chat_bubble_outline,
        color: _themeService.textSecondaryColor,
        size: 20,
      ),
    );
  }
}
