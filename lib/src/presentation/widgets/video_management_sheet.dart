import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';

class VideoManagementSheet extends StatelessWidget {
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
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Hide/Show option
            ListTile(
              leading: Icon(
                isHidden ? Icons.visibility : Icons.visibility_off,
                color: Colors.white,
              ),
              title: Text(
                isHidden ? 'Hiển thị video' : 'Ẩn video',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                isHidden 
                    ? 'Video sẽ hiển thị cho mọi người' 
                    : 'Chỉ người theo dõi của bạn mới thấy video này',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
              ),
              onTap: () async {
                try {
                  final videoService = VideoService();
                  final result = await videoService.toggleHideVideo(videoId, userId);
                  final newHiddenStatus = result['isHidden'] ?? !isHidden;
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    onHiddenChanged(newHiddenStatus);
                    
                    final message = newHiddenStatus 
                        ? 'Video chỉ hiển thị cho người theo dõi' 
                        : 'Video hiển thị cho mọi người';
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

            const Divider(color: Colors.grey, height: 1),

            // Delete option
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              title: const Text(
                'Xóa video',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Video sẽ bị xóa vĩnh viễn',
                style: TextStyle(
                  color: Colors.grey[400],
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
                    backgroundColor: Colors.grey[800],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(
                      color: Colors.white,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                const Text(
                  'Xóa video này?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Video sẽ bị xóa vĩnh viễn và không thể khôi phục.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
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
                          backgroundColor: Colors.grey[800],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(
                            color: Colors.white,
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
                          print('🗑️ DELETE BUTTON PRESSED');
                          print('   VideoId: $videoId');
                          print('   UserId: $userId');
                          
                          // Get the navigator before any async operations
                          final navigator = Navigator.of(context);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          
                          try {
                            print('   Step 1: Closing confirmation dialog...');
                            // Close confirmation dialog first
                            navigator.pop();
                            
                            print('   Step 2: Showing loading indicator...');
                            // Show loading indicator
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (BuildContext dialogContext) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                            );
                            
                            print('   Step 3: Calling deleteVideo API...');
                            // Delete video
                            await videoService.deleteVideo(videoId, userId);
                            
                            print('   Step 4: Video deleted successfully!');
                            
                            if (!context.mounted) {
                              print('   ⚠️ Context not mounted after delete');
                              return;
                            }
                            
                            print('   Step 5: Closing loading indicator...');
                            // Close loading indicator
                            navigator.pop();
                            
                            print('   Step 6: Calling onDeleted callback...');
                            // Call onDeleted callback - this will handle navigation
                            onDeleted();
                            
                            print('   ✅ Delete process completed!');
                            
                          } catch (e) {
                            print('   ❌ Error during delete: $e');
                            
                            if (!context.mounted) {
                              print('   ⚠️ Context not mounted in error handler');
                              return;
                            }
                            
                            // Close loading indicator if showing
                            try {
                              navigator.pop();
                            } catch (popError) {
                              print('   ⚠️ Error popping loading: $popError');
                            }
                            
                            // Extract error message
                            String errorMessage = e.toString().replaceAll('Exception: ', '');
                            
                            // Show error in a snackbar
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('❌ Lỗi: $errorMessage'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Xóa',
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
