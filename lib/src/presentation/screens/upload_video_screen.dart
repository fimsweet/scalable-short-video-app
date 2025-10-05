import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final VideoService _videoService = VideoService();
  final AuthService _authService = AuthService();

  XFile? _selectedVideo;
  bool _isUploading = false;

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10), // TikTok-style: max 10 minutes
      );

      if (video != null) {
        print('📹 Video picked:');
        print('  Path: ${video.path}');
        print('  Name: ${video.name}');
        print('  MIME type: ${video.mimeType}');
        
        // Validate file format using MIME type (more reliable than extension)
        final mimeType = video.mimeType?.toLowerCase() ?? '';
        final extension = video.path.toLowerCase().split('.').last;
        
        // Check MIME type first (more reliable), fallback to extension
        // Accept any video/* MIME type to be lenient
        final isValidFormat = 
            mimeType.startsWith('video/') || // Any video MIME type
            ['mp4', 'mov', 'avi', 'webm', 'mkv'].contains(extension);
        
        if (!isValidFormat) {
          print('❌ Invalid format detected');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Chỉ hỗ trợ định dạng video\nFile: ${video.name}\nMIME: $mimeType\nExtension: $extension'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }

        print('✅ Video format valid: MIME=$mimeType, Extension=$extension');

        // Validate file size (max 500MB)
        final fileSize = await video.length();
        const maxSize = 500 * 1024 * 1024; // 500MB
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
        print('✅ Selected video: ${video.path} (${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB)');
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

      final result = await _videoService.uploadVideo(
        videoFile: _selectedVideo!,
        userId: user['id'].toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        token: token,
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
        });

        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Video đang được xử lý! Bạn sẽ thấy nó sớm thôi'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return to previous screen
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
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Upload Video'),
        actions: [
          if (!_isUploading)
            TextButton(
              onPressed: _uploadVideo,
              child: const Text(
                'Đăng',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Video Preview
              GestureDetector(
                onTap: _isUploading ? null : _pickVideo,
                child: Container(
                  width: double.infinity,
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _selectedVideo == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_library, size: 64, color: Colors.grey[600]),
                            const SizedBox(height: 16),
                            Text('Chọn video từ thư viện', style: TextStyle(color: Colors.grey[600])),
                          ],
                        )
                      : Stack(
                          children: [
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_circle_outline, size: 64, color: Colors.white),
                                  const SizedBox(height: 8),
                                  Text(
                                    _selectedVideo!.name,
                                    style: const TextStyle(color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            if (_isUploading)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black54,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const CircularProgressIndicator(color: Colors.white),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Đang upload...',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Video requirements info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue[300]),
                        const SizedBox(width: 8),
                        Text(
                          'Yêu cầu video:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[300],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildRequirement('⏱️ Thời lượng: 15 giây - 10 phút'),
                    _buildRequirement('📦 Kích thước: Tối đa 500MB'),
                    _buildRequirement('📹 Định dạng: MP4, MOV, AVI'),
                    _buildRequirement('📱 Tỷ lệ khung hình: 9:16 hoặc 16:9'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text('Tiêu đề', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                enabled: !_isUploading,
                style: const TextStyle(color: Colors.white),
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: 'Thêm tiêu đề thu hút...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tiêu đề';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              const Text('Mô tả (không bắt buộc)', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                enabled: !_isUploading,
                style: const TextStyle(color: Colors.white),
                maxLength: 500,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Chia sẻ thêm về video của bạn...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Upload Button
              if (!_isUploading)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _uploadVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Đăng video',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
