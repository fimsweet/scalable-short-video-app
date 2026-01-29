import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';

class MessageService {
  static final MessageService _instance = MessageService._internal();
  factory MessageService() => _instance;
  MessageService._internal();

  String get _baseUrl => AppConfig.videoServiceUrl;

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

    _socket?.disconnect();
    _socket?.dispose();
    
    _currentUserId = userId;
    
    print('🔌 Connecting to WebSocket at $_baseUrl/chat as user $userId...');

    _socket = IO.io(
      '$_baseUrl/chat',
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
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

    _socket!.on('newMessage', (data) {
      print('📩 New message received: $data');
      if (data != null) {
        _newMessageController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('messageSent', (data) {
      print('✅ Message sent confirmation: $data');
      if (data != null) {
        _messageSentController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('messagesRead', (data) {
      print('👁️ Messages read: $data');
      if (data != null) {
        _messagesReadController.add(Map<String, dynamic>.from(data));
      }
    });

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

  /// Upload image for chat message
  Future<String?> uploadImage(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final filename = image.name.isNotEmpty 
          ? image.name 
          : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Determine mime type
      String mimeType = 'image/jpeg';
      final ext = filename.toLowerCase().split('.').last;
      switch (ext) {
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        case 'jpg':
        case 'jpeg':
        default:
          mimeType = 'image/jpeg';
      }
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/messages/upload-image'),
      );
      
      // Add file with proper content type
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ));
      
      print('📤 Uploading chat image: $filename (${bytes.length} bytes, $mimeType)');
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      print('📥 Upload response: ${response.statusCode} - $responseBody');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(responseBody);
        if (data['success'] == true) {
          return data['imageUrl'] as String?;
        }
      }
      
      print('❌ Upload failed with status: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Error uploading image: $e');
      return null;
    }
  }

  void dispose() {
    disconnect();
    _newMessageController.close();
    _messageSentController.close();
    _messagesReadController.close();
    _userTypingController.close();
  }

  // Get conversation settings (mute, pin, theme, nickname)
  Future<Map<String, dynamic>> getConversationSettings(String recipientId) async {
    try {
      final currentUserId = _currentUserId ?? '';
      final response = await http.get(
        Uri.parse('$_baseUrl/messages/settings/$recipientId?userId=$currentUserId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      
      // Return defaults if not found
      return {
        'isMuted': false,
        'isPinned': false,
        'themeColor': null,
        'nickname': null,
      };
    } catch (e) {
      print('Error getting conversation settings: $e');
      return {
        'isMuted': false,
        'isPinned': false,
        'themeColor': null,
        'nickname': null,
      };
    }
  }

  // Update conversation settings
  Future<bool> updateConversationSettings(
    String recipientId, {
    bool? isMuted,
    bool? isPinned,
    String? themeColor,
    String? nickname,
  }) async {
    try {
      final currentUserId = _currentUserId ?? '';
      final body = <String, dynamic>{};
      if (isMuted != null) body['isMuted'] = isMuted;
      if (isPinned != null) body['isPinned'] = isPinned;
      if (themeColor != null) body['themeColor'] = themeColor;
      if (nickname != null) body['nickname'] = nickname;

      final response = await http.put(
        Uri.parse('$_baseUrl/messages/settings/$recipientId?userId=$currentUserId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating conversation settings: $e');
      return false;
    }
  }

  // ========== PINNED MESSAGES ==========

  Future<bool> pinMessage(String messageId) async {
    try {
      final currentUserId = _currentUserId ?? '';
      final response = await http.post(
        Uri.parse('$_baseUrl/messages/pin/$messageId?userId=$currentUserId'),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error pinning message: $e');
      return false;
    }
  }

  Future<bool> unpinMessage(String messageId) async {
    try {
      final currentUserId = _currentUserId ?? '';
      final response = await http.post(
        Uri.parse('$_baseUrl/messages/unpin/$messageId?userId=$currentUserId'),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error unpinning message: $e');
      return false;
    }
  }

  Future<List<dynamic>> getPinnedMessages(String recipientId) async {
    try {
      final currentUserId = _currentUserId ?? '';
      final response = await http.get(
        Uri.parse('$_baseUrl/messages/pinned/$currentUserId/$recipientId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      print('Error getting pinned messages: $e');
      return [];
    }
  }

  // ========== SEARCH MESSAGES ==========

  Future<List<dynamic>> searchMessages(String recipientId, String query, {int limit = 50}) async {
    try {
      final currentUserId = _currentUserId ?? '';
      final response = await http.get(
        Uri.parse('$_baseUrl/messages/search/$currentUserId/$recipientId?query=${Uri.encodeComponent(query)}&limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      print('Error searching messages: $e');
      return [];
    }
  }

  // ========== MEDIA MESSAGES ==========

  Future<List<dynamic>> getMediaMessages(String recipientId, {int limit = 50, int offset = 0}) async {
    try {
      final currentUserId = _currentUserId ?? '';
      final response = await http.get(
        Uri.parse('$_baseUrl/messages/media/$currentUserId/$recipientId?limit=$limit&offset=$offset'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      print('Error getting media messages: $e');
      return [];
    }
  }
}
