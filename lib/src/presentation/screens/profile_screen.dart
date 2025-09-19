import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/screens/login_screen.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
        content: const Text('Bạn chắc chắn muốn đăng xuất?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              _authService.logout();
              Navigator.pop(context);
              setState(() {}); // Ở lại trang profile và cập nhật UI
            },
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _mockLogin() {
    _authService.login('ten nguoi dung');
    setState(() {});
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    ).then((result) {
      if (result == true) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = _authService.isLoggedIn;
    return loggedIn ? _buildLoggedIn() : _buildLoggedOut();
  }

  // Logged OUT view (giống TikTok hiển thị lời mời đăng nhập)
  Widget _buildLoggedOut() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Hồ sơ'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            color: Colors.grey[900],
            onSelected: (v) {
              if (v == 'login') _mockLogin();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'login',
                child: Row(children: [Icon(Icons.login, color: Colors.white), SizedBox(width: 12), Text('Đăng nhập', style: TextStyle(color: Colors.white))]),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline, size: 80, color: Colors.grey[700]),
              const SizedBox(height: 24),
              const Text('Đăng nhập để xem hồ sơ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                'Theo dõi người khác, thích video và tạo nội dung của riêng bạn.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 200,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, // Nút màu trắng
                    foregroundColor: Colors.black, // Chữ màu đen
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _navigateToLogin, // Dẫn tới màn hình đăng nhập
                  child: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Logged IN view
  Widget _buildLoggedIn() {
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
              Text(_authService.username ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Icon(Icons.keyboard_arrow_down),
              const SizedBox(width: 4),
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
            ],
          ),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.alternate_email)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.add_box_outlined)),
            PopupMenuButton<String>(
              icon: const Icon(Icons.menu),
              color: Colors.grey[900],
              onSelected: (v) {
                if (v == 'logout') _showLogoutDialog();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'settings',
                  child: Row(children: [Icon(Icons.settings, color: Colors.white), SizedBox(width: 12), Text('Cài đặt', style: TextStyle(color: Colors.white))]),
                ),
                PopupMenuItem(
                  value: 'help',
                  child: Row(children: [Icon(Icons.help, color: Colors.white), SizedBox(width: 12), Text('Trợ giúp', style: TextStyle(color: Colors.white))]),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(children: [Icon(Icons.logout, color: Colors.red), SizedBox(width: 12), Text('Đăng xuất', style: TextStyle(color: Colors.red))]),
                ),
              ],
            ),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(radius: 40, backgroundColor: Colors.grey),
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
                    Text(_authService.username ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Expanded(child: _ActionButton(text: 'Chỉnh sửa')),
                        SizedBox(width: 8),
                        Expanded(child: _ActionButton(text: 'Chia sẻ trang cá nhân')),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
          body: Column(
            children: const [
              TabBar(
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
                    SizedBox.shrink(),
                    Center(child: Text('Videos')),
                    Center(child: Text('Tagged')),
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
  Widget build(BuildContext context) => Column(
        children: [
          Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      );
}

class _ActionButton extends StatelessWidget {
  final String text;
  const _ActionButton({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold))),
      );
}
