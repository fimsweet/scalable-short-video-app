import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

class VideoManagementSheet extends StatefulWidget {
  final String videoId;
  final String userId;
  final bool isHidden;
  final VoidCallback onDeleted;
  final Function(bool) onHiddenChanged;

  const VideoManagementSheet({
    super.key,
    required this.videoId,
    required this.userId,
    required this.isHidden,
    required this.onDeleted,
    required this.onHiddenChanged,
  });

  @override
  State<VideoManagementSheet> createState() => _VideoManagementSheetState();
}

class _VideoManagementSheetState extends State<VideoManagementSheet> {
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _showSuccessDialog(BuildContext context, String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SafeArea(
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _themeService.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _themeService.textSecondaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Hide/Show option
            ListTile(
              leading: Icon(
                widget.isHidden ? Icons.visibility : Icons.visibility_off,
                color: _themeService.iconColor,
              ),
              title: Text(
                widget.isHidden ? _localeService.get('show_video') : _localeService.get('hide_video'),
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                widget.isHidden 
                    ? _localeService.get('video_visible_to_all') 
                    : _localeService.get('video_followers_only'),
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 13,
                ),
              ),
              onTap: () async {
                try {
                  final videoService = VideoService();
                  final result = await videoService.toggleHideVideo(widget.videoId, widget.userId);
                  final newHiddenStatus = result['isHidden'] ?? !widget.isHidden;
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    widget.onHiddenChanged(newHiddenStatus);
                    
                    final message = newHiddenStatus 
                        ? _localeService.get('video_now_followers') 
                        : _localeService.get('video_now_public');
                    _showSuccessDialog(context, message);
                  }
                } catch (e) {
                  if (context.mounted) {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SafeArea(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Lỗi: ${e.toString()}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                }
              },
            ),

            Divider(color: _themeService.dividerColor, height: 1),

            // Delete option
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              title: Text(
                _localeService.get('delete_video'),
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                _localeService.get('video_delete_permanent'),
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 13,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context);
              },
            ),

            const SizedBox(height: 8),

            // Cancel button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _localeService.get('cancel'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final videoService = VideoService();
    final themeService = ThemeService();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: themeService.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  _localeService.get('delete_video_title'),
                  style: TextStyle(
                    color: themeService.textPrimaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _localeService.get('delete_video_message'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: themeService.textSecondaryColor,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          backgroundColor: themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _localeService.get('cancel'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          print('DELETE BUTTON PRESSED');
                          print('   VideoId: ${widget.videoId}');
                          print('   UserId: ${widget.userId}');
                          
                          // Get root navigator to pop all overlays
                          final rootNavigator = Navigator.of(context, rootNavigator: true);
                          
                          try {
                            print('   Step 1: Closing all dialogs/sheets...');
                            // Close confirmation dialog
                            rootNavigator.pop();
                            
                            // Small delay to let UI update
                            await Future.delayed(const Duration(milliseconds: 100));
                            
                            print('   Step 2: Calling deleteVideo API...');
                            // Delete video
                            await videoService.deleteVideo(widget.videoId, widget.userId);
                            
                            print('   Step 3: Video deleted successfully!');
                            print('   Step 4: Calling onDeleted callback...');
                            
                            // Call onDeleted callback - this will handle navigation
                            widget.onDeleted();
                            
                            print('   ✅ Delete process completed!');
                            
                          } catch (e) {
                            print('   ❌ Error during delete: $e');
                            
                            // Try to close any remaining dialogs
                            try {
                              rootNavigator.pop();
                            } catch (_) {}
                            
                            // Show error using root scaffold - check if context is still mounted
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('❌ Lỗi: ${e.toString().replaceAll('Exception: ', '')}'),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _localeService.get('delete'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
