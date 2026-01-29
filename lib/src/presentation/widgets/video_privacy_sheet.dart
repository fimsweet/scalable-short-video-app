import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

class VideoPrivacySheet extends StatefulWidget {
  final String videoId;
  final String userId;
  final String currentVisibility; // 'public', 'friends', 'private'
  final bool allowComments;
  final bool allowDuet;
  final Function(String visibility, bool allowComments, bool allowDuet)? onChanged;

  const VideoPrivacySheet({
    super.key,
    required this.videoId,
    required this.userId,
    this.currentVisibility = 'public',
    this.allowComments = true,
    this.allowDuet = true,
    this.onChanged,
  });

  @override
  State<VideoPrivacySheet> createState() => _VideoPrivacySheetState();
}

class _VideoPrivacySheetState extends State<VideoPrivacySheet> {
  final VideoService _videoService = VideoService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  
  late String _selectedVisibility;
  late bool _allowComments;
  late bool _allowDuet;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _selectedVisibility = widget.currentVisibility;
    _allowComments = widget.allowComments;
    _allowDuet = widget.allowDuet;
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

  Future<void> _updatePrivacy() async {
    if (_isUpdating) return;
    
    setState(() => _isUpdating = true);
    
    try {
      await _videoService.updateVideoPrivacy(
        videoId: widget.videoId,
        userId: widget.userId,
        visibility: _selectedVisibility,
        allowComments: _allowComments,
        allowDuet: _allowDuet,
      );
      
      widget.onChanged?.call(_selectedVisibility, _allowComments, _allowDuet);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localeService.isVietnamese 
                ? 'Đã cập nhật quyền riêng tư' 
                : 'Privacy updated'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localeService.get('error_occurred')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
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
                    _localeService.isVietnamese ? 'Cài đặt quyền riêng tư' : 'Privacy Settings',
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
            
            Divider(color: _themeService.dividerColor, height: 1),
            
            // Visibility section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _localeService.isVietnamese ? 'Ai có thể xem bài đăng này' : 'Who can view this post',
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Public option
                  _buildVisibilityOption(
                    value: 'public',
                    label: _localeService.isVietnamese ? 'Mọi người' : 'Everyone',
                  ),
                  
                  // Friends option
                  _buildVisibilityOption(
                    value: 'friends',
                    label: _localeService.isVietnamese ? 'Bạn bè' : 'Friends',
                    subtitle: _localeService.isVietnamese 
                        ? 'Những follower mà bạn follow lại' 
                        : 'Followers you follow back',
                  ),
                  
                  // Private option
                  _buildVisibilityOption(
                    value: 'private',
                    label: _localeService.isVietnamese ? 'Chỉ bạn' : 'Only you',
                  ),
                ],
              ),
            ),
            
            Divider(color: _themeService.dividerColor, height: 1),
            
            // Toggle options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Allow comments toggle
                  _buildToggleOption(
                    label: _localeService.isVietnamese ? 'Cho phép bình luận' : 'Allow comments',
                    value: _allowComments,
                    onChanged: (v) => setState(() => _allowComments = v),
                  ),
                  
                  // Allow duet/stitch toggle
                  _buildToggleOption(
                    label: _localeService.isVietnamese 
                        ? 'Cho phép sử dụng lại nội dung' 
                        : 'Allow reuse content',
                    subtitle: _localeService.isVietnamese 
                        ? 'Duet, Ghép nối, nhãn dán và thêm vào Nhật ký' 
                        : 'Duet, Stitch, stickers and add to diary',
                    value: _allowDuet,
                    onChanged: (v) => setState(() => _allowDuet = v),
                  ),
                ],
              ),
            ),
            
            // Save button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUpdating ? null : _updatePrivacy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2D55),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _localeService.isVietnamese ? 'Lưu' : 'Save',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityOption({
    required String value,
    required String label,
    String? subtitle,
  }) {
    final isSelected = _selectedVisibility == value;
    
    return InkWell(
      onTap: () => setState(() => _selectedVisibility = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: _themeService.textSecondaryColor,
                              fontSize: 13,
                            ),
                          ),
                          if (value == 'friends')
                            Icon(
                              Icons.chevron_right,
                              color: _themeService.textSecondaryColor,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFFF2D55) : _themeService.textSecondaryColor,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFF2D55),
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _themeService.textPrimaryColor,
                    fontSize: 15,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF6AD4DD),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: _themeService.textSecondaryColor.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}
