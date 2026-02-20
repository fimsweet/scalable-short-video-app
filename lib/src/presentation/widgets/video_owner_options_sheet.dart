import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_privacy_sheet.dart';

class VideoOwnerOptionsSheet extends StatefulWidget {
  final String videoId;
  final String userId;
  final String? title;
  final String? description;
  final String visibility;
  final bool allowComments;
  final bool allowDuet;
  final bool isHidden;
  final VoidCallback? onDeleted;
  final Function(bool)? onHiddenChanged;
  final Function(String, bool, bool)? onPrivacyChanged;
  final Function(String?, String?)? onEdited;

  const VideoOwnerOptionsSheet({
    super.key,
    required this.videoId,
    required this.userId,
    this.title,
    this.description,
    this.visibility = 'public',
    this.allowComments = true,
    this.allowDuet = true,
    this.isHidden = false,
    this.onDeleted,
    this.onHiddenChanged,
    this.onPrivacyChanged,
    this.onEdited,
  });

  @override
  State<VideoOwnerOptionsSheet> createState() => _VideoOwnerOptionsSheetState();
}

class _VideoOwnerOptionsSheetState extends State<VideoOwnerOptionsSheet> {
  final VideoService _videoService = VideoService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _showEditDialog() {
    final titleController = TextEditingController(text: widget.title ?? '');
    final descController = TextEditingController(text: widget.description ?? '');
    
    Navigator.pop(context); // Close options sheet first
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _localeService.isVietnamese ? 'Chỉnh sửa bài đăng' : 'Edit Post',
          style: TextStyle(color: _themeService.textPrimaryColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: TextStyle(color: _themeService.textPrimaryColor),
              decoration: InputDecoration(
                labelText: _localeService.isVietnamese ? 'Tiêu đề' : 'Title',
                labelStyle: TextStyle(color: _themeService.textSecondaryColor),
                filled: true,
                fillColor: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              style: TextStyle(color: _themeService.textPrimaryColor),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _localeService.isVietnamese ? 'Mô tả' : 'Description',
                labelStyle: TextStyle(color: _themeService.textSecondaryColor),
                filled: true,
                fillColor: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _localeService.get('cancel'),
              style: TextStyle(color: _themeService.textSecondaryColor),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _videoService.editVideo(
                  videoId: widget.videoId,
                  userId: widget.userId,
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                );
                widget.onEdited?.call(titleController.text.trim(), descController.text.trim());
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_localeService.get('error_occurred')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              _localeService.isVietnamese ? 'Lưu' : 'Save',
              style: const TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacySheet() {
    Navigator.pop(context); // Close options sheet first
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => VideoPrivacySheet(
        videoId: widget.videoId,
        userId: widget.userId,
        // When hidden, force 'private' to stay consistent with TikTok behavior
        currentVisibility: widget.isHidden ? 'private' : widget.visibility,
        allowComments: widget.isHidden ? false : widget.allowComments,
        allowDuet: widget.allowDuet,
        isHidden: widget.isHidden,
        onChanged: widget.onPrivacyChanged,
      ),
    );
  }

  void _showDeleteConfirmation() {
    Navigator.pop(context); // Close options sheet first
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _localeService.isVietnamese ? 'Xóa video?' : 'Delete video?',
          style: TextStyle(color: _themeService.textPrimaryColor),
        ),
        content: Text(
          _localeService.isVietnamese 
              ? 'Video sẽ bị xóa vĩnh viễn và không thể khôi phục.' 
              : 'This video will be permanently deleted and cannot be recovered.',
          style: TextStyle(color: _themeService.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _localeService.get('cancel'),
              style: TextStyle(color: _themeService.textSecondaryColor),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _videoService.deleteVideo(widget.videoId, widget.userId);
                widget.onDeleted?.call();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_localeService.get('error_occurred')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              _localeService.isVietnamese ? 'Xóa' : 'Delete',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showFeatureComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_localeService.isVietnamese ? 'Tính năng sắp ra mắt' : 'Feature coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _themeService.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  Text(
                    _localeService.isVietnamese ? 'Thêm' : 'More',
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: _themeService.iconColor),
                  ),
                ],
              ),
            ),
            
            // Options grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Wrap(
                spacing: 24,
                runSpacing: 20,
                alignment: WrapAlignment.start,
                children: [
                  // Duet
                  _buildOptionItem(
                    icon: Icons.people_outline,
                    label: 'Duet',
                    onTap: _showFeatureComingSoon,
                  ),
                  
                  // Stitch (Ghép nối)
                  _buildOptionItem(
                    icon: Icons.content_cut_outlined,
                    label: _localeService.isVietnamese ? 'Ghép nối' : 'Stitch',
                    onTap: _showFeatureComingSoon,
                  ),
                  
                  // Edit post
                  _buildOptionItem(
                    icon: Icons.edit_outlined,
                    label: _localeService.isVietnamese ? 'Chỉnh sửa\nbài đăng' : 'Edit\npost',
                    onTap: _showEditDialog,
                  ),
                  
                  // Privacy settings
                  _buildOptionItem(
                    icon: Icons.lock_outline,
                    label: _localeService.isVietnamese ? 'Cài đặt\nquyền riêng tư' : 'Privacy\nsettings',
                    onTap: _showPrivacySheet,
                  ),
                  
                  // Ad settings (coming soon)
                  _buildOptionItem(
                    icon: Icons.stars_outlined,
                    label: _localeService.isVietnamese ? 'Cài đặt\nquảng cáo' : 'Ad\nsettings',
                    onTap: _showFeatureComingSoon,
                  ),
                  
                  // Delete
                  _buildOptionItem(
                    icon: Icons.delete_outline,
                    label: _localeService.isVietnamese ? 'Xóa' : 'Delete',
                    onTap: _showDeleteConfirmation,
                    isDestructive: true,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _themeService.isLightMode ? Colors.grey[200] : Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDestructive 
                    ? Colors.red 
                    : _themeService.textPrimaryColor,
                size: 26,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDestructive 
                    ? Colors.red 
                    : _themeService.textPrimaryColor,
                fontSize: 12,
                height: 1.2,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
