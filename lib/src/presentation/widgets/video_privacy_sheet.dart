import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/app_snackbar.dart';

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

  bool get _hasChanges =>
      _selectedVisibility != widget.currentVisibility ||
      _allowComments != widget.allowComments ||
      _allowDuet != widget.allowDuet;

  Future<void> _handleDismiss() async {
    if (_hasChanges) {
      final result = await _showUnsavedChangesDialog();
      if (result == 'save') {
        await _updatePrivacy();
      } else if (result == 'discard') {
        if (mounted) Navigator.pop(context);
      }
      // result == null means user tapped outside dialog or cancelled → stay
    } else {
      Navigator.pop(context);
    }
  }

  Future<String?> _showUnsavedChangesDialog() {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2D55).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFF2D55),
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _localeService.isVietnamese
                    ? 'Thay đổi chưa được lưu'
                    : 'Unsaved Changes',
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _localeService.isVietnamese
                    ? 'Bạn có muốn lưu thay đổi trước khi thoát không?'
                    : 'Do you want to save your changes before leaving?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, 'save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2D55),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _localeService.isVietnamese ? 'Lưu thay đổi' : 'Save Changes',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Discard button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, 'discard'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _localeService.isVietnamese ? 'Hủy thay đổi' : 'Discard',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _themeService.textSecondaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        AppSnackBar.showSuccess(
          context,
          _localeService.isVietnamese 
              ? 'Đã cập nhật quyền riêng tư' 
              : 'Privacy updated',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, _localeService.get('error_occurred'));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleDismiss();
        }
      },
      child: Container(
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
                    onTap: _handleDismiss,
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
            activeTrackColor: const Color(0xFF34C759),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: _themeService.switchInactiveTrackColor,
          ),
        ],
      ),
    );
  }
}
