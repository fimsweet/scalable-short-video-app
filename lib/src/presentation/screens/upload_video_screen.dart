import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'dart:ui' as ui;

// Custom painter for dashed border
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 2,
    this.dashWidth = 8,
    this.dashSpace = 4,
    this.borderRadius = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    path.addRRect(rrect);

    final dashPath = _createDashedPath(path, dashWidth, dashSpace);
    canvas.drawPath(dashPath, paint);
  }

  Path _createDashedPath(Path source, double dashWidth, double dashSpace) {
    final dashedPath = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final nextDash = distance + dashWidth;
        final nextSpace = nextDash + dashSpace;
        dashedPath.addPath(
          metric.extractPath(distance, nextDash.clamp(0.0, metric.length)),
          Offset.zero,
        );
        distance = nextSpace;
      }
    }
    return dashedPath;
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        dashWidth != oldDelegate.dashWidth ||
        dashSpace != oldDelegate.dashSpace ||
        borderRadius != oldDelegate.borderRadius;
  }
}

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final VideoService _videoService = VideoService();
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();

  XFile? _selectedVideo;
  bool _isUploading = false;

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

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );

      if (video != null) {
        print('📹 Video picked: ${video.name}');
        
        final mimeType = video.mimeType?.toLowerCase() ?? '';
        final extension = video.path.toLowerCase().split('.').last;
        
        final isValidFormat = 
            mimeType.startsWith('video/') ||
            ['mp4', 'mov', 'avi', 'webm', 'mkv'].contains(extension);
        
        if (!isValidFormat) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Định dạng video không được hỗ trợ'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final fileSize = await video.length();
        const maxSize = 500 * 1024 * 1024;
        if (fileSize > maxSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Kích thước video tối đa 500MB'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedVideo = video;
        });
      }
    } catch (e) {
      print('❌ Error picking video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn video: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadVideo() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn video'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final token = await _authService.getToken();
      final user = _authService.user;

      if (token == null || user == null) {
        throw Exception('Vui lòng đăng nhập lại');
      }

      final description = _descriptionController.text.trim();
      final result = await _videoService.uploadVideo(
        videoFile: _selectedVideo!,
        userId: user['id'].toString(),
        title: description,
        description: description,
        token: token,
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
        });

        if (result['success']) {
          // Show success bottom sheet
          await showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isDismissible: false,
            enableDrag: false,
            builder: (context) => Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Video đã được tải lên!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Video của bạn đang được xử lý và sẽ xuất hiện sớm thôi!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.pop(context, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Đóng',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload thất bại: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Upload error: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: _themeService.iconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Upload Video',
          style: TextStyle(color: _themeService.textPrimaryColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (!_isUploading)
            TextButton(
              onPressed: _uploadVideo,
              child: Text(
                'Đăng',
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Video Preview Area
                GestureDetector(
                  onTap: _isUploading ? null : _pickVideo,
                  child: CustomPaint(
                    painter: DashedBorderPainter(
                      color: _selectedVideo != null 
                          ? (_themeService.isLightMode ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.3))
                          : (_themeService.isLightMode ? Colors.grey[400]! : Colors.grey[700]!),
                      strokeWidth: 2,
                      dashWidth: 10,
                      dashSpace: 5,
                      borderRadius: 16,
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 400,
                      decoration: BoxDecoration(
                        color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _selectedVideo != null
                            ? [
                                BoxShadow(
                                  color: Colors.pink.withOpacity(0.1),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                    child: _selectedVideo == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Upload Icon - TikTok style
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.pink.withOpacity(0.3),
                                      Colors.purple.withOpacity(0.3),
                                      Colors.blue.withOpacity(0.3),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 56,
                                    color: _themeService.textPrimaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Chọn video từ thư viện',
                                style: TextStyle(
                                  color: _themeService.textPrimaryColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _themeService.isLightMode ? Colors.grey[200]?.withOpacity(0.5) : Colors.grey[800]?.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: _themeService.textSecondaryColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Tối đa 500MB • MP4, MOV, AVI',
                                      style: TextStyle(
                                        color: _themeService.textSecondaryColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Tap to upload hint
                              CustomPaint(
                                painter: DashedBorderPainter(
                                  color: _themeService.isLightMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.2),
                                  strokeWidth: 1.5,
                                  dashWidth: 6,
                                  dashSpace: 3,
                                  borderRadius: 25,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.touch_app,
                                        size: 18,
                                        color: _themeService.textPrimaryColor.withOpacity(0.7),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Nhấn để chọn video',
                                        style: TextStyle(
                                          color: _themeService.textPrimaryColor.withOpacity(0.7),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Stack(
                            children: [
                              // Selected video preview
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Success checkmark
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.green.shade400,
                                            Colors.teal.shade400,
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.green.withOpacity(0.4),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.check_circle,
                                        size: 48,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _themeService.isLightMode ? Colors.white.withOpacity(0.9) : Colors.black87,
                                        borderRadius: BorderRadius.circular(12),
                                        border: _themeService.isLightMode ? Border.all(color: Colors.grey[300]!, width: 1) : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.video_library,
                                            color: _themeService.textPrimaryColor.withOpacity(0.7),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Video đã chọn',
                                            style: TextStyle(
                                              color: _themeService.textPrimaryColor.withOpacity(0.7),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Text(
                                        _selectedVideo!.name,
                                        style: TextStyle(
                                          color: _themeService.textPrimaryColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Change video button
                                    TextButton.icon(
                                      onPressed: _pickVideo,
                                      icon: const Icon(Icons.swap_horiz, size: 18),
                                      label: const Text('Chọn video khác'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: _themeService.textPrimaryColor.withOpacity(0.7),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isUploading)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _themeService.isLightMode ? Colors.white.withOpacity(0.95) : Colors.black87,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          color: _themeService.textPrimaryColor,
                                          strokeWidth: 3,
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          'Đang upload...',
                                          style: TextStyle(
                                            color: _themeService.textPrimaryColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Description Input
                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isUploading,
                  style: TextStyle(color: _themeService.textPrimaryColor, fontSize: 15),
                  maxLength: 2200,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: 'Mô tả video',
                    labelStyle: TextStyle(color: _themeService.textSecondaryColor, fontSize: 13),
                    hintText: 'Kể về video của bạn...',
                    hintStyle: TextStyle(color: _themeService.textSecondaryColor, fontSize: 15),
                    filled: true,
                    fillColor: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                    counterStyle: TextStyle(color: _themeService.textSecondaryColor),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập mô tả cho video';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Upload Button (only show if video selected)
                if (_selectedVideo != null && !_isUploading)
                  Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.pink.shade400,
                          Colors.purple.shade400,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(27),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pink.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _uploadVideo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Đăng video',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
