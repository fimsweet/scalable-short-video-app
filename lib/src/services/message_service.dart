import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:socket_io_client/socket_io_client.dart' as IO;

class MessageService {
  static final MessageService _instance = MessageService._internal();
  factory MessageService() => _instance;
  MessageService._internal();

  String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3002';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3002';
    } else {
      return 'http://localhost:3002';
    }
  }

  IO.Socket? _socket;
  String? _currentUserId;
  
  // Stream controllers
  final StreamController<Map<String, dynamic>> _newMessageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageSentController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messagesReadController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _userTypingController = 
      StreamController<Map<String, dynamic>>.broadcast();

  // Streams
  Stream<Map<String, dynamic>> get newMessageStream => _newMessageController.stream;
  Stream<Map<String, dynamic>> get messageSentStream => _messageSentController.stream;
  Stream<Map<String, dynamic>> get messagesReadStream => _messagesReadController.stream;
  Stream<Map<String, dynamic>> get userTypingStream => _userTypingController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String userId) {
    if (_socket != null && _currentUserId == userId && _socket!.connected) {
      print('🔌 Already connected as user $userId');
      return;
    }

    // Disconnect existing socket if any
    _socket?.disconnect();
    _socket?.dispose();
    
    _currentUserId = userId;
    
    print('🔌 Connecting to WebSocket at $_baseUrl/chat as user $userId...');

    _socket = IO.io(
      '$_baseUrl/chat',
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling']) // Try websocket first, fallback to polling
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1000)
          .build(),
    );

    _socket!.onConnect((_) {
      print('✅ WebSocket connected successfully!');
      _socket!.emit('join', {'userId': userId});
    });

    _socket!.onDisconnect((reason) {
      print('❌ WebSocket disconnected: $reason');
    });

    _socket!.onConnectError((error) {
      print('❌ WebSocket connection error: $error');
    });

    _socket!.onError((error) {
      print('❌ WebSocket error: $error');
    });

    // Listen for new messages
    _socket!.on('newMessage', (data) {
      print('📩 New message received: $data');
      if (data != null) {
        _newMessageController.add(Map<String, dynamic>.from(data));
      }
    });

    // Listen for sent message confirmation
    _socket!.on('messageSent', (data) {
      print('✅ Message sent confirmation: $data');
      if (data != null) {
        _messageSentController.add(Map<String, dynamic>.from(data));
      }
    });

    // Listen for read receipts
    _socket!.on('messagesRead', (data) {
      print('👁️ Messages read: $data');
      if (data != null) {
        _messagesReadController.add(Map<String, dynamic>.from(data));
      }
    });

    // Listen for typing indicators
    _socket!.on('userTyping', (data) {
      if (data != null) {
        _userTypingController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.connect();
  }

  void disconnect() {
    print('🔌 Disconnecting WebSocket...');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _currentUserId = null;
  }

  void markAsRead(String conversationId) {
    if (_socket == null || _currentUserId == null) return;

    _socket!.emit('markAsRead', {
      'conversationId': conversationId,
      'userId': _currentUserId,
    });
  }

  void sendTypingIndicator(String recipientId, bool isTyping) {
    if (_socket == null || _currentUserId == null) return;

    _socket!.emit('typing', {
      'senderId': _currentUserId,
      'recipientId': recipientId,
      'isTyping': isTyping,
    });
  }

  // REST API methods
  Future<List<dynamic>> getMessages(String userId1, String userId2, {int limit = 50, int offset = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/messages/conversation/$userId1/$userId2?limit=$limit&offset=$offset'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      print('❌ Error getting messages: $e');
      return [];
    }
  }

  Future<List<dynamic>> getConversations(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/messages/conversations/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      print('❌ Error getting conversations: $e');
      return [];
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/messages/unread/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Send message - supports both WebSocket and REST API
  Future<Map<String, dynamic>> sendMessage({
    required String recipientId,
    required String content,
  }) async {
    final actualSenderId = _currentUserId ?? '';
    
    if (actualSenderId.isEmpty) {
      print('❌ Cannot send message: no sender ID');
      return {'success': false};
    }

    try {
      // Send via REST API only - server will handle WebSocket broadcast
      final response = await http.post(
        Uri.parse('$_baseUrl/messages/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'senderId': actualSenderId,
          'recipientId': recipientId,
          'content': content,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Message sent successfully');
        
        // Emit messageSent locally so UI can update temp message
        if (data['data'] != null) {
          _messageSentController.add(Map<String, dynamic>.from(data['data']));
        }
        
        return data;
      }
      return {'success': false};
    } catch (e) {
      print('❌ Error sending message: $e');
      return {'success': false};
    }
  }

  void dispose() {
    disconnect();
    _newMessageController.close();
    _messageSentController.close();
    _messagesReadController.close();
    _userTypingController.close();
  }
}
