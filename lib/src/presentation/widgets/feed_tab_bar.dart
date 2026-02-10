import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

class FeedTabBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChanged;
  final VoidCallback? onSearchTap;
  final bool hasNewFollowing;
  final bool hasNewFriends;

  const FeedTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
    this.onSearchTap,
    this.hasNewFollowing = false,
    this.hasNewFriends = false,
  });

  @override
  Widget build(BuildContext context) {
    final localeService = LocaleService();
    
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        height: 40,
        child: Row(
          children: [
            const SizedBox(width: 12),
            // Tabs - 3 tabs side by side
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTab(localeService.get('following_tab'), 0, hasNew: hasNewFollowing),
                  const SizedBox(width: 20),
                  _buildTab(localeService.get('friends_tab'), 1, hasNew: hasNewFriends),
                  const SizedBox(width: 20),
                  _buildTab(localeService.get('for_you_tab'), 2),
                ],
              ),
            ),
            // Search icon on the RIGHT - use Material for proper tap on web
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSearchTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 24,
                    shadows: [
                      Shadow(
                        blurRadius: 12.0,
                        color: Colors.black87,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String title, int index, {bool hasNew = false}) {
    final isSelected = selectedIndex == index;
    
    return GestureDetector(
      onTap: () => onTabChanged(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    shadows: const [
                      Shadow(
                        blurRadius: 12.0,
                        color: Colors.black87,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                // Red dot indicator for new content
                if (hasNew && !isSelected)
                  Positioned(
                    right: -6,
                    top: -2,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B5C),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x80FF3B5C),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 20 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1.5),
                boxShadow: isSelected ? [
                  const BoxShadow(
                    color: Colors.white30,
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ] : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
