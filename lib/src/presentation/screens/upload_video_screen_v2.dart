import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'dart:io';

/// Modern multi-stage video upload screen
/// Stage 1: Pick video
/// Stage 2: Add description & select categories
/// Stage 3: Upload & success
class UploadVideoScreenV2 extends StatefulWidget {
  const UploadVideoScreenV2({super.key});

  @override
  State<UploadVideoScreenV2> createState() => _UploadVideoScreenV2State();
}

class _UploadVideoScreenV2State extends State<UploadVideoScreenV2>
    with TickerProviderStateMixin {
  // Controllers & Services
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final VideoService _videoService = VideoService();
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final ApiService _apiService = ApiService();

  // State
  int _currentStage = 0; // 0: Pick video, 1: Details, 2: Uploading/Success
  XFile? _selectedVideo;
  XFile? _selectedThumbnail; // Custom thumbnail
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _uploadSuccess = false;
  String? _uploadError;

  // Categories
  List<Map<String, dynamic>> _categories = [];
  Set<int> _selectedCategoryIds = {};
  bool _isCategoriesLoading = true;

  // Video thumbnail
  VideoPlayerController? _thumbnailController;

  // Animation
  late AnimationController _stageAnimController;
  late AnimationController _successAnimController;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _descriptionController.addListener(_onDescriptionChanged);
    _loadCategories();

    _pageController = PageController();

    _stageAnimController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _successAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    _thumbnailController?.dispose();
    _stageAnimController.dispose();
    _successAnimController.dispose();
    _pageController.dispose();
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onThemeChanged() => mounted ? setState(() {}) : null;
  void _onLocaleChanged() => mounted ? setState(() {}) : null;
  void _onDescriptionChanged() => mounted ? setState(() {}) : null;

  Future<void> _loadCategories() async {
    try {
      final result = await _apiService.getCategories();
      if (result['success'] && mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _isCategoriesLoading = false;
        });
      } else if (mounted) {
        setState(() => _isCategoriesLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isCategoriesLoading = false);
    }
  }

  void _toggleCategory(int categoryId) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else if (_selectedCategoryIds.length < 3) {
        _selectedCategoryIds.add(categoryId);
      } else {
        _showSnackBar(_localeService.get('max_3_categories'), Colors.orange);
      }
    });
  }

  String _getCategoryDisplayName(Map<String, dynamic> category) {
    if (_localeService.currentLocale == 'vi' && category['displayNameVi'] != null) {
      return category['displayNameVi'];
    }
    return category['displayName'] ?? category['name'] ?? '';
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _pickVideo() async {
    try {
      HapticFeedback.selectionClick();
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );

      if (video != null) {
        final fileName = video.name.toLowerCase();
        final extension = fileName.contains('.') ? fileName.split('.').last : '';
        final validExtensions = ['mp4', 'mov', 'avi', 'webm', 'mkv', 'm4v', '3gp', 'wmv', 'flv'];

        if (!validExtensions.contains(extension)) {
          _showSnackBar('${_localeService.get('video_format_not_supported')}: $extension', Colors.red);
          return;
        }

        final fileSize = await video.length();
        if (fileSize > 500 * 1024 * 1024) {
          _showSnackBar(_localeService.get('video_max_size'), Colors.red);
          return;
        }

        HapticFeedback.mediumImpact();
        setState(() => _selectedVideo = video);
        await _generateThumbnail(video);
        _goToNextStage();
      }
    } catch (e) {
      _showSnackBar('${_localeService.get('error_selecting_video')}: $e', Colors.red);
    }
  }

  Future<void> _generateThumbnail(XFile video) async {
    try {
      _thumbnailController?.dispose();
      _thumbnailController = VideoPlayerController.file(File(video.path));
      await _thumbnailController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      print('Error generating thumbnail: $e');
    }
  }

  Future<void> _pickCustomThumbnail() async {
    try {
      HapticFeedback.selectionClick();
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        HapticFeedback.mediumImpact();
        setState(() => _selectedThumbnail = image);
      }
    } catch (e) {
      _showSnackBar('${_localeService.get('error_occurred')}: $e', Colors.red);
    }
  }

  void _removeCustomThumbnail() {
    HapticFeedback.lightImpact();
    setState(() => _selectedThumbnail = null);
  }

  void _goToNextStage() {
    if (_currentStage < 2) {
      setState(() => _currentStage++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _goToPreviousStage() {
    if (_currentStage > 0 && !_isUploading) {
      setState(() => _currentStage--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<bool> _handleBackPressed() async {
    if (_isUploading) return false;
    if (_uploadSuccess) {
      Navigator.pop(context, true);
      return false;
    }

    if (_currentStage > 0) {
      _goToPreviousStage();
      return false;
    }

    if (_selectedVideo != null || _descriptionController.text.isNotEmpty) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => _buildDiscardDialog(),
      );
      return shouldExit ?? false;
    }

    return true;
  }

  Widget _buildDiscardDialog() {
    return AlertDialog(
      backgroundColor: _themeService.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_rounded, color: Colors.orange, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _localeService.get('discard_changes'),
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        _localeService.get('discard_changes_message'),
        style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 15),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            _localeService.get('continue_editing'),
            style: TextStyle(color: ThemeService.accentColor, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Hủy bỏ',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Future<void> _uploadVideo() async {
    if (_selectedVideo == null) return;
    if (_descriptionController.text.trim().isEmpty) {
      _showSnackBar(_localeService.get('please_enter_description'), Colors.orange);
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadError = null;
    });
    _goToNextStage();

    try {
      final token = await _authService.getToken();
      final user = _authService.user;

      if (token == null || user == null) {
        throw Exception(_localeService.get('please_login_again'));
      }

      // Simulate progress (actual progress from API if available)
      _startProgressSimulation();

      final description = _descriptionController.text.trim();
      
      // Use upload with thumbnail if custom thumbnail is selected
      final Map<String, dynamic> result;
      if (_selectedThumbnail != null) {
        result = await _videoService.uploadVideoWithThumbnail(
          videoFile: _selectedVideo!,
          thumbnailFile: _selectedThumbnail,
          userId: user['id'].toString(),
          title: description,
          description: description,
          token: token,
          categoryIds: _selectedCategoryIds.isNotEmpty ? _selectedCategoryIds.toList() : null,
        );
      } else {
        result = await _videoService.uploadVideo(
          videoFile: _selectedVideo!,
          userId: user['id'].toString(),
          title: description,
          description: description,
          token: token,
          categoryIds: _selectedCategoryIds.isNotEmpty ? _selectedCategoryIds.toList() : null,
        );
      }

      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 1.0;
        });

        if (result['success']) {
          setState(() => _uploadSuccess = true);
          _successAnimController.forward();
          HapticFeedback.heavyImpact();
        } else {
          setState(() => _uploadError = result['message']);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadError = e.toString();
        });
      }
    }
  }

  void _startProgressSimulation() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || !_isUploading || _uploadProgress >= 0.95) return false;
      setState(() => _uploadProgress += 0.02);
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = !_themeService.isLightMode;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackPressed();
        if (shouldPop && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: _themeService.backgroundColor,
        appBar: _buildAppBar(isDark),
        body: Column(
          children: [
            // Stage indicator
            _buildStageIndicator(isDark),
            
            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStage1PickVideo(isDark),
                  _buildStage2Details(isDark),
                  _buildStage3Upload(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: _themeService.appBarBackground,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          _currentStage == 0 ? Icons.close_rounded : Icons.chevron_left,
          color: _themeService.iconColor,
          size: _currentStage == 0 ? 22 : 28,
        ),
        onPressed: () async {
          if (_uploadSuccess) {
            Navigator.pop(context, true);
          } else if (_currentStage > 0 && !_isUploading) {
            _goToPreviousStage();
          } else {
            final shouldPop = await _handleBackPressed();
            if (shouldPop && mounted) Navigator.pop(context);
          }
        },
      ),
      title: Text(
        _localeService.get('upload_video'),
        style: TextStyle(
          color: _themeService.textPrimaryColor,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildStageIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _buildStageStep(0, _localeService.isVietnamese ? 'Chọn video' : 'Select', isDark),
          _buildStageConnector(0, isDark),
          _buildStageStep(1, _localeService.isVietnamese ? 'Chi tiết' : 'Details', isDark),
          _buildStageConnector(1, isDark),
          _buildStageStep(2, _localeService.isVietnamese ? 'Đăng tải' : 'Upload', isDark),
        ],
      ),
    );
  }

  Widget _buildStageStep(int stage, String label, bool isDark) {
    final isActive = _currentStage >= stage;
    final isCurrent = _currentStage == stage;

    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive ? ThemeService.accentColor : (isDark ? Colors.grey[800] : Colors.grey[200]),
              shape: BoxShape.circle,
              border: isCurrent
                  ? Border.all(color: ThemeService.accentColor.withOpacity(0.3), width: 3)
                  : null,
              boxShadow: isCurrent
                  ? [BoxShadow(color: ThemeService.accentColor.withOpacity(0.3), blurRadius: 8)]
                  : null,
            ),
            child: Center(
              child: isActive && !isCurrent
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                  : Text(
                      '${stage + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : _themeService.textSecondaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? _themeService.textPrimaryColor : _themeService.textSecondaryColor,
              fontSize: 12,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageConnector(int afterStage, bool isDark) {
    final isActive = _currentStage > afterStage;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: isActive ? ThemeService.accentColor : (isDark ? Colors.grey[800] : Colors.grey[300]),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  // ========== STAGE 1: PICK VIDEO ==========
  Widget _buildStage1PickVideo(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Main upload area
          GestureDetector(
            onTap: _pickVideo,
            child: Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[50],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: ThemeService.accentColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_upload_rounded,
                      size: 64,
                      color: ThemeService.accentColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _localeService.get('select_video_from_library'),
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _localeService.get('tap_to_select_video'),
                    style: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _localeService.get('max_size_format'),
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Supported formats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: _themeService.textSecondaryColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _localeService.isVietnamese
                        ? 'Hỗ trợ: MP4, MOV, AVI, WebM, MKV'
                        : 'Supported: MP4, MOV, AVI, WebM, MKV',
                    style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== STAGE 2: DETAILS ==========
  Widget _buildStage2Details(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video preview
          if (_selectedVideo != null) _buildVideoPreview(isDark),
          const SizedBox(height: 24),

          // Custom thumbnail section
          Row(
            children: [
              Text(
                _localeService.isVietnamese ? 'Ảnh bìa' : 'Cover image',
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _localeService.isVietnamese ? '(tuỳ chọn)' : '(optional)',
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _localeService.isVietnamese 
                ? 'Chọn ảnh bìa tùy chỉnh hoặc để hệ thống tự động tạo'
                : 'Select a custom cover or let the system auto-generate',
            style: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          _buildThumbnailPicker(isDark),
          const SizedBox(height: 24),

          // Description
          Text(
            _localeService.isVietnamese ? 'Mô tả' : 'Description',
            style: TextStyle(
              color: _themeService.textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
            ),
            child: TextField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 500,
              style: TextStyle(color: _themeService.textPrimaryColor, fontSize: 15),
              decoration: InputDecoration(
                hintText: _localeService.get('describe_your_video'),
                hintStyle: TextStyle(color: _themeService.textSecondaryColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                counterStyle: TextStyle(color: _themeService.textSecondaryColor),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Categories
          Row(
            children: [
              Text(
                _localeService.isVietnamese ? 'Thể loại' : 'Categories',
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _localeService.isVietnamese ? '(tuỳ chọn)' : '(optional)',
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ThemeService.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_selectedCategoryIds.length}/3',
                  style: TextStyle(color: ThemeService.accentColor, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCategoriesGrid(isDark),
          const SizedBox(height: 32),

          // Upload button
          _buildUploadButtonStage2(),
        ],
      ),
    );
  }

  Widget _buildThumbnailPicker(bool isDark) {
    return GestureDetector(
      onTap: _pickCustomThumbnail,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedThumbnail != null
                ? ThemeService.accentColor
                : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
            width: _selectedThumbnail != null ? 2 : 1,
          ),
        ),
        child: _selectedThumbnail != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(_selectedThumbnail!.path),
                      fit: BoxFit.cover,
                    ),
                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Custom badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ThemeService.accentColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _localeService.isVietnamese ? 'Tùy chỉnh' : 'Custom',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // Remove & Change buttons
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _removeCustomThumbnail,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.close, color: Colors.white, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    _localeService.isVietnamese ? 'Xóa' : 'Remove',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  _localeService.isVietnamese ? 'Đổi' : 'Change',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Row(
                children: [
                  // Auto-generated preview
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                    child: SizedBox(
                      width: 100,
                      height: 138,
                      child: _thumbnailController?.value.isInitialized == true
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _thumbnailController!.value.size.width,
                                    height: _thumbnailController!.value.size.height,
                                    child: VideoPlayer(_thumbnailController!),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _localeService.isVietnamese ? 'Tự động' : 'Auto',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              color: isDark ? Colors.grey[800] : Colors.grey[300],
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                    ),
                  ),
                  // Select custom thumbnail
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ThemeService.accentColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_photo_alternate_rounded,
                            size: 28,
                            color: ThemeService.accentColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _localeService.isVietnamese ? 'Chọn ảnh bìa' : 'Choose cover',
                          style: TextStyle(
                            color: _themeService.textPrimaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildVideoPreview(bool isDark) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            child: SizedBox(
              width: 100,
              height: 120,
              child: _thumbnailController?.value.isInitialized == true
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _thumbnailController!.value.size.width,
                        height: _thumbnailController!.value.size.height,
                        child: VideoPlayer(_thumbnailController!),
                      ),
                    )
                  : Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _localeService.isVietnamese ? 'Đã chọn video' : 'Video selected',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedVideo!.name,
                    style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      _goToPreviousStage();
                    },
                    child: Text(
                      _localeService.isVietnamese ? 'Đổi video' : 'Change',
                      style: TextStyle(
                        color: ThemeService.accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid(bool isDark) {
    if (_isCategoriesLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map((category) {
        final id = category['id'] as int;
        final isSelected = _selectedCategoryIds.contains(id);

        return GestureDetector(
          onTap: () => _toggleCategory(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? ThemeService.accentColor : (isDark ? Colors.grey[850] : Colors.grey[100]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? ThemeService.accentColor : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
              ),
            ),
            child: Text(
              _getCategoryDisplayName(category),
              style: TextStyle(
                color: isSelected ? Colors.white : _themeService.textPrimaryColor,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUploadButtonStage2() {
    final canUpload = _descriptionController.text.trim().isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: canUpload ? _uploadVideo : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canUpload ? ThemeService.accentColor : Colors.grey[300],
          disabledBackgroundColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
          foregroundColor: Colors.white,
          disabledForegroundColor: _themeService.isLightMode ? Colors.grey[500] : Colors.grey[600],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.upload_rounded,
              size: 22,
              color: canUpload ? Colors.white : (_themeService.isLightMode ? Colors.grey[500] : Colors.grey[600]),
            ),
            const SizedBox(width: 10),
            Text(
              _localeService.get('upload'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: canUpload ? Colors.white : (_themeService.isLightMode ? Colors.grey[500] : Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== STAGE 3: UPLOADING/SUCCESS ==========
  Widget _buildStage3Upload(bool isDark) {
    if (_uploadSuccess) {
      return _buildSuccessView(isDark);
    }

    if (_uploadError != null) {
      return _buildErrorView(isDark);
    }

    return _buildUploadingView(isDark);
  }

  Widget _buildUploadingView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Progress circle
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: _uploadProgress,
                      strokeWidth: 6,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(ThemeService.accentColor),
                    ),
                  ),
                  Text(
                    '${(_uploadProgress * 100).toInt()}%',
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _localeService.isVietnamese ? 'Đang tải lên...' : 'Uploading...',
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _localeService.isVietnamese
                  ? 'Vui lòng không đóng ứng dụng'
                  : 'Please don\'t close the app',
              style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.teal.shade400],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 32),
            Text(
              _localeService.get('video_uploaded'),
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _localeService.get('video_processing'),
              style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeService.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  _localeService.get('done'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
            ),
            const SizedBox(height: 32),
            Text(
              _localeService.get('upload_failed'),
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _uploadError ?? '',
              style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _goToPreviousStage,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: _themeService.textSecondaryColor),
                    ),
                    child: Text(
                      _localeService.isVietnamese ? 'Quay lại' : 'Go back',
                      style: TextStyle(color: _themeService.textPrimaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _uploadError = null;
                        _currentStage = 1;
                      });
                      _pageController.jumpToPage(1);
                      _uploadVideo();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeService.accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(_localeService.isVietnamese ? 'Thử lại' : 'Retry'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
