import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Video Prefetch Service
/// Preloads video data and thumbnails for smooth playback like TikTok
/// 
/// Strategy:
/// - Prefetch next 3 videos when user is watching current video
/// - Cache video metadata and thumbnails
/// - Preconnect to CDN for faster HLS segment loading
class VideoPrefetchService extends ChangeNotifier {
  static final VideoPrefetchService _instance = VideoPrefetchService._internal();
  factory VideoPrefetchService() => _instance;
  VideoPrefetchService._internal();

  // Cache for prefetched video URLs (to verify they're reachable)
  final LinkedHashMap<String, bool> _prefetchedUrls = LinkedHashMap();
  
  // Maximum cache size
  static const int _maxCacheSize = 20;
  
  // Number of videos to prefetch ahead
  static const int _prefetchCount = 3;
  
  // Track current prefetch operations
  final Set<String> _prefetchingUrls = {};

  /// Prefetch videos around the current index
  /// Call this when user scrolls to a new video
  Future<void> prefetchVideosAround(List<dynamic> videos, int currentIndex) async {
    if (videos.isEmpty) return;
    
    // Prefetch next N videos
    final endIndex = (currentIndex + _prefetchCount + 1).clamp(0, videos.length);
    
    for (int i = currentIndex + 1; i < endIndex; i++) {
      final video = videos[i];
      if (video == null) continue;
      
      final hlsUrl = video['hlsUrl']?.toString();
      final thumbnailUrl = video['thumbnailUrl']?.toString();
      
      // Prefetch HLS playlist (triggers CDN caching)
      if (hlsUrl != null && hlsUrl.isNotEmpty) {
        _prefetchUrl(_buildFullUrl(hlsUrl));
      }
      
      // Prefetch thumbnail
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        _prefetchUrl(_buildFullUrl(thumbnailUrl));
      }
    }
    
    // Clean old cache entries if needed
    _cleanCache();
  }

  /// Prefetch a specific video URL
  Future<void> _prefetchUrl(String url) async {
    // Skip if already prefetched or prefetching
    if (_prefetchedUrls.containsKey(url) || _prefetchingUrls.contains(url)) {
      return;
    }
    
    _prefetchingUrls.add(url);
    
    try {
      // HEAD request to trigger CDN caching without downloading full content
      final response = await http.head(
        Uri.parse(url),
        headers: {
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('', 408),
      );
      
      _prefetchedUrls[url] = response.statusCode == 200;
      
      if (kDebugMode && response.statusCode == 200) {
        print('✅ Prefetched: ${url.split('/').last}');
      }
    } catch (e) {
      // Silent fail - prefetching is best effort
      _prefetchedUrls[url] = false;
    } finally {
      _prefetchingUrls.remove(url);
    }
  }

  /// Build full URL from relative path
  String _buildFullUrl(String path) {
    if (path.startsWith('http')) return path;
    
    // Use CloudFront URL if available, otherwise video service
    final baseUrl = AppConfig.cloudFrontUrl ?? AppConfig.videoServiceUrl;
    return '$baseUrl$path';
  }

  /// Check if URL was prefetched successfully
  bool isPrefetched(String url) {
    final fullUrl = _buildFullUrl(url);
    return _prefetchedUrls[fullUrl] == true;
  }

  /// Clean old cache entries
  void _cleanCache() {
    while (_prefetchedUrls.length > _maxCacheSize) {
      _prefetchedUrls.remove(_prefetchedUrls.keys.first);
    }
  }

  /// Clear all prefetch cache
  void clearCache() {
    _prefetchedUrls.clear();
    _prefetchingUrls.clear();
  }

  /// Get prefetch statistics
  Map<String, dynamic> getStats() {
    return {
      'cachedUrls': _prefetchedUrls.length,
      'pendingPrefetch': _prefetchingUrls.length,
      'successRate': _prefetchedUrls.isEmpty 
          ? 0.0 
          : _prefetchedUrls.values.where((v) => v).length / _prefetchedUrls.length,
    };
  }
}
