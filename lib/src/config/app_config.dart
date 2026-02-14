import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// Environment configuration for the app
/// 
/// SWITCH ENVIRONMENT:
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
  // MANUAL OVERRIDE - Set to true to test production URLs in debug mode
  // ============================================
  static const bool _forceProduction = false;

  // ============================================
  // ENVIRONMENT DETECTION
  // ============================================
  static bool get isProduction => _forceProduction || kReleaseMode;

  // ============================================
  //  PRODUCTION URLs (AWS EC2) - THESIS DEPLOYMENT
  // ============================================
  // EC2 Elastic IP: 18.138.223.226
  // API Gateway (Nginx): port 80 → routes to user-service & video-service
  // ============================================
  
  // API Gateway - single entry point (Nginx reverse proxy)
  static const String _prodApiGatewayUrl = 'http://18.138.223.226';
  
  // Both services go through the same gateway — Nginx routes by path prefix:
  //   /auth/*, /users/*, /follows/*, /sessions/*, /reports/*, /activity-history/* → user-service:3000
  //   /videos/*, /comments/*, /likes/*, /messages/*, /notifications/*, etc.    → video-service:3002
  static const String _prodUserServiceUrl = _prodApiGatewayUrl;
  static const String _prodVideoServiceUrl = _prodApiGatewayUrl;
  
  // CloudFront CDN for video/image delivery
  static const String? _prodCloudFrontUrl = 'https://d3ucy55nukq6p9.cloudfront.net';

  // ============================================
  // DEVELOPMENT URLs (Local)
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
  // GETTERS - Use these in services
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
      // WS through API Gateway (Nginx proxies /socket.io/ to video-service)
      return 'ws://18.138.223.226';
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
  // APP INFO
  // ============================================
  static const String appName = 'Short Video App';
  static const String appVersion = '1.0.0';

  // ============================================
  // TIMEOUTS
  // ============================================
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ============================================
  // DEBUG - Print config at startup
  // ============================================
  static void printConfig() {
    print('');
    print('');
    print(' APP CONFIGURATION             ║');
    print('');
    print('Environment: ${isProduction ? "PRODUCTION" : "DEVELOPMENT"}');
    print('Force Prod:  $_forceProduction');
    print('User API:    $userServiceUrl');
    print('Video API:   $videoServiceUrl');
    print('WebSocket:   $webSocketUrl');
    print('');
    print('');
  }
}
