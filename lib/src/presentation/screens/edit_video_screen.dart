import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/app_snackbar.dart';
import 'dart:io';

class EditVideoScreen extends StatefulWidget {
  final String videoId;
  final String userId;
  final String? currentTitle;
  final String? currentDescription;
  final String? currentThumbnailUrl;
  final Function(String description, String? thumbnailUrl)? onSaved;

  const EditVideoScreen({
    super.key,
    required this.videoId,
    required this.userId,
    this.currentTitle,
    this.currentDescription,
    this.currentThumbnailUrl,
    this.onSaved,
  });

  @override
  State<EditVideoScreen> createState() => _EditVideoScreenState();
}

class _EditVideoScreenState extends State<EditVideoScreen> {
  final VideoService _videoService = VideoService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final ImagePicker _picker = ImagePicker();
  
  late TextEditingController _descriptionController;
  
  bool _isLoading = false;
  bool _hasChanges = false;
  XFile? _newThumbnail;
  String? _currentThumbnailUrl;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.currentDescription ?? '');
    _currentThumbnailUrl = widget.currentThumbnailUrl;
    
    _descriptionController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onTextChanged);
    _descriptionController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final descChanged = _descriptionController.text != (widget.currentDescription ?? '');
    
    if (mounted) {
      setState(() {
        _hasChanges = descChanged || _newThumbnail != null;
      });
    }
  }

  Future<void> _pickThumbnail() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _newThumbnail = image;
          _hasChanges = true;
        });
      }
    } catch (e) {
      print('Error picking thumbnail: $e');
      if (mounted) {
        AppSnackBar.showError(context, _localeService.get('error_occurred'));
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      String? newThumbnailUrl = _currentThumbnailUrl;
      
      // Upload new thumbnail if selected
      if (_newThumbnail != null) {
        final thumbnailResult = await _videoService.updateThumbnail(
          videoId: widget.videoId,
          userId: widget.userId,
          thumbnailFile: _newThumbnail!,
        );
        
        if (thumbnailResult['success'] == true && thumbnailResult['data'] != null) {
          newThumbnailUrl = thumbnailResult['data']['thumbnailUrl'];
        }
      }
      
      // Update description
      final result = await _videoService.editVideo(
        videoId: widget.videoId,
        userId: widget.userId,
        description: _descriptionController.text.trim(),
      );

      if (result['success'] == true && mounted) {
        widget.onSaved?.call(
          _descriptionController.text.trim(),
          newThumbnailUrl,
        );
        
        AppSnackBar.showSuccess(
          context,
          _localeService.isVietnamese 
              ? 'Đã cập nhật video thành công' 
              : 'Video updated successfully',
        );
        
        Navigator.pop(context, true);
      } else if (mounted) {
        AppSnackBar.showError(context, _localeService.get('error_occurred'));
      }
    } catch (e) {
      print('Error updating video: $e');
      if (mounted) {
        AppSnackBar.showError(context, _localeService.get('error_occurred'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _localeService.isVietnamese ? 'Bỏ thay đổi?' : 'Discard changes?',
          style: TextStyle(color: _themeService.textPrimaryColor),
        ),
        content: Text(
          _localeService.isVietnamese 
              ? 'Bạn có thay đổi chưa được lưu. Bạn có chắc muốn thoát?'
              : 'You have unsaved changes. Are you sure you want to leave?',
          style: TextStyle(color: _themeService.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              _localeService.isVietnamese ? 'Ở lại' : 'Stay',
              style: TextStyle(color: _themeService.textPrimaryColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              _localeService.isVietnamese ? 'Bỏ' : 'Discard',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: _themeService.backgroundColor,
        appBar: AppBar(
          backgroundColor: _themeService.backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.close,
              color: _themeService.textPrimaryColor,
            ),
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            _localeService.isVietnamese ? 'Chỉnh sửa bài đăng' : 'Edit post',
            style: TextStyle(
              color: _themeService.textPrimaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _hasChanges && !_isLoading ? _saveChanges : null,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue,
                      ),
                    )
                  : Text(
                      _localeService.isVietnamese ? 'Lưu' : 'Save',
                      style: TextStyle(
                        color: _hasChanges ? Colors.blue : Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail section
              Text(
                _localeService.isVietnamese ? 'Ảnh bìa' : 'Cover image',
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _buildThumbnailEditor(),
              
              const SizedBox(height: 24),
              
              // Description field
              Text(
                _localeService.isVietnamese ? 'Mô tả' : 'Description',
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 16,
                ),
                maxLines: 5,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: _localeService.isVietnamese 
                      ? 'Thêm mô tả cho video của bạn...' 
                      : 'Add a description for your video...',
                  hintStyle: TextStyle(
                    color: _themeService.textSecondaryColor,
                  ),
                  filled: true,
                  fillColor: _themeService.isLightMode 
                      ? Colors.grey[100] 
                      : Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  counterStyle: TextStyle(
                    color: _themeService.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Info text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _localeService.isVietnamese 
                            ? 'Ảnh bìa và mô tả giúp người xem tìm thấy video của bạn dễ dàng hơn.'
                            : 'Cover image and description help viewers find your video more easily.',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailEditor() {
    return GestureDetector(
      onTap: _pickThumbnail,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _newThumbnail != null 
                  ? Colors.blue 
                  : (_themeService.isLightMode ? Colors.grey[300]! : Colors.grey[700]!),
              width: _newThumbnail != null ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail preview - use contain to show full image
                if (_newThumbnail != null)
                  Image.file(
                    File(_newThumbnail!.path),
                    fit: BoxFit.contain,
                  )
                else if (_currentThumbnailUrl != null && _currentThumbnailUrl!.isNotEmpty)
                  Image.network(
                    _videoService.getVideoUrl(_currentThumbnailUrl!),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildPlaceholder();
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _themeService.textSecondaryColor,
                        ),
                      );
                    },
                  )
                else
                  _buildPlaceholder(),
                
                // Change thumbnail button
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _localeService.isVietnamese ? 'Thay đổi' : 'Change',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // New badge if thumbnail changed
                if (_newThumbnail != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _localeService.isVietnamese ? 'Mới' : 'New',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildPlaceholder() {
    return Container(
      color: _themeService.isLightMode ? Colors.grey[200] : Colors.grey[800],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 48,
            color: _themeService.textSecondaryColor,
          ),
          const SizedBox(height: 8),
          Text(
            _localeService.isVietnamese ? 'Chọn ảnh bìa' : 'Select cover image',
            style: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
