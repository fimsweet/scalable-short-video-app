import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';

class VideoMoreOptionsSheet extends StatelessWidget {
  final String videoId;
  final String userId;
  final bool isHidden;
  final VoidCallback? onEditTap;
  final VoidCallback? onPrivacyTap;
  final VoidCallback? onDeleteTap;
  final VoidCallback? onHideTap;

  const VideoMoreOptionsSheet({
    super.key,
    required this.videoId,
    required this.userId,
    this.isHidden = false,
    this.onEditTap,
    this.onPrivacyTap,
    this.onDeleteTap,
    this.onHideTap,
  });

  @override
  Widget build(BuildContext context) {
    final localeService = LocaleService();
    final themeService = ThemeService();
    
    return Container(
      decoration: BoxDecoration(
        color: themeService.isLightMode 
            ? themeService.backgroundColor 
            : const Color(0xFF2B2B2B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title with close button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40), // Spacer for centering
                Text(
                  localeService.isVietnamese ? 'Thêm' : 'More',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: themeService.textPrimaryColor,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close,
                      color: themeService.textPrimaryColor,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Options grid - TikTok style horizontal icons (only 4 options)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Edit post (Chỉnh sửa bài đăng)
                _buildOptionItem(
                  context: context,
                  icon: Icons.edit_outlined,
                  label: localeService.isVietnamese ? 'Chỉnh sửa\nbài đăng' : 'Edit\npost',
                  onTap: onEditTap,
                  themeService: themeService,
                ),
                
                // Privacy settings (Cài đặt quyền riêng tư)
                _buildOptionItem(
                  context: context,
                  icon: Icons.lock_outline,
                  label: localeService.isVietnamese ? 'Quyền\nriêng tư' : 'Privacy',
                  onTap: onPrivacyTap,
                  themeService: themeService,
                ),
                
                // Hide video (Ẩn video)
                _buildOptionItem(
                  context: context,
                  icon: isHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  label: isHidden 
                      ? (localeService.isVietnamese ? 'Hiện\nvideo' : 'Show\nvideo')
                      : (localeService.isVietnamese ? 'Ẩn\nvideo' : 'Hide\nvideo'),
                  onTap: onHideTap,
                  themeService: themeService,
                ),
                
                // Delete (Xóa)
                _buildOptionItem(
                  context: context,
                  icon: Icons.delete_outline,
                  label: localeService.isVietnamese ? 'Xóa' : 'Delete',
                  onTap: onDeleteTap,
                  themeService: themeService,
                  isDestructive: true,
                ),
              ],
            ),
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }

  Widget _buildOptionItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required ThemeService themeService,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap?.call();
      },
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circle icon container
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: themeService.isLightMode 
                    ? Colors.grey[200] 
                    : const Color(0xFF3A3A3A),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDestructive 
                    ? Colors.red 
                    : themeService.isLightMode 
                        ? themeService.textPrimaryColor
                        : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            // Label
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isDestructive 
                    ? Colors.red 
                    : themeService.isLightMode 
                        ? themeService.textPrimaryColor
                        : Colors.white,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
