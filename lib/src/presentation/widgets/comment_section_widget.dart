import 'package:flutter/material.dart';

class CommentSectionWidget extends StatelessWidget {
  final ScrollController controller;
  const CommentSectionWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 26, 26, 26),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40), // For spacing
                const Text(
                  '83 bình luận',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.grey, height: 1),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: const [
                _CommentItem(
                  username: 'lamborchibi',
                  comment:
                      'cheetah này là hiền nhất trong họ báo rồi. giá mà đc nuôi bọn này',
                  time: '5 ngày',
                  likes: '188',
                ),
                _CommentItem(
                  username: 'Astrophile',
                  comment: 'Báo săn là mèo nhỏ thôi',
                  time: '5 ngày',
                  likes: '18',
                ),
                _CommentItem(
                  username: 'PTD lab',
                  comment: 'báo kiểu: chỉ là con khỉ ko lông thôi mat',
                  time: '5 ngày',
                  likes: '566',
                ),
                _CommentItem(
                  username: 'PHAT',
                  comment: 'nhưng đừng nhầm nó với hoa mai nhé:)))',
                  time: '3 ngày',
                  likes: '5',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.grey),
          Container(
            color: const Color.fromARGB(255, 26, 26, 26),
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Thêm bình luận...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.gif_box_outlined,
                                color: Colors.grey[400]),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: Icon(Icons.emoji_emotions_outlined,
                                color: Colors.grey[400]),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: Icon(Icons.alternate_email,
                                color: Colors.grey[400]),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  final String username;
  final String comment;
  final String time;
  final String likes;

  const _CommentItem({
    required this.username,
    required this.comment,
    required this.time,
    required this.likes,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Trả lời',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Icon(Icons.favorite_border, size: 18, color: Colors.white),
              const SizedBox(height: 4),
              Text(
                likes,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
