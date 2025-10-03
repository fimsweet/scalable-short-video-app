import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/screens/profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    VideoScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
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
              print('Add video tapped');
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
