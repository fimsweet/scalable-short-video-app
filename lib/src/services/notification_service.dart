import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  String get _baseUrl => AppConfig.videoServiceUrl;
  
  Timer? _pollTimer;
  final StreamController<int> _unreadCountController = StreamController<int>.broadcast();
  
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  Future<List<dynamic>> getNotifications(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/notifications/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      print('Error getting notifications: $e');
      return [];
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/notifications/unread/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  Future<bool> markAsRead(String notificationId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/notifications/read/$notificationId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/notifications/read-all/$userId'),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error marking all as read: $e');
      return false;
    }
  }

  Future<bool> deleteNotification(String notificationId, String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/notifications/$notificationId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting notification: $e');
      return false;
    }
  }

  void startPolling(String userId, {Duration interval = const Duration(seconds: 10)}) {
    stopPolling();
    
    _pollTimer = Timer.periodic(interval, (timer) async {
      final count = await getUnreadCount(userId);
      _unreadCountController.add(count);
    });

    getUnreadCount(userId).then((count) => _unreadCountController.add(count));
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void dispose() {
    stopPolling();
    _unreadCountController.close();
  }
}
