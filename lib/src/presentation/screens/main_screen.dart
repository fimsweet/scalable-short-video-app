import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/screens/profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/upload_video_screen.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/login_required_dialog.dart'; // ADD THIS

// Global key to access MainScreen state
final GlobalKey<_MainScreenState> mainScreenKey = GlobalKey<_MainScreenState>();

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  
  // Key to force rebuild screens when auth state changes
  int _rebuildKey = 0;
  
  // Key to access VideoScreen state for pausing/resuming videos
  final GlobalKey<VideoScreenState> _videoScreenKey = GlobalKey<VideoScreenState>();

  // Public method to switch to profile tab
  void switchToProfileTab() {
    setState(() {
      _selectedIndex = 1; // Profile tab index
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    
    // Listen to auth events using the same method
    _authService.addLogoutListener(_onAuthStateChanged);
    _authService.addLoginListener(_onAuthStateChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    // Remove listeners using the same method reference
    _authService.removeLogoutListener(_onAuthStateChanged);
    _authService.removeLoginListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onLocaleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onAuthStateChanged() {
    print('🔔 MainScreen: Auth state changed - forcing rebuild');
    print('   isLoggedIn: ${_authService.isLoggedIn}');
    
    // Force rebuild all screens by changing the key
    if (mounted) {
      setState(() {
        _rebuildKey++;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Remove force refresh - let each screen handle its own state
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        key: ValueKey('main_stack_$_rebuildKey'), // Force rebuild when key changes
        index: _selectedIndex,
        children: [
          VideoScreen(key: _videoScreenKey),
          ProfileScreen(key: ValueKey('profile_screen_$_rebuildKey')),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: _selectedIndex == 1 && _themeService.isLightMode
            ? BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[400]!, width: 1),
                ),
              )
            : null,
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: _localeService.get('home'),
              ),
              BottomNavigationBarItem(
                icon: Container(
                  width: 48,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _selectedIndex == 0 ? Colors.white : (_themeService.isLightMode ? Colors.black : Colors.white),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _selectedIndex == 0 ? Colors.black : (_themeService.isLightMode ? Colors.black : Colors.black), width: 1),
                  ),
                  child: Icon(
                    Icons.add,
                    color: _selectedIndex == 0 ? Colors.black : (_themeService.isLightMode ? Colors.white : Colors.black),
                    size: 24,
                  ),
                ),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: _localeService.get('profile'),
              ),
            ],
            currentIndex: _selectedIndex == 0 ? 0 : 2,
            selectedItemColor: _selectedIndex == 0 ? Colors.white : (_themeService.isLightMode ? Colors.black : Colors.white),
            unselectedItemColor: _selectedIndex == 0 ? Colors.grey : _themeService.textSecondaryColor,
            onTap: (index) {
              if (index == 1) {
                _navigateToUpload();
              } else if (index == 2) {
                // Switching to Profile tab - pause video
                _videoScreenKey.currentState?.onTabInvisible();
                setState(() => _selectedIndex = 1);
              } else {
                // Switching to Feed tab - resume video
                final wasOnProfile = _selectedIndex == 1;
                setState(() => _selectedIndex = 0);
                if (wasOnProfile) {
                  _videoScreenKey.currentState?.onTabVisible();
                }
              }
            },
            backgroundColor: _selectedIndex == 0 ? Colors.black : (_themeService.isLightMode ? Colors.white : Colors.black),
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            enableFeedback: false,
          ),
        ),
      ),
    );
  }

  void _navigateToUpload() async {
    if (!_authService.isLoggedIn) {
      LoginRequiredDialog.show(context, 'post');
      return;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UploadVideoScreen()),
    );

    if (result == true) {
      setState(() {
        _rebuildKey++;
        _selectedIndex = 1;
      });
    }
  }
}
