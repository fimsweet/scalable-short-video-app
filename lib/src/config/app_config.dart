import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// Environment configuration for the app
/// 
/// HOW TO SWITCH ENVIRONMENT:
/// ================================
/// Option 1: Build Mode (Automatic)
///   - Debug mode (F5) → Development URLs
///   - Release mode (flutter build apk --release) → Production URLs
///
/// Option 2: Force Production in Debug (for testing)
///   - Set _forceProduction = true below
/// ================================
class AppConfig {
  // ============================================
  // 🔧 MANUAL OVERRIDE - Set to true to test production URLs in debug mode
  // ============================================
  static const bool _forceProduction = false;

  // ============================================
  // ENVIRONMENT DETECTION
  // ============================================
  static bool get isProduction => _forceProduction || kReleaseMode;

  // ============================================
  // 🌐 PRODUCTION URLs (AWS) - Update these before deploying
  // ============================================
  // Option 1: Single API Gateway (recommended)
  static const String _prodApiBaseUrl = 'https://api.your-domain.com';
  
  // CloudFront CDN for video/image delivery (optional but recommended)
  static const String? _prodCloudFrontUrl = null; // e.g., 'https://d123456.cloudfront.net'
  
  // All services behind API Gateway
  static String get _prodUserServiceUrl => _prodApiBaseUrl;
  static String get _prodVideoServiceUrl => _prodApiBaseUrl;

  // Option 2: Separate URLs (if not using API Gateway)
  // static const String _prodUserServiceUrl = 'https://user-api.your-domain.com';
  // static const String _prodVideoServiceUrl = 'https://video-api.your-domain.com';

  // ============================================
  // 🖥️ DEVELOPMENT URLs (Local)
  // ============================================
  static String get _devUserServiceUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    } else {
      return 'http://localhost:3000';
    }
  }

  static String get _devVideoServiceUrl {
    if (kIsWeb) {
      return 'http://localhost:3002';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3002';
    } else {
      return 'http://localhost:3002';
    }
  }

  // ============================================
  // 📍 GETTERS - Use these in services
  // ============================================
  
  /// User Service URL (auth, users, follow)
  static String get userServiceUrl {
    return isProduction ? _prodUserServiceUrl : _devUserServiceUrl;
  }

  /// Video Service URL (videos, comments, likes, chat)
  static String get videoServiceUrl {
    return isProduction ? _prodVideoServiceUrl : _devVideoServiceUrl;
  }

  /// WebSocket URL for real-time features
  static String get webSocketUrl {
    if (isProduction) {
      // WSS for production (secure)
      return _prodVideoServiceUrl.replaceFirst('https://', 'wss://');
    } else {
      // WS for development
      if (kIsWeb) {
        return 'ws://localhost:3002';
      } else if (Platform.isAndroid) {
        return 'ws://10.0.2.2:3002';
      } else {
        return 'ws://localhost:3002';
      }
    }
  }

  /// CloudFront CDN URL for video/image delivery (production only)
  /// Returns null in development (use videoServiceUrl instead)
  static String? get cloudFrontUrl {
    return isProduction ? _prodCloudFrontUrl : null;
  }

  // ============================================
  // 📱 APP INFO
  // ============================================
  static const String appName = 'Short Video App';
  static const String appVersion = '1.0.0';

  // ============================================
  // ⏱️ TIMEOUTS
  // ============================================
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ============================================
  // 🔍 DEBUG - Print config at startup
  // ============================================
  static void printConfig() {
    print('');
    print('');
    print(' APP CONFIGURATION             ║');
    print('');
    print('Environment: ${isProduction ? "🚀 PRODUCTION" : "🔧 DEVELOPMENT"}');
    print('Force Prod:  $_forceProduction');
    print('User API:    $userServiceUrl');
    print('Video API:   $videoServiceUrl');
    print('WebSocket:   $webSocketUrl');
    print('');
    print('');
  }
}
