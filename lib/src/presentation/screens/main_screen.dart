import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/screens/profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/upload_video_screen.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Listen to logout events
    _authService.addLogoutListener(_onLogout);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authService.removeLogoutListener(_onLogout);
    super.dispose();
  }

  void _onLogout() {
    print('🔔 Logout event received - refreshing all screens');
    // Only rebuild when logout
    setState(() {});
    
    // Switch to profile tab to show logged out state
    if (_selectedIndex != 1) {
      _onItemTapped(1);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Remove force refresh - let each screen handle its own state
  }

  List<Widget> get _widgetOptions => <Widget>[
    Visibility(
      visible: _selectedIndex == 0,
      maintainState: true, // CHANGED: Keep state when switching tabs
      child: const VideoScreen(),
    ),
    Visibility(
      visible: _selectedIndex == 1,
      maintainState: true,
      child: const ProfileScreen(),
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    print('📱 Switched to tab $index (isLoggedIn: ${_authService.isLoggedIn})');
  }

  void _navigateToUpload() async {
    // Check if user is logged in
    if (!_authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để upload video'),
          backgroundColor: Colors.red,
        ),
      );
      // Navigate to profile screen to login
      _onItemTapped(1);
      return;
    }

    // Navigate to upload screen
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UploadVideoScreen()),
    );

    // If upload successful, just rebuild to trigger reload in VideoScreen
    if (result == true) {
      setState(() {});
      // Switch to profile tab to show uploaded video
      _onItemTapped(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: _widgetOptions,
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            const BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Trang chủ',
            ),
            BottomNavigationBarItem(
              icon: Container(
                width: 48,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              label: '',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Hồ sơ',
            ),
          ],
          currentIndex: _selectedIndex == 0 ? 0 : 2,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
          onTap: (index) {
            if (index == 1) {
              // Handle add video tap
              _navigateToUpload();
            } else if (index == 2) {
              _onItemTapped(1); // Index for ProfileScreen in _widgetOptions
            } else {
              _onItemTapped(0); // Index for VideoScreen in _widgetOptions
            }
          },
          backgroundColor: Colors.black,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          enableFeedback: false, // Tắt haptic feedback
        ),
      ),
    );
  }
}
