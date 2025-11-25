import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  // Mock data cho giao diện
  final List<Map<String, dynamic>> _conversations = [
    {
      'id': '1',
      'username': 'thanh_truong',
      'avatar': null,
      'lastMessage': 'Video hôm qua hay quá! 🔥',
      'time': '2p',
      'isRead': false,
    },
    {
      'id': '2',
      'username': 'minh_anh_99',
      'avatar': null,
      'lastMessage': 'Bạn đã gửi một video',
      'time': '1h',
      'isRead': true,
    },
    {
      'id': '3',
      'username': 'kols_vietnam',
      'avatar': null,
      'lastMessage': 'Chào bạn, mình muốn hợp tác...',
      'time': '1d',
      'isRead': false,
    },
    {
      'id': '4',
      'username': 'user_123456',
      'avatar': null,
      'lastMessage': 'Haha buồn cười quá 😂',
      'time': '3d',
      'isRead': true,
    },
  ];

  void _navigateToChat(Map<String, dynamic> conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          recipientId: conversation['id'],
          recipientUsername: conversation['username'],
          recipientAvatar: conversation['avatar'],
        ),
      ),
    ).then((_) {
      // Mark as read when returning
      setState(() {
        conversation['isRead'] = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Hộp thư',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: Colors.white, size: 24),
            onPressed: () {
              // TODO: New chat
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 15),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // Conversation List
          Expanded(
            child: _conversations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mail_outline,
                          size: 80,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Chưa có tin nhắn',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bắt đầu nhắn tin với bạn bè',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final chat = _conversations[index];
                      final isRead = chat['isRead'] as bool;

                      return InkWell(
                        onTap: () => _navigateToChat(chat),
                        highlightColor: Colors.grey[900],
                        splashColor: Colors.transparent,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              // Avatar with online indicator
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.grey[800],
                                    backgroundImage: chat['avatar'] != null
                                        ? NetworkImage(chat['avatar'])
                                        : null,
                                    child: chat['avatar'] == null
                                        ? const Icon(Icons.person, color: Colors.white, size: 28)
                                        : null,
                                  ),
                                  // Online indicator
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.black, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),

                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            chat['username'],
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          chat['time'],
                                          style: TextStyle(
                                            color: isRead ? Colors.grey[600] : Colors.blue,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            chat['lastMessage'],
                                            style: TextStyle(
                                              color: isRead ? Colors.grey[500] : Colors.white,
                                              fontSize: 14,
                                              fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // Unread indicator
                                        if (!isRead)
                                          Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              color: Colors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
