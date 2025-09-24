import 'package:flutter/material.dart';

class ShareSheetWidget extends StatelessWidget {
  const ShareSheetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Text(
            'Chia sẻ đến',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.black.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: 15, // Mock user count
              itemBuilder: (context, index) {
                return _UserListItem(
                  username: 'nguoidung_${index + 1}',
                  fullName: 'Tên Người Dùng ${index + 1}',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserListItem extends StatelessWidget {
  final String username;
  final String fullName;

  const _UserListItem({required this.username, required this.fullName});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey,
        // backgroundImage: NetworkImage('...'),
      ),
      title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(fullName, style: TextStyle(color: Colors.grey[400])),
      trailing: ElevatedButton(
        onPressed: () {
          // Handle send action
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã gửi cho $username')),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text('Gửi'),
      ),
    );
  }
}
