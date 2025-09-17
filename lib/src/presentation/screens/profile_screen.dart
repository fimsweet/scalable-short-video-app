import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ten nguoi dung',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.keyboard_arrow_down),
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.alternate_email)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.add_box_outlined)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.menu)),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.grey,
                            // backgroundImage: NetworkImage('URL_TO_IMAGE'),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: const [
                                _ProfileStat(count: '0', label: 'bài viết'),
                                _ProfileStat(count: '24', label: 'người theo dõi'),
                                _ProfileStat(count: '34', label: 'đang theo dõi'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'User name',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(text: 'Chỉnh sửa'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ActionButton(text: 'Chia sẻ trang cá nhân'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: Column(
            children: [
              const TabBar(
                indicatorColor: Colors.white,
                tabs: [
                  Tab(icon: Icon(Icons.grid_on)),
                  Tab(icon: Icon(Icons.movie_creation_outlined)),
                  Tab(icon: Icon(Icons.person_pin_outlined)),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // Grid content
                    Container(),
                    // Videos content
                    const Center(child: Text('Videos')),
                    // Tagged content
                    const Center(child: Text('Tagged')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String count;
  final String label;
  const _ProfileStat({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  const _ActionButton({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold))),
    );
  }
}
