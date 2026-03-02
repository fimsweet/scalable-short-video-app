import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Video Prefetch Service
/// Pre-downloads HLS manifests and first segments for smooth playback.
/// 
/// Since we use only 1 VideoPlayerController at a time (to avoid MediaCodec
/// decoder exhaustion), this service warms the HTTP/CDN cache by downloading
/// the HLS manifest (.m3u8) and the first video segment of upcoming videos.
/// When the player switches to the next video, the data is already cached
/// at the HTTP level, so initialization is much faster.
/// 
/// Strategy:
/// - Prefetch next 2 videos' HLS manifests (GET, not HEAD)
/// - Prefetch thumbnails for adjacent videos (shown as placeholders)
/// - Download first ~1MB of each upcoming video's first HLS segment
class VideoPrefetchService extends ChangeNotifier {
  static final VideoPrefetchService _instance = VideoPrefetchService._internal();
  factory VideoPrefetchService() => _instance;
  VideoPrefetchService._internal();

  // Cache for prefetched video URLs
  final LinkedHashMap<String, bool> _prefetchedUrls = LinkedHashMap();
  
  // Maximum cache size
  static const int _maxCacheSize = 30;
  
  // Number of videos to prefetch ahead
  static const int _prefetchCount = 2;
  
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
      
      // Prefetch HLS manifest (GET request — actually downloads the .m3u8)
      // This warms the HTTP cache so VideoPlayerController.initialize() is faster
      if (hlsUrl != null && hlsUrl.isNotEmpty) {
        _prefetchHlsManifest(_buildFullUrl(hlsUrl));
      }
      
      // Prefetch thumbnail (shown as placeholder on adjacent videos)
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        _prefetchUrl(_buildFullUrl(thumbnailUrl));
      }
    }
    
    // Clean old cache entries if needed
    _cleanCache();
  }

  /// Prefetch HLS manifest with GET request to actually cache the data.
  /// Also parses the manifest to prefetch the first video segment.
  Future<void> _prefetchHlsManifest(String url) async {
    if (_prefetchedUrls.containsKey(url) || _prefetchingUrls.contains(url)) {
      return;
    }
    
    _prefetchingUrls.add(url);
    
    try {
      // GET request to actually download and cache the manifest
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () => http.Response('', 408),
      );
      
      _prefetchedUrls[url] = response.statusCode == 200;
      
      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('[OK] Prefetched HLS manifest: ${url.split('/').last}');
        }
        
        // Parse manifest to find first segment and prefetch it
        final body = response.body;
        final lines = body.split('\n');
        
        // Find the first .ts segment or sub-playlist URL
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
          
          // Build absolute URL for the segment
          String segmentUrl;
          if (trimmed.startsWith('http')) {
            segmentUrl = trimmed;
          } else {
            // Relative URL — resolve against manifest base
            final baseUri = Uri.parse(url);
            final resolved = baseUri.resolve(trimmed);
            segmentUrl = resolved.toString();
          }
          
          // If this is a sub-playlist (.m3u8), prefetch it too
          if (trimmed.endsWith('.m3u8')) {
            _prefetchHlsManifest(segmentUrl);
          } else if (trimmed.endsWith('.ts') || trimmed.endsWith('.m4s')) {
            // Prefetch first segment only (warm the CDN cache)
            _prefetchUrl(segmentUrl);
          }
          break; // Only prefetch the first segment/sub-playlist
        }
      }
    } catch (e) {
      _prefetchedUrls[url] = false;
    } finally {
      _prefetchingUrls.remove(url);
    }
  }

  /// Prefetch a URL with GET request to cache the response data
  Future<void> _prefetchUrl(String url) async {
    // Skip if already prefetched or prefetching
    if (_prefetchedUrls.containsKey(url) || _prefetchingUrls.contains(url)) {
      return;
    }
    
    _prefetchingUrls.add(url);
    
    try {
      // GET request to actually download data into HTTP cache
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () => http.Response('', 408),
      );
      
      _prefetchedUrls[url] = response.statusCode == 200;
      
      if (kDebugMode && response.statusCode == 200) {
        print('[OK] Prefetched: ${url.split('/').last}');
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
