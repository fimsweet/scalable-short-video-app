import 'package:flutter/material.dart';

class FollowerFollowingScreen extends StatelessWidget {
  final int initialIndex;
  const FollowerFollowingScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('user_demo'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Người theo dõi'),
              Tab(text: 'Đang theo dõi'),
              Tab(text: 'Bài viết'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _UserList(key: PageStorageKey('followers'), type: 'follower'),
            _UserList(key: PageStorageKey('following'), type: 'following'),
            _PostGrid(key: PageStorageKey('posts')),
          ],
        ),
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final String type;
  const _UserList({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    // Mock data
    final users = List.generate(
      20,
      (i) => 'Người dùng ${i + 1}',
    );

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.grey),
          title: Text(users[index]),
          subtitle: Text('@${users[index].toLowerCase().replaceAll(' ', '_')}'),
          trailing: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: type == 'follower' ? Colors.red : Colors.grey[800],
            ),
            child: Text(type == 'follower' ? 'Follow lại' : 'Hủy theo dõi'),
          ),
        );
      },
    );
  }
}

class _PostGrid extends StatelessWidget {
  const _PostGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 15, // Mock post count
      itemBuilder: (context, index) {
        return Container(
          color: Colors.grey[900],
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
        );
      },
    );
  }
}
