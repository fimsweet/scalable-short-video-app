import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/comment_section_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_controls_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/hls_video_player.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/like_service.dart';
import 'package:scalable_short_video_app/src/services/comment_service.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';
import 'package:scalable_short_video_app/src/services/saved_video_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/video_playback_service.dart';
import 'package:scalable_short_video_app/src/services/analytics_tracking_service.dart';
import 'package:scalable_short_video_app/src/services/video_prefetch_service.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/feed_tab_bar.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/main_screen.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/share_video_sheet.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/login_required_dialog.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_privacy_sheet.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_more_options_sheet.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/app_snackbar.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_options_sheet.dart';
import 'package:scalable_short_video_app/src/presentation/screens/search_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/edit_video_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/login_screen.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => VideoScreenState();
}

// Export state class so it can be accessed from MainScreen
class VideoScreenState extends State<VideoScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final VideoService _videoService = VideoService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final LikeService _likeService = LikeService();
  final CommentService _commentService = CommentService();
  final FollowService _followService = FollowService();
  final SavedVideoService _savedVideoService = SavedVideoService();
  final LocaleService _localeService = LocaleService();
  final VideoPlaybackService _videoPlaybackService = VideoPlaybackService();
  final AnalyticsTrackingService _analyticsService = AnalyticsTrackingService();
  final VideoPrefetchService _prefetchService = VideoPrefetchService();
  
  List<dynamic> _videos = [];
  
  // Store reference to current video player state
  HLSVideoPlayerState? _currentVideoPlayerState;
  
  // Track expanded state for each video caption
  Map<int, bool> _expandedCaptions = {};
  
  // Cache user info for each video owner
  Map<String, Map<String, dynamic>> _userCache = {};
  
  // Track like status for each video
  Map<String, bool> _likeStatus = {};
  Map<String, int> _likeCounts = {};
  Map<String, int> _commentCounts = {};
  Map<String, int> _saveCounts = {};
  Map<String, int> _shareCounts = {}; // ADD THIS
  Map<String, int> _viewCounts = {}; // Track view counts
  
  // Track video privacy settings
  Map<String, String> _videoVisibility = {};
  Map<String, bool> _videoAllowComments = {};
  Map<String, bool> _videoAllowDuet = {};
  
  // Track owner-level comment disabled (whoCanComment = noOne)
  Map<String, bool> _ownerCommentDisabled = {};
  
  // Track follow status for each user
  Map<String, bool> _followStatus = {};
  // Track requested (pending) status for follow approval
  Map<String, bool> _requestedStatus = {};
  
  // Track save status for each video
  Map<String, bool> _saveStatus = {};
  
  // Separate PageControllers for each tab to preserve scroll state
  PageController? _forYouPageController;
  PageController? _friendsPageController;
  PageController? _followingPageController;
  
  // PageController for horizontal tab switching (like TikTok swipe between tabs)
  PageController? _horizontalTabController;
  
  // Current page for active tab
  int _currentPage = 0;

  // Watch time tracking for recommendation algorithm
  DateTime? _videoStartTime;
  String? _currentWatchingVideoId;
  int? _currentVideoDuration; // in seconds

  int _selectedFeedTab = 2; // 0 = Following, 1 = Friends, 2 = For You (default)
  
  // Separate video lists for each tab
  List<dynamic> _forYouVideos = [];
  List<dynamic> _followingVideos = [];
  
  // Loading state per tab (to show loading spinner vs empty state)
  bool _isLoadingForYou = true;
  bool _isLoadingFollowing = true;
  bool _isLoadingFriends = true;
  List<dynamic> _friendsVideos = [];
  
  // New content indicators for tabs (red dot)
  bool _hasNewFollowing = false;
  bool _hasNewFriends = false;
  DateTime? _lastFollowingVisit;
  DateTime? _lastFriendsVisit;
  
  // Separate page positions for each tab to preserve state
  int _forYouCurrentPage = 0;
  int _followingCurrentPage = 0;
  int _friendsCurrentPage = 0;

  // Playback speed & auto-scroll settings (persisted across modal opens)
  double _playbackSpeed = 1.0;
  bool _autoScroll = false;
  bool _autoScrollTriggered = false; // Prevent duplicate triggers
  bool _isHideToggling = false; // Prevent rapid hide/unhide race condition

  /// Public: whether the current feed tab is "For You" (đề xuất)
  bool get isOnForYouTab => _selectedFeedTab == 2;

  /// Public: refresh the For You feed with new recommended videos
  Future<void> refreshForYouFeed() async {
    // Switch to For You tab if not already there
    if (_selectedFeedTab != 2) {
      _onTabChanged(2);
      // Wait for tab animation
      await Future.delayed(const Duration(milliseconds: 350));
    }

    // Flush current watch time so backend knows we watched this video
    _sendWatchTime();

    // Collect IDs of all currently displayed For You videos to exclude them
    final currentVideoIds = _forYouVideos
        .where((v) => v != null)
        .map<String>((v) => v['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    // Pause current video
    _pauseCurrentVideo();

    // Reset page to 0
    _forYouCurrentPage = 0;
    _currentPage = 0;
    if (_forYouPageController?.hasClients ?? false) {
      _forYouPageController!.jumpToPage(0);
    }

    // Reload For You videos
    setState(() {
      _isLoadingForYou = true;
    });

    try {
      await _loadForYouVideos(excludeIds: currentVideoIds);
    } catch (e) {
      print('Error refreshing For You feed: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingForYou = false;
        _videos = _forYouVideos;
      });

      // Resume first video after short delay
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _resumeCurrentVideo();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAllPageControllers();
    
    // Initialize current tab index in playback service (default is For You = 2)
    _videoPlaybackService.setCurrentTabIndex(_selectedFeedTab);
    
    // Add listeners to reload videos when auth state changes
    _authService.addLogoutListener(_onAuthChanged);
    _authService.addLoginListener(_onAuthChanged);
    
    // Listen to video playback service for tab visibility changes
    _videoPlaybackService.addListener(_onPlaybackServiceChanged);
    
    // Load persisted tab visit timestamps for badge indicators
    _loadTabVisitTimestamps();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVideos();
      _checkNewVideoIndicators();
    });
  }
  
  /// Load persisted last-visit timestamps from SharedPreferences
  Future<void> _loadTabVisitTimestamps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final followingMs = prefs.getInt('lastFollowingVisit');
      final friendsMs = prefs.getInt('lastFriendsVisit');
      if (followingMs != null) {
        _lastFollowingVisit = DateTime.fromMillisecondsSinceEpoch(followingMs);
      }
      if (friendsMs != null) {
        _lastFriendsVisit = DateTime.fromMillisecondsSinceEpoch(friendsMs);
      }
    } catch (e) {
      // Silent fail
    }
  }
  
  /// Persist tab visit timestamp to SharedPreferences
  Future<void> _saveTabVisitTimestamp(String key, DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, time.millisecondsSinceEpoch);
    } catch (e) {
      // Silent fail
    }
  }
  
  void _initAllPageControllers() {
    _forYouPageController = PageController();
    _friendsPageController = PageController();
    _followingPageController = PageController();
    
    // Initialize horizontal tab controller starting at "For You" tab (index 2)
    _horizontalTabController = PageController(initialPage: 2);
    _horizontalTabController!.addListener(_onHorizontalTabScroll);
    
    // Add listeners to each controller
    _forYouPageController!.addListener(() => _onPageControllerChanged(_forYouPageController!, 2));
    _friendsPageController!.addListener(() => _onPageControllerChanged(_friendsPageController!, 1));
    _followingPageController!.addListener(() => _onPageControllerChanged(_followingPageController!, 0));
    print('VideoScreen: All PageControllers initialized');
  }
  
  void _onHorizontalTabScroll() {
    // This is called during scrolling, we only need to handle page changes in onPageChanged
  }
  
  void _onPageControllerChanged(PageController controller, int tabIndex) {
    if (controller.page != null && _selectedFeedTab == tabIndex) {
      final newPage = controller.page!.round();
      if (newPage != _currentPage) {
        print('VideoScreen: PageController listener - page changed from $_currentPage to $newPage (tab $tabIndex)');
        setState(() {
          _currentPage = newPage;
          // Also save to tab-specific page position
          if (tabIndex == 2) _forYouCurrentPage = newPage;
          else if (tabIndex == 1) _friendsCurrentPage = newPage;
          else _followingCurrentPage = newPage;
        });
        // Prefetch next videos when page changes
        _prefetchService.prefetchVideosAround(_videos, newPage);
      }
    }
  }
  
  void _onAuthChanged() {
    print('VideoScreen: Auth state changed - reloading videos');
    // Clear like/save cache on auth change so stale state isn't shown
    LikeService.clearCache();
    SavedVideoService.clearCache();
    // Clear caches and reload
    _likeStatus.clear();
    _saveStatus.clear();
    _followStatus.clear();
    _requestedStatus.clear();
    _forYouVideos.clear();
    _followingVideos.clear();
    _friendsVideos.clear();
    // Reset loading states
    _isLoadingForYou = true;
    _isLoadingFollowing = true;
    _isLoadingFriends = true;
    _loadVideos();
  }
  
  void _onPlaybackServiceChanged() {
    print('VideoScreen: PlaybackService changed - isVideoTabVisible=${_videoPlaybackService.isVideoTabVisible}, wasManuallyPaused=${_videoPlaybackService.wasManuallyPaused}');
    if (mounted) {
      setState(() {});
      if (_videoPlaybackService.isVideoTabVisible) {
        _resumeCurrentVideo();
      } else {
        _pauseCurrentVideo();
      }
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Pause video when app goes to background
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Send watch time when app goes to background
      _sendWatchTime();
      _pauseCurrentVideo();
    } else if (state == AppLifecycleState.resumed) {
      // Resume video when app comes back if tab is visible
      if (_videoPlaybackService.isVideoTabVisible) {
        _resumeCurrentVideo();
        // Restart tracking for current video
        if (_videos.isNotEmpty && _currentPage < _videos.length) {
          final video = _videos[_currentPage];
          if (video != null && video['id'] != null) {
            final videoId = video['id'].toString();
            final duration = video['duration'] as int? ?? 30;
            _startWatchTimeTracking(videoId, duration);
          }
        }
      }
    }
  }
  
  void _pauseCurrentVideo() {
    print('VideoScreen: _pauseCurrentVideo called');
    _currentVideoPlayerState?.pauseVideo();
  }
  
  void _resumeCurrentVideo() {
    // Only resume if user didn't manually pause (check per-tab state)
    if (!_videoPlaybackService.wasManuallyPausedForTab(_selectedFeedTab)) {
      print('VideoScreen: _resumeCurrentVideo - resuming video on tab $_selectedFeedTab');
      _currentVideoPlayerState?.resumeVideo();
    } else {
      print('VideoScreen: _resumeCurrentVideo - NOT resuming on tab $_selectedFeedTab (was manually paused)');
    }
  }

  // Remove these methods - no longer needed
  // void _onLogin() { ... }
  // void _onLogout() { ... }

  // Remove didChangeDependencies check - not needed with key-based rebuild
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Remove _checkAndReloadIfNeeded() - MainScreen handles this now
  }

  // Remove _checkAndReloadIfNeeded method

  @override
  void dispose() {
    // Send final watch time before disposing
    _sendWatchTime();
    
    WidgetsBinding.instance.removeObserver(this);
    // Remove auth listeners
    _authService.removeLogoutListener(_onAuthChanged);
    _authService.removeLoginListener(_onAuthChanged);
    // Remove playback service listener
    _videoPlaybackService.removeListener(_onPlaybackServiceChanged);
    // Dispose all PageControllers
    _horizontalTabController?.removeListener(_onHorizontalTabScroll);
    _horizontalTabController?.dispose();
    _forYouPageController?.dispose();
    _friendsPageController?.dispose();
    _followingPageController?.dispose();
    _userCache.clear();
    _likeStatus.clear();
    _likeCounts.clear();
    _commentCounts.clear();
    _followStatus.clear();
    _requestedStatus.clear();
    _currentVideoPlayerState = null;
    super.dispose();
  }

  // ========== Watch Time Tracking ==========
  
  /// Start tracking watch time for a video
  void _startWatchTimeTracking(String videoId, int? durationSeconds) {
    // Send previous video's watch time first
    _sendWatchTime();
    
    // Start tracking new video
    _videoStartTime = DateTime.now();
    _currentWatchingVideoId = videoId;
    _currentVideoDuration = durationSeconds;
  }
  
  /// Send watch time to server (for recommendation algorithm)
  void _sendWatchTime() {
    if (_currentWatchingVideoId == null || _videoStartTime == null) return;
    if (!_authService.isLoggedIn || _authService.user == null) return;
    
    final watchDuration = DateTime.now().difference(_videoStartTime!).inSeconds;
    
    // Only record if watched for more than 1 second
    if (watchDuration > 1) {
      final userId = _authService.user!['id'].toString();
      final videoId = _currentWatchingVideoId!;
      final videoDuration = _currentVideoDuration ?? 30; // Default 30 seconds if unknown
      
      // Fire and forget - don't await to avoid blocking UI
      _apiService.recordWatchTime(
        userId: userId,
        videoId: videoId,
        watchDuration: watchDuration,
        videoDuration: videoDuration,
      ).then((result) {
        if (result['success'] == true) {
          final data = result['data'];
          print('Watch time sent: ${watchDuration}s / ${videoDuration}s (${data?['watchPercentage']?.toStringAsFixed(1) ?? 0}%)');
        }
      }).catchError((e) {
        // Silent fail - analytics shouldn't break UX
      });
    }
    
    // Reset tracking
    _videoStartTime = null;
    _currentWatchingVideoId = null;
    _currentVideoDuration = null;
  }

  /// Check if there are new videos in Following/Friends tabs (for red dot indicators)
  Future<void> _checkNewVideoIndicators() async {
    if (!_authService.isLoggedIn || _authService.user == null) return;
    
    final userId = _authService.user!['id'].toString();
    // Default "since" = 24 hours ago if no last visit recorded
    final defaultSince = DateTime.now().subtract(const Duration(hours: 24));
    
    try {
      final results = await Future.wait([
        _videoService.getFollowingNewVideoCount(
          userId, _lastFollowingVisit ?? defaultSince,
        ),
        _videoService.getFriendsNewVideoCount(
          userId, _lastFriendsVisit ?? defaultSince,
        ),
      ]);
      
      if (mounted) {
        setState(() {
          _hasNewFollowing = results[0] > 0;
          _hasNewFriends = results[1] > 0;
        });
      }
    } catch (e) {
      // Silent fail - indicators are not critical
    }
  }

  Future<void> _loadVideos() async {
    try {
      if (mounted) {
        setState(() {
          // Set loading state for current tab
          if (_selectedFeedTab == 2) _isLoadingForYou = true;
          else if (_selectedFeedTab == 1) _isLoadingFriends = true;
          else _isLoadingFollowing = true;
        });
      }

      if (_selectedFeedTab == 2) {
        // For You feed
        await _loadForYouVideos();
      } else if (_selectedFeedTab == 1) {
        // Friends feed - videos from mutual friends
        await _loadFriendsVideos();
      } else {
        // Following feed - videos from followed users
        await _loadFollowingVideos();
      }

      if (mounted) {
        setState(() {
          // Clear loading state for current tab
          if (_selectedFeedTab == 2) _isLoadingForYou = false;
          else if (_selectedFeedTab == 1) _isLoadingFriends = false;
          else _isLoadingFollowing = false;
        });
      }
    } catch (e) {
      print('Error loading videos: $e');
      if (mounted) {
        setState(() {
          // Clear loading state on error
          if (_selectedFeedTab == 2) _isLoadingForYou = false;
          else if (_selectedFeedTab == 1) _isLoadingFriends = false;
          else _isLoadingFollowing = false;
        });
      }
    }
  }

  Future<void> _loadForYouVideos({List<String>? excludeIds}) async {
    // Use personalized recommendations if user is logged in
    List<dynamic> videos;
    
    if (_authService.isLoggedIn && _authService.user != null) {
      final userId = _authService.user!['id'] as int;
      print('Loading personalized recommendations for user $userId');
      videos = await _videoService.getRecommendedVideos(userId, excludeIds: excludeIds);
    } else {
      // For guests, use trending videos or regular feed
      print('Loading trending videos for guest');
      videos = await _videoService.getTrendingVideos();
    }
    
    final readyVideos = videos.where((v) => v != null && v['status'] == 'ready').toList();

    // Process videos and wait for all status checks to complete
    await _processVideos(readyVideos);
    
    if (mounted) {
      setState(() {
        _forYouVideos = readyVideos;
        _videos = _forYouVideos;
      });
      
      // Prefetch first few videos immediately after loading
      _prefetchService.prefetchVideosAround(readyVideos, 0);

      // Start watch time tracking for the first video (onPageChanged doesn't fire for initial page)
      if (readyVideos.isNotEmpty && _currentPage == 0 && _selectedFeedTab == 2) {
        final firstVideo = readyVideos[0];
        if (firstVideo != null && firstVideo['id'] != null) {
          final videoId = firstVideo['id'].toString();
          final duration = firstVideo['duration'] as int? ?? 30;
          _startWatchTimeTracking(videoId, duration);
        }
      }
    }
  }

  Future<void> _loadFollowingVideos() async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      if (mounted) {
        setState(() {
          _followingVideos = [];
          _videos = _followingVideos;
        });
      }
      return;
    }

    // REMOVE cache check - always reload status from server
    // if (_followingVideos.isNotEmpty) { ... }

    final userId = _authService.user!['id'].toString();
    final videos = await _videoService.getFollowingVideos(userId);
    final readyVideos = videos.where((v) => v != null && v['status'] == 'ready').toList();

    await _processVideos(readyVideos);
    
    if (mounted) {
      setState(() {
        _followingVideos = readyVideos;
        _videos = _followingVideos;
      });

      // Start watch time tracking for first video
      if (readyVideos.isNotEmpty && _selectedFeedTab == 0 && _followingCurrentPage == 0) {
        final firstVideo = readyVideos[0];
        if (firstVideo != null && firstVideo['id'] != null) {
          _startWatchTimeTracking(firstVideo['id'].toString(), firstVideo['duration'] as int? ?? 30);
        }
      }
    }
  }

  Future<void> _loadFriendsVideos() async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      if (mounted) {
        setState(() {
          _friendsVideos = [];
          _videos = _friendsVideos;
        });
      }
      return;
    }

    final userId = _authService.user!['id'].toString();
    // Use the dedicated friends API - only mutual follows
    final videos = await _videoService.getFriendsVideos(userId);
    final readyVideos = videos.where((v) => v != null && v['status'] == 'ready').toList();

    await _processVideos(readyVideos);
    
    if (mounted) {
      setState(() {
        _friendsVideos = readyVideos;
        _videos = _friendsVideos;
      });

      // Start watch time tracking for first video
      if (readyVideos.isNotEmpty && _selectedFeedTab == 1 && _friendsCurrentPage == 0) {
        final firstVideo = readyVideos[0];
        if (firstVideo != null && firstVideo['id'] != null) {
          _startWatchTimeTracking(firstVideo['id'].toString(), firstVideo['duration'] as int? ?? 30);
        }
      }
    }
  }

  Future<void> _processVideos(List<dynamic> readyVideos) async {
    // Only set/overwrite status for videos in this batch (don't clear global maps
    // so that other tabs' statuses are preserved when switching tabs)

    // Initialize counts first (immediate display)
    for (var video in readyVideos) {
      if (video == null || video['id'] == null) continue;
      
      final videoId = video['id'].toString();
      _likeCounts[videoId] = _parseIntSafe(video['likeCount']);
      _commentCounts[videoId] = _parseIntSafe(video['commentCount']);
      _saveCounts[videoId] = _parseIntSafe(video['saveCount']);
      _shareCounts[videoId] = _parseIntSafe(video['shareCount']);
      _viewCounts[videoId] = _parseIntSafe(video['viewCount']);
      
      // Track privacy settings for own videos
      _videoVisibility[videoId] = video['visibility']?.toString() ?? 'public';
      _videoAllowComments[videoId] = video['allowComments'] ?? true;
      _videoAllowDuet[videoId] = video['allowDuet'] ?? true;
      
      // Seed from cache so heart/bookmark shows correct immediately; fallback to payload or false
      _likeStatus[videoId] = _likeService.getCached(videoId) ?? (video['isLiked'] == true ? true : false);
      _likeCounts[videoId] = _likeService.getCachedCount(videoId) ?? _parseIntSafe(video['likeCount']);
      _saveStatus[videoId] = _savedVideoService.getCached(videoId) ?? false;
      _saveCounts[videoId] = _savedVideoService.getCachedCount(videoId) ?? _parseIntSafe(video['saveCount']);
    }

    // IMPORTANT: Update UI immediately with default values
    if (mounted) {
      setState(() {});
    }

    // Load like/save status from server if logged in
    if (_authService.isLoggedIn && _authService.user != null) {
      final userId = _authService.user!['id']?.toString();
      print('User logged in, loading statuses for userId: $userId');
      
      if (userId != null && userId.isNotEmpty) {
        // Create list of futures to run in parallel
        List<Future<void>> statusFutures = [];

        for (var video in readyVideos) {
          if (video == null || video['id'] == null) continue;
          
          final videoId = video['id'].toString();
          
          // Check like status
          statusFutures.add(
            _likeService.isLikedByUser(videoId, userId).then((isLiked) {
              _likeStatus[videoId] = isLiked;
              print('Video $videoId liked: $isLiked');
            }).catchError((e) {
              print('Error checking like status for $videoId: $e');
              // keep cache seed on error - don't override with false
            })
          );
          
          // Check save status
          statusFutures.add(
            _savedVideoService.isSavedByUser(videoId, userId).then((isSaved) {
              _saveStatus[videoId] = isSaved;
              print('Video $videoId saved: $isSaved');
            }).catchError((e) {
              print('Error checking save status for $videoId: $e');
              // keep cache seed on error - don't override with false
            })
          );
        }

        // Wait for all status checks to complete
        await Future.wait(statusFutures);
        
        print('All like/save statuses loaded:');
        _likeStatus.forEach((k, v) => print('   Like $k: $v'));
        _saveStatus.forEach((k, v) => print('   Save $k: $v'));
        
        // IMPORTANT: Trigger rebuild AFTER all statuses are loaded
        if (mounted) {
          setState(() {
            print('Rebuilding UI with loaded statuses');
          });
        }
      }
    } else {
      print('User not logged in, all statuses set to false');
    }

    // Check follow status for each video owner
    if (_authService.isLoggedIn && _authService.user != null) {
      final currentUserId = _authService.user!['id'] as int;
      
      List<Future<void>> followFutures = [];
      
      for (var video in readyVideos) {
        if (video == null || video['userId'] == null) continue;
        
        final videoOwnerId = int.tryParse(video['userId'].toString());
        if (videoOwnerId != null && videoOwnerId != currentUserId) {
          followFutures.add(
            _followService.getFollowStatus(currentUserId, videoOwnerId).then((status) {
              _followStatus[videoOwnerId.toString()] = status == 'following';
              _requestedStatus[videoOwnerId.toString()] = status == 'pending';
            }).catchError((e) {
              _followStatus[videoOwnerId.toString()] = false;
              _requestedStatus[videoOwnerId.toString()] = false;
            })
          );
        }
      }
      
      await Future.wait(followFutures);
      
      // Update UI after follow statuses loaded
      if (mounted) {
        setState(() {});
      }
    }

    // Populate owner-level whoCanComment from video response data (no extra API call)
    for (var video in readyVideos) {
      if (video == null || video['userId'] == null) continue;
      final ownerId = video['userId'].toString();
      if (_ownerCommentDisabled.containsKey(ownerId)) continue;
      final whoCanComment = video['ownerWhoCanComment'] ?? 'everyone';
      _ownerCommentDisabled[ownerId] = (whoCanComment == 'noOne' || whoCanComment == 'onlyMe');
    }
  }

  // Add helper method to safely parse int
  int _parseIntSafe(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Check if comments are effectively enabled for a video
  /// Combines per-video allowComments AND owner-level whoCanComment
  bool _isCommentsEffectivelyEnabled(String videoId, String? ownerId) {
    final perVideo = _videoAllowComments[videoId] ?? true;
    final ownerDisabled = ownerId != null ? (_ownerCommentDisabled[ownerId] ?? false) : false;
    return perVideo && !ownerDisabled;
  }

  IconData _getVisibilityIcon(String visibility) {
    switch (visibility.toLowerCase()) {
      case 'private':
        return Icons.lock_outline;
      case 'friends':
        return Icons.people_outline;
      default:
        return Icons.public;
    }
  }

  String _getVisibilityLabel(String visibility) {
    switch (visibility.toLowerCase()) {
      case 'private':
        return _localeService.isVietnamese ? 'Riêng tư' : 'Private';
      case 'friends':
        return _localeService.isVietnamese ? 'Bạn bè' : 'Friends';
      default:
        return _localeService.isVietnamese ? 'Công khai' : 'Public';
    }
  }

  /// Navigate to login screen from video tab  
  void _navigateToLogin() {
    // Navigate directly to login screen
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    ).then((result) {
      // Refresh screen after login if successful
      if (result == true && mounted) {
        setState(() {});
        _loadVideos();
      }
    });
  }

  void _onTabChanged(int index) {
    if (_selectedFeedTab == index) return;
    
    final previousTab = _selectedFeedTab;
    print('VideoScreen: Switching from tab $previousTab to tab $index');
    
    // Animate horizontal PageView to the selected tab
    if (_horizontalTabController?.hasClients ?? false) {
      _horizontalTabController!.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  // Called when horizontal PageView page changes (either by tap or swipe)
  void _onHorizontalPageChanged(int index) {
    if (_selectedFeedTab == index) return;
    
    final previousTab = _selectedFeedTab;
    print('VideoScreen: Horizontal page changed from $previousTab to $index');
    
    // Flush watch time for current video before switching tabs
    _sendWatchTime();
    
    // Save current video playback state before switching tab
    _saveCurrentVideoPlaybackState();
    
    // Save current page position for the tab we're leaving
    _saveCurrentPagePosition(previousTab);
    
    // Pause current video when switching tabs
    _pauseCurrentVideo();
    
    // Update current tab index in playback service for per-tab pause state
    _videoPlaybackService.setCurrentTabIndex(index);
    
    setState(() {
      _selectedFeedTab = index;
      _videos = _getVideosForTab(index);
      _currentPage = _getSavedPagePosition(index);
      
      // Clear red dot indicator when visiting a tab and persist timestamp
      if (index == 0) {
        _hasNewFollowing = false;
        _lastFollowingVisit = DateTime.now();
        _saveTabVisitTimestamp('lastFollowingVisit', _lastFollowingVisit!);
      } else if (index == 1) {
        _hasNewFriends = false;
        _lastFriendsVisit = DateTime.now();
        _saveTabVisitTimestamp('lastFriendsVisit', _lastFriendsVisit!);
      }
    });
    
    // Load videos for target tab if still loading
    if (index == 2 && _isLoadingForYou) {
      print('VideoScreen: Loading For You videos (still loading)');
      _loadVideos();
    } else if (index == 1 && _isLoadingFriends) {
      print('VideoScreen: Loading Friends videos (still loading)');
      _loadVideos();
    } else if (index == 0 && _isLoadingFollowing) {
      print('VideoScreen: Loading Following videos (still loading)');
      _loadVideos();
    } else {
      print('VideoScreen: Using cached videos for tab $index (${_videos.length} videos), page $_currentPage');
      // Resume video playback for the target tab after a short delay
      // Check per-tab pause state
      if (!_videoPlaybackService.wasManuallyPausedForTab(index)) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _resumeCurrentVideo();
          }
        });
      } else {
        print('VideoScreen: Not resuming video on tab $index (was manually paused)');
      }
    }
  }
  
  List<dynamic> _getVideosForTab(int tabIndex) {
    if (tabIndex == 2) {
      return _forYouVideos;
    } else if (tabIndex == 1) {
      return _friendsVideos;
    } else {
      return _followingVideos;
    }
  }
  
  void _saveCurrentPagePosition(int tabIndex) {
    print('VideoScreen: Saving page position $_currentPage for tab $tabIndex');
    if (tabIndex == 2) {
      _forYouCurrentPage = _currentPage;
    } else if (tabIndex == 1) {
      _friendsCurrentPage = _currentPage;
    } else {
      _followingCurrentPage = _currentPage;
    }
  }
  
  int _getSavedPagePosition(int tabIndex) {
    if (tabIndex == 2) {
      return _forYouCurrentPage;
    } else if (tabIndex == 1) {
      return _friendsCurrentPage;
    } else {
      return _followingCurrentPage;
    }
  }
  
  // Save current video playback state (position + pause state)
  void _saveCurrentVideoPlaybackState() {
    if (_currentVideoPlayerState != null && _videos.isNotEmpty && _currentPage < _videos.length) {
      final video = _videos[_currentPage];
      final videoId = video?['id']?.toString() ?? '';
      if (videoId.isNotEmpty) {
        final position = _currentVideoPlayerState!.currentPosition;
        final isPaused = !_currentVideoPlayerState!.isPlaying;
        _videoPlaybackService.saveVideoState(_selectedFeedTab, videoId, position, isPaused);
        print('VideoScreen: Saved playback state for video $videoId in tab $_selectedFeedTab - position=$position, paused=$isPaused');
      }
    }
  }

  Future<void> _handleLike(String videoId) async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      LoginRequiredDialog.show(context, 'like');
      return;
    }

    final userId = _authService.user!['id']?.toString();
    if (userId == null || userId.isEmpty) {
      print('Invalid user ID');
      return;
    }

    print('Toggle like for video $videoId by user $userId');
    
    final result = await _likeService.toggleLike(videoId, userId);

    if (mounted) {
      setState(() {
        _likeStatus[videoId] = result['liked'] ?? false;
        _likeCounts[videoId] = result['likeCount'] ?? 0;
      });
      
      print('${result['liked'] ? '❤️' : '🤍'} Like toggled - Status: ${result['liked']}, Count: ${result['likeCount']}');
    }
  }

  Future<void> _handleFollow(int videoOwnerId, {int? videoIndex}) async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      LoginRequiredDialog.show(context, 'follow');
      return;
    }

    final currentUserId = _authService.user!['id'] as int;
    
    if (currentUserId == videoOwnerId) {
      return;
    }

    print('Toggle follow for user $videoOwnerId by user $currentUserId');
    
    final result = await _followService.toggleFollow(currentUserId, videoOwnerId);
    final isNowFollowing = result['following'] ?? false;
    final isRequested = result['requested'] ?? false;

    if (mounted) {
      setState(() {
        _followStatus[videoOwnerId.toString()] = isNowFollowing;
        _requestedStatus[videoOwnerId.toString()] = isRequested;
      });
      
      print('${isNowFollowing ? '✅' : isRequested ? '⏳' : '❌'} Follow toggled - Following: $isNowFollowing, Requested: $isRequested');
      // Videos stay visible — they are only removed on next feed refresh/reload
    }
  }
  
  /// Build context-aware follow/friend button based on current feed tab
  Widget _buildFollowButton(int videoOwnerId, bool isFollowing, int videoIndex) {
    final isRequested = _requestedStatus[videoOwnerId.toString()] ?? false;
    // Determine button text and style based on tab context
    String buttonText;
    Color borderColor;
    Color textColor;
    IconData? icon;
    
    if (isRequested) {
      // Pending follow request
      buttonText = _localeService.get('requested');
      borderColor = Colors.orange.withValues(alpha: 0.7);
      textColor = Colors.orange.withValues(alpha: 0.9);
      icon = Icons.hourglass_top_rounded;
    } else if (_selectedFeedTab == 1 && isFollowing) {
      // Friends tab — mutual friends, show "Bạn bè" with icon
      buttonText = _localeService.isVietnamese ? 'Bạn bè' : 'Friends';
      borderColor = Colors.grey[600]!;
      textColor = Colors.grey[400]!;
      icon = Icons.people_outline;
    } else if (_selectedFeedTab == 0 && isFollowing) {
      // Following tab — one-way follow, show "Đang theo dõi"
      buttonText = _localeService.isVietnamese ? 'Đang theo dõi' : 'Following';
      borderColor = Colors.grey[600]!;
      textColor = Colors.grey[400]!;
      icon = null;
    } else if (isFollowing) {
      // For You tab or any other — currently following
      buttonText = _localeService.isVietnamese ? 'Đang theo dõi' : 'Following';
      borderColor = Colors.grey[600]!;
      textColor = Colors.grey[400]!;
      icon = null;
    } else {
      // Not following — show "Theo dõi"
      buttonText = _localeService.get('follow');
      borderColor = Colors.white;
      textColor = Colors.white;
      icon = null;
    }
    
    return GestureDetector(
      onTap: () => _handleFollow(videoOwnerId, videoIndex: videoIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(4),
          color: Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: textColor),
              const SizedBox(width: 4),
            ],
            Text(
              buttonText,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave(String videoId) async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      LoginRequiredDialog.show(context, 'save');
      return;
    }

    final userId = _authService.user!['id']?.toString();
    if (userId == null || userId.isEmpty) return;

    final result = await _savedVideoService.toggleSave(videoId, userId);

    if (mounted) {
      setState(() {
        _saveStatus[videoId] = result['saved'] ?? false;
        _saveCounts[videoId] = result['saveCount'] ?? (_saveCounts[videoId] ?? 0);
      });

      print(result['saved'] ? '🟡 Video saved' : '⚪ Video unsaved');
    }
  }

  void _handleShare(String videoId) {
    if (!_authService.isLoggedIn || _authService.user == null) {
      LoginRequiredDialog.show(context, 'share');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareVideoSheet(
        videoId: videoId,
        onShareComplete: (shareCount) {
          if (mounted) {
            setState(() {
              _shareCounts[videoId] = shareCount;
            });
          }
        },
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  // Show TikTok-style long-press options sheet
  void _showVideoOptionsSheet(dynamic video, String videoId, String? userId) {
    final currentUserId = _authService.userId?.toString();
    final isOwnVideo = currentUserId != null && userId == currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => VideoOptionsSheet(
        videoId: videoId,
        videoOwnerId: userId,
        isOwnVideo: isOwnVideo,
        currentSpeed: _playbackSpeed,
        autoScroll: _autoScroll,
        onSpeedChanged: (speed) {
          _playbackSpeed = speed;
          _currentVideoPlayerState?.setPlaybackSpeed(speed);
        },
        onAutoScrollChanged: (val) {
          _autoScroll = val;
          // Toggle looping: when auto-scroll is ON, don't loop so onVideoEnd fires
          _currentVideoPlayerState?.setLooping(!val);
        },
        onReport: () {
          AppSnackBar.showInfo(
            context,
            _localeService.get('report_submitted'),
          );
        },
        onCopyLink: () {
          AppSnackBar.showSuccess(
            context,
            _localeService.get('link_copied'),
          );
        },
      ),
    );
  }

  // Handle auto-scroll when video ends
  void _handleVideoEnd(int tabIndex) {
    if (!_autoScroll || _autoScrollTriggered) return;
    _autoScrollTriggered = true;

    final pageController = _getPageController(tabIndex);
    final videos = _getVideosForTab(tabIndex);
    final currentPage = _getCurrentPageForTab(tabIndex);

    if (pageController != null && currentPage < videos.length - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }

    // Reset trigger after animation completes
    Future.delayed(const Duration(milliseconds: 500), () {
      _autoScrollTriggered = false;
    });
  }

  PageController? _getPageController(int tabIndex) {
    switch (tabIndex) {
      case 0: return _followingPageController;
      case 1: return _friendsPageController;
      case 2: return _forYouPageController;
      default: return null;
    }
  }

  int _getCurrentPageForTab(int tabIndex) {
    switch (tabIndex) {
      case 0: return _followingCurrentPage;
      case 1: return _friendsCurrentPage;
      case 2: return _forYouCurrentPage;
      default: return 0;
    }
  }

  // Show owner "More" options sheet - TikTok style
  void _showOwnerMoreOptions(dynamic video, String videoId, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => VideoMoreOptionsSheet(
        videoId: videoId,
        userId: userId,
        isHidden: video['isHidden'] ?? false,
        onEditTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditVideoScreen(
                videoId: videoId,
                userId: userId,
                currentTitle: video['title']?.toString(),
                currentDescription: video['description']?.toString(),
                currentThumbnailUrl: video['thumbnailUrl']?.toString(),
                onSaved: (description, thumbnailUrl) {
                  if (mounted) {
                    setState(() {
                      video['description'] = description;
                      if (thumbnailUrl != null) {
                        video['thumbnailUrl'] = thumbnailUrl;
                      }
                    });
                  }
                },
              ),
            ),
          );
        },
        onPrivacyTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (context) => VideoPrivacySheet(
              videoId: videoId,
              userId: userId,
              currentVisibility: video['isHidden'] == true ? 'private' : (_videoVisibility[videoId] ?? 'public'),
              allowComments: video['isHidden'] == true ? false : (_videoAllowComments[videoId] ?? true),
              allowDuet: _videoAllowDuet[videoId] ?? true,
              isHidden: video['isHidden'] == true,
              onChanged: (visibility, allowComments, allowDuet) {
                if (mounted) {
                  setState(() {
                    _videoVisibility[videoId] = visibility;
                    _videoAllowComments[videoId] = allowComments;
                    _videoAllowDuet[videoId] = allowDuet;
                    video['visibility'] = visibility;
                    video['allowComments'] = allowComments;
                    video['allowDuet'] = allowDuet;
                    // Sync: if visibility changed from private, auto-unhide
                    if (visibility != 'private' && video['isHidden'] == true) {
                      video['isHidden'] = false;
                    }
                  });
                }
              },
            ),
          );
        },
        onHideTap: () async {
          if (_isHideToggling) return; // Prevent race condition
          _isHideToggling = true;
          final isHidden = video['isHidden'] ?? false;
          try {
            final result = await _videoService.toggleHideVideo(videoId, userId);
            if (result['success'] == true && mounted) {
              final newIsHidden = result['isHidden'] ?? !isHidden;
              setState(() {
                video['isHidden'] = newIsHidden;
                // Sync privacy state from backend response
                if (result['visibility'] != null) {
                  video['visibility'] = result['visibility'];
                  _videoVisibility[videoId] = result['visibility'];
                }
                if (result['allowComments'] != null) {
                  video['allowComments'] = result['allowComments'];
                  _videoAllowComments[videoId] = result['allowComments'] == true;
                }
              });
              AppSnackBar.showSuccess(
                context,
                newIsHidden
                    ? (_localeService.isVietnamese ? 'Đã ẩn video' : 'Video hidden')
                    : (_localeService.isVietnamese ? 'Đã hiện video' : 'Video visible'),
              );
            }
          } catch (e) {
            print('Error toggling video visibility: $e');
          } finally {
            _isHideToggling = false;
          }
        },
        onDeleteTap: () {
          _showDeleteConfirmation(video, videoId, userId);
        },
      ),
    );
  }

  // Show delete confirmation dialog - Modern style
  void _showDeleteConfirmation(dynamic video, String videoId, String userId) async {
    final confirmed = await AppDialog.showDeleteConfirmation(
      context,
      title: _localeService.isVietnamese ? 'Xóa video?' : 'Delete video?',
      message: _localeService.isVietnamese 
          ? 'Video sẽ bị xóa vĩnh viễn. Bạn không thể hoàn tác hành động này.'
          : 'This video will be permanently deleted. You cannot undo this action.',
    );
    
    if (confirmed == true && mounted) {
      try {
        final success = await _videoService.deleteVideo(videoId, userId);
        if (success && mounted) {
          AppSnackBar.showSuccess(
            context, 
            _localeService.isVietnamese ? 'Đã xóa video' : 'Video deleted',
          );
          _loadVideos();
        } else if (mounted) {
          AppSnackBar.showError(context, _localeService.get('error_occurred'));
        }
      } catch (e) {
        print('Error deleting video: $e');
        if (mounted) {
          AppSnackBar.showError(context, _localeService.get('error_occurred'));
        }
      }
    }
  }

  Future<Map<String, dynamic>> _getUserInfo(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return <String, dynamic>{'username': 'user', 'avatar': null};
    }
    
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }
    
    try {
      final userInfo = await _apiService.getUserById(userId);
      if (userInfo != null) {
        _userCache[userId] = userInfo;
        return userInfo;
      }
    } catch (e) {
      print('Error fetching user info: $e');
    }
    
    return <String, dynamic>{'username': 'user', 'avatar': null};
  }

  Widget _buildExpandableCaption(String caption, {bool isExpanded = false}) {
    if (caption.isEmpty) return const SizedBox.shrink();

    const int maxLinesCollapsed = 2;
    
    return Text(
      caption,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        height: 1.3,
        shadows: [
          Shadow(
            blurRadius: 8.0,
            color: Colors.black87,
            offset: Offset(1, 1),
          ),
        ],
      ),
      maxLines: isExpanded ? null : maxLinesCollapsed,
      overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
    );
  }
  
  /// Build the "End of videos" page
  Widget _buildEndOfVideosPage() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.withOpacity(0.2),
                      Colors.teal.withOpacity(0.1),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 48,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _localeService.isVietnamese 
                    ? 'Bạn đã xem hết video rồi!' 
                    : 'You\'re all caught up!',
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _localeService.isVietnamese 
                    ? 'Kéo xuống để làm mới hoặc khám phá nội dung mới' 
                    : 'Pull down to refresh or explore new content',
                style: TextStyle(
                  color: Colors.grey[400], 
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // Refresh action - plain text+icon, no box
              GestureDetector(
                onTap: _loadVideos,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 18, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(
                      _localeService.isVietnamese ? 'Làm mới' : 'Refresh',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Explore action - plain text+icon
              GestureDetector(
                onTap: () {
                  _videoPlaybackService.setVideoTabInvisible();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SearchScreen()),
                  ).then((_) {
                    _videoPlaybackService.setVideoTabVisible();
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.explore_outlined, size: 18, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(
                      _localeService.isVietnamese ? 'Khám phá nội dung mới' : 'Explore new content',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Build a single video item
  Widget _buildVideoItem(dynamic video, int index, int tabIndex, int currentPageForTab, bool isActiveTab) {
    if (video == null) {
      return Center(
        child: Text(_localeService.get('invalid_video'), style: const TextStyle(color: Colors.white)),
      );
    }
    
    final videoId = video['id']?.toString() ?? '';
    final hlsUrl = video['hlsUrl'] != null 
        ? _videoService.getVideoUrl(video['hlsUrl']) 
        : '';
    final thumbnailUrl = video['thumbnailUrl'] != null 
        ? _videoService.getVideoUrl(video['thumbnailUrl']) 
        : null;
    final userId = video['userId']?.toString();
    
    // Load videos within range of 2 to allow smooth pause transition
    final shouldLoadVideo = (index - currentPageForTab).abs() <= 2;
    
    // Check if this is the current playing video
    final isCurrentVideo = index == currentPageForTab && isActiveTab;
    
    return Stack(
      children: [
        // Video player
        if (hlsUrl.isNotEmpty && shouldLoadVideo)
          HLSVideoPlayer(
            key: ValueKey('video_${tabIndex}_$videoId'),
            videoUrl: hlsUrl,
            autoPlay: isCurrentVideo && _videoPlaybackService.isVideoTabVisible,
            isTabVisible: isActiveTab && _videoPlaybackService.isVideoTabVisible,
            tabIndex: tabIndex,
            videoId: videoId,
            thumbnailUrl: thumbnailUrl,
            onPlayerCreated: (playerState) {
              if (isCurrentVideo) {
                _currentVideoPlayerState = playerState;
                // Apply persisted speed & looping setting
                if (_playbackSpeed != 1.0) {
                  playerState?.setPlaybackSpeed(_playbackSpeed);
                }
                if (_autoScroll) {
                  playerState?.setLooping(false);
                }
              }
            },
            onLongPress: () => _showVideoOptionsSheet(video, videoId, userId),
            onVideoEnd: () => _handleVideoEnd(tabIndex),
          )
        else if (!shouldLoadVideo)
          // Show black screen with spinner for videos not in range
          Container(
            color: Colors.black,
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          )
        else
          Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 80, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(_localeService.get('video_unavailable'), style: const TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
          ),
      
        // Bottom info
        Positioned(
          bottom: 20,
          left: 12,
          right: 90,
          child: SafeArea(
            child: _buildVideoInfo(video, videoId, userId, index),
          ),
        ),
      
        // Controls
        if (videoId.isNotEmpty)
          Positioned(
            bottom: 8,
            right: 0,
            child: _buildVideoControls(video, videoId, userId),
          ),
      ],
    );
  }
  
  /// Build video info section (username, description, etc.)
  Widget _buildVideoInfo(dynamic video, String videoId, String? userId, int index) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserInfo(userId),
      builder: (context, snapshot) {
        Map<String, dynamic> userInfo;
        if (snapshot.hasData && snapshot.data != null) {
          userInfo = snapshot.data!;
        } else {
          userInfo = {'username': 'user', 'avatar': null};
        }
        
        final videoOwnerId = int.tryParse(userId ?? '');
        final currentUserId = _authService.user?['id'] as int?;
        final isOwnVideo = videoOwnerId != null && currentUserId != null && videoOwnerId == currentUserId;
        final isFollowing = videoOwnerId != null ? (_followStatus[videoOwnerId.toString()] ?? false) : false;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Privacy button and view count for own videos
            if (isOwnVideo)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (context) => VideoPrivacySheet(
                            videoId: videoId,
                            userId: userId!,
                            currentVisibility: video['isHidden'] == true ? 'private' : (_videoVisibility[videoId] ?? 'public'),
                            allowComments: video['isHidden'] == true ? false : (_videoAllowComments[videoId] ?? true),
                            allowDuet: _videoAllowDuet[videoId] ?? true,
                            isHidden: video['isHidden'] == true,
                            onChanged: (visibility, allowComments, allowDuet) {
                              setState(() {
                                _videoVisibility[videoId] = visibility;
                                _videoAllowComments[videoId] = allowComments;
                                _videoAllowDuet[videoId] = allowDuet;
                                // Sync: if visibility changed from private, auto-unhide
                                if (visibility != 'private' && video['isHidden'] == true) {
                                  video['isHidden'] = false;
                                }
                              });
                            },
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(150),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getVisibilityIcon(_videoVisibility[videoId] ?? 'public'),
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getVisibilityLabel(_videoVisibility[videoId] ?? 'public'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(150),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            _formatCount(_viewCounts[videoId] ?? video['viewCount'] ?? 0),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            // Username and follow button
            Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(videoOwnerId),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: userInfo['avatar'] != null
                        ? NetworkImage(_apiService.getAvatarUrl(userInfo['avatar']))
                        : null,
                    child: userInfo['avatar'] == null
                        ? const Icon(Icons.person, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _navigateToProfile(videoOwnerId),
                  child: Text(
                    userInfo['fullName'] ?? userInfo['username'] ?? 'user',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!isOwnVideo && videoOwnerId != null)
                  _buildFollowButton(videoOwnerId, isFollowing, index),
              ],
            ),
            const SizedBox(height: 8),
            
            // Description
            GestureDetector(
              onTap: () {
                setState(() {
                  _expandedCaptions[index] = !(_expandedCaptions[index] ?? false);
                });
              },
              child: _buildExpandableCaption(
                video['description'] ?? video['title'] ?? '',
                isExpanded: _expandedCaptions[index] ?? false,
              ),
            ),
          ],
        );
      },
    );
  }
  
  /// Build video controls (like, comment, share, etc.)
  Widget _buildVideoControls(dynamic video, String videoId, String? userId) {
    final commentsEnabled = _isCommentsEffectivelyEnabled(videoId, userId);
    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: VideoControlsWidget(
        showManageButton: false,
        showMoreButton: _authService.isLoggedIn && 
            _authService.user != null && 
            _authService.user!['id'].toString() == userId,
        onMoreTap: () => _showOwnerMoreOptions(video, videoId, userId!),
        onManageTap: () {},
        isLiked: _likeStatus[videoId] ?? false,
        isSaved: _saveStatus[videoId] ?? false,
        likeCount: _formatCount(_likeCounts[videoId] ?? 0),
        commentCount: commentsEnabled 
            ? _formatCount(_commentCounts[videoId] ?? 0) 
            : '',
        saveCount: _formatCount(_saveCounts[videoId] ?? 0),
        shareCount: (_shareCounts[videoId] ?? 0) == 0 ? _localeService.get('share') : _formatCount(_shareCounts[videoId] ?? 0),
        onLikeTap: () => _handleLike(videoId),
        onCommentTap: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: CommentSectionWidget(
                videoId: videoId,
                videoOwnerId: userId,
                allowComments: commentsEnabled,
                onCommentAdded: () async {
                  final count = await _commentService.getCommentCount(videoId);
                  if (mounted) setState(() => _commentCounts[videoId] = count);
                },
                onCommentDeleted: () async {
                  final count = await _commentService.getCommentCount(videoId);
                  if (mounted) setState(() => _commentCounts[videoId] = count);
                },
              ),
            ),
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            useSafeArea: false,
          );
        },
        onSaveTap: () => _handleSave(videoId),
        onShareTap: () => _handleShare(videoId),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    if (_horizontalTabController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Use PageView for horizontal tab switching (like TikTok swipe between tabs)
          // Each page uses AutomaticKeepAliveClientMixin to preserve state
          PageView(
            controller: _horizontalTabController,
            onPageChanged: _onHorizontalPageChanged,
            physics: const ClampingScrollPhysics(), // Smooth swipe like TikTok
            children: [
              // Tab 0: Following
              _TabVideoFeed(
                key: const PageStorageKey('following_tab'),
                tabIndex: 0,
                videos: _followingVideos,
                pageController: _followingPageController,
                isActiveTab: _selectedFeedTab == 0,
                isLoading: _isLoadingFollowing,
                isLoggedIn: _authService.isLoggedIn,
                buildVideoItem: _buildVideoItem,
                buildEndOfVideosPage: _buildEndOfVideosPage,
                onPageChanged: (index) => _handleVideoPageChanged(index, 0),
                onLoadVideos: _loadVideos,
                onLoginTap: _navigateToLogin,
                localeService: _localeService,
              ),
              // Tab 1: Friends
              _TabVideoFeed(
                key: const PageStorageKey('friends_tab'),
                tabIndex: 1,
                videos: _friendsVideos,
                pageController: _friendsPageController,
                isActiveTab: _selectedFeedTab == 1,
                isLoading: _isLoadingFriends,
                isLoggedIn: _authService.isLoggedIn,
                buildVideoItem: _buildVideoItem,
                buildEndOfVideosPage: _buildEndOfVideosPage,
                onPageChanged: (index) => _handleVideoPageChanged(index, 1),
                onLoadVideos: _loadVideos,
                onLoginTap: _navigateToLogin,
                localeService: _localeService,
              ),
              // Tab 2: For You
              _TabVideoFeed(
                key: const PageStorageKey('foryou_tab'),
                tabIndex: 2,
                videos: _forYouVideos,
                pageController: _forYouPageController,
                isActiveTab: _selectedFeedTab == 2,
                isLoading: _isLoadingForYou,
                isLoggedIn: _authService.isLoggedIn,
                buildVideoItem: _buildVideoItem,
                buildEndOfVideosPage: _buildEndOfVideosPage,
                onPageChanged: (index) => _handleVideoPageChanged(index, 2),
                onLoadVideos: _loadVideos,
                localeService: _localeService,
                showEndPage: true, // Only For You tab shows end page
              ),
            ],
          ),
        
          // Tab bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: FeedTabBar(
                selectedIndex: _selectedFeedTab,
                onTabChanged: _onTabChanged,
                hasNewFollowing: _hasNewFollowing,
                hasNewFriends: _hasNewFriends,
                onSearchTap: () {
                  _videoPlaybackService.setVideoTabInvisible();
                  print('VideoScreen: Navigating to search, pausing video');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SearchScreen()),
                  ).then((_) {
                    _videoPlaybackService.setVideoTabVisible();
                    print('VideoScreen: Returned from search, restoring video state');
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _handleVideoPageChanged(int index, int tabIndex) {
    // Only handle if this is the active tab
    if (_selectedFeedTab != tabIndex) return;
    
    final videos = _getVideosForTab(tabIndex);
    
    // Don't track for the "end of videos" page
    if (index >= videos.length) {
      print('VideoScreen: Reached end of videos page');
      return;
    }
    
    print('VideoScreen: Video page changed to index $index (tab $tabIndex)');
    setState(() {
      _currentPage = index;
      // Save to tab-specific position
      if (tabIndex == 2) _forYouCurrentPage = index;
      else if (tabIndex == 1) _friendsCurrentPage = index;
      else _followingCurrentPage = index;
    });
    
    // Prefetch next videos for smooth scrolling (like TikTok)
    _prefetchService.prefetchVideosAround(videos, index);
    
    // Increment view count when video is viewed
    final video = videos[index];
    if (video != null && video['id'] != null) {
      final videoId = video['id'].toString();
      
      // Only count view once per session
      if (_analyticsService.shouldCountView(videoId)) {
        _videoService.incrementViewCount(videoId);
      }
      
      // Start tracking watch time for recommendation algorithm
      final duration = video['duration'] as int? ?? 30;
      _startWatchTimeTracking(videoId, duration);
      
      // Start analytics tracking
      _analyticsService.startWatching(videoId);
    }
  }

  void _navigateToProfile(int? userId) {
    if (userId == null) return;
    
    final currentUserId = _authService.user?['id'] as int?;
    final isOwnProfile = currentUserId != null && currentUserId == userId;
    
    if (isOwnProfile) {
      mainScreenKey.currentState?.switchToProfileTab();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
      ).then((_) {
        // Refresh follow status when returning from profile
        _refreshFollowStatuses();
      });
    }
  }

  /// Refresh follow statuses for all visible videos
  Future<void> _refreshFollowStatuses() async {
    if (!_authService.isLoggedIn || _authService.user == null) return;
    final currentUserId = _authService.user!['id'] as int;
    
    // Collect all unique video owner IDs
    final ownerIds = <int>{};
    for (final videos in [_forYouVideos, _followingVideos, _friendsVideos]) {
      for (final video in videos) {
        final ownerId = int.tryParse(video?['userId']?.toString() ?? '');
        if (ownerId != null && ownerId != currentUserId) {
          ownerIds.add(ownerId);
        }
      }
    }
    
    // Re-check follow status for each owner
    for (final ownerId in ownerIds) {
      try {
        final status = await _followService.getFollowStatus(currentUserId, ownerId);
        if (mounted) {
          setState(() {
            _followStatus[ownerId.toString()] = status == 'following';
            _requestedStatus[ownerId.toString()] = status == 'pending';
          });
        }
      } catch (e) {
        // Ignore errors
      }
    }
  }
}

/// Separate widget for each tab's video feed with AutomaticKeepAliveClientMixin
/// This ensures the tab state is preserved when switching tabs (like TikTok)
class _TabVideoFeed extends StatefulWidget {
  final int tabIndex;
  final List<dynamic> videos;
  final PageController? pageController;
  final bool isActiveTab;
  final bool isLoading; // Loading state to show spinner instead of empty state
  final bool isLoggedIn; // Whether user is logged in (for login prompt on Following/Friends)
  final Widget Function(dynamic video, int index, int tabIndex, int currentPage, bool isActiveTab) buildVideoItem;
  final Widget Function() buildEndOfVideosPage;
  final void Function(int index) onPageChanged;
  final Future<void> Function() onLoadVideos;
  final VoidCallback? onLoginTap; // Callback when user taps login button
  final LocaleService localeService;
  final bool showEndPage;

  const _TabVideoFeed({
    super.key,
    required this.tabIndex,
    required this.videos,
    required this.pageController,
    required this.isActiveTab,
    required this.isLoading,
    required this.isLoggedIn,
    required this.buildVideoItem,
    required this.buildEndOfVideosPage,
    required this.onPageChanged,
    required this.onLoadVideos,
    this.onLoginTap,
    required this.localeService,
    this.showEndPage = false,
  });

  @override
  State<_TabVideoFeed> createState() => _TabVideoFeedState();
}

class _TabVideoFeedState extends State<_TabVideoFeed> with AutomaticKeepAliveClientMixin {
  int _currentPageForTab = 0;

  @override
  bool get wantKeepAlive => true; // CRITICAL: Keep this tab alive when switching

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    // PRIORITY: Show loading spinner while loading (before checking empty state)
    if (widget.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    
    // Show login prompt for Following/Friends tabs when not logged in
    if (!widget.isLoggedIn && widget.tabIndex != 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                widget.localeService.isVietnamese 
                    ? 'Đăng nhập để xem video' 
                    : 'Log in to watch videos',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.tabIndex == 0
                    ? (widget.localeService.isVietnamese 
                        ? 'Đăng nhập để xem video từ những người bạn đang theo dõi' 
                        : 'Log in to see videos from people you follow')
                    : (widget.localeService.isVietnamese 
                        ? 'Đăng nhập để xem video từ bạn bè của bạn' 
                        : 'Log in to see videos from your friends'),
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: widget.onLoginTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(
                  widget.localeService.isVietnamese ? 'Đăng nhập' : 'Log in',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show empty state ONLY after loading is complete
    if (widget.videos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.tabIndex == 2
                      ? Colors.green.withOpacity(0.1)
                      : Colors.white.withOpacity(0.05),
                ),
                child: Icon(
                  widget.tabIndex == 2 
                      ? Icons.check_circle_outline_rounded
                      : widget.tabIndex == 0 
                          ? Icons.person_add_alt_1_rounded 
                          : Icons.people_alt_rounded,
                  size: 40,
                  color: widget.tabIndex == 2 ? Colors.green : Colors.grey[400],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.tabIndex == 2
                    ? (widget.localeService.isVietnamese 
                        ? 'Bạn đã xem hết video rồi!' 
                        : 'You\'re all caught up!')
                    : widget.tabIndex == 0 
                        ? widget.localeService.get('no_videos_following')
                        : widget.localeService.get('no_videos_yet'),
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.tabIndex == 2
                    ? (widget.localeService.isVietnamese 
                        ? 'Kéo xuống để làm mới hoặc khám phá nội dung mới' 
                        : 'Pull down to refresh or explore new content')
                    : widget.tabIndex == 0
                        ? widget.localeService.get('follow_others_hint')
                        : widget.localeService.get('be_first_upload'),
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: widget.onLoadVideos,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 18, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(
                      widget.localeService.get('reload'),
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (widget.pageController == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    
    return RefreshIndicator(
      onRefresh: widget.onLoadVideos,
      child: PageView.builder(
        controller: widget.pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.showEndPage && widget.videos.isNotEmpty 
            ? widget.videos.length + 1 
            : widget.videos.length,
        physics: const ClampingScrollPhysics(),
        onPageChanged: (index) {
          _currentPageForTab = index;
          widget.onPageChanged(index);
        },
        itemBuilder: (context, index) {
          // Show "End of videos" screen for the last item (For You tab only)
          if (widget.showEndPage && index >= widget.videos.length) {
            return widget.buildEndOfVideosPage();
          }
          
          return widget.buildVideoItem(
            widget.videos[index],
            index,
            widget.tabIndex,
            _currentPageForTab,
            widget.isActiveTab,
          );
        },
      ),
    );
  }
}