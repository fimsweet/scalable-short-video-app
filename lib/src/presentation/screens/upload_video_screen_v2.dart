import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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

  // Track background upload so we can await it before navigating back
  Future<void>? _backgroundUploadFuture;
  bool _uploadCompleted = false;

  // Chunked upload state — kept for resume capability
  ChunkedUploadState? _chunkedUploadState;
  bool _isResuming = false;

  // Categories
  List<Map<String, dynamic>> _categories = [];
  Set<int> _selectedCategoryIds = {};
  bool _isCategoriesLoading = true;

  // Privacy settings
  String _selectedVisibility = 'public'; // 'public', 'friends', 'private'
  bool _allowComments = true;
  bool _isPrivacyExpanded = false;

  // Video thumbnail
  VideoPlayerController? _thumbnailController;
  
  // Frame picker for auto-thumbnail
  List<Duration> _framePositions = [];
  int _selectedFrameIndex = 0;
  bool _isGeneratingFrames = false;

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
        // Navigate to details screen immediately, generate thumbnail in background
        _goToNextStage();
        _generateThumbnail(video);
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
      if (mounted) {
        setState(() {});
        // Generate 10 random frame positions after initialization
        _generateFramePositions();
      }
    } catch (e) {
      print('Error generating thumbnail: $e');
    }
  }

  void _generateFramePositions() {
    if (_thumbnailController == null || !_thumbnailController!.value.isInitialized) return;
    
    final totalDuration = _thumbnailController!.value.duration;
    if (totalDuration.inMilliseconds <= 0) return;
    
    setState(() => _isGeneratingFrames = true);
    
    // Generate 10 evenly-spaced positions across the video
    final totalMs = totalDuration.inMilliseconds;
    final positions = <Duration>[];
    for (int i = 0; i < 10; i++) {
      final posMs = (totalMs * (i + 0.5) / 10).round();
      positions.add(Duration(milliseconds: posMs));
    }
    
    setState(() {
      _framePositions = positions;
      _selectedFrameIndex = 0;
      _isGeneratingFrames = false;
    });
    
    // Seek to first frame
    _thumbnailController!.seekTo(positions[0]);
  }

  Future<void> _selectFrame(int index) async {
    if (index < 0 || index >= _framePositions.length) return;
    if (_thumbnailController == null || !_thumbnailController!.value.isInitialized) return;
    
    HapticFeedback.selectionClick();
    setState(() => _selectedFrameIndex = index);
    await _thumbnailController!.seekTo(_framePositions[index]);
    if (mounted) setState(() {});
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
          child: Text(
            _localeService.get('discard'),
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
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

    // Auth check first
    final token = await _authService.getToken();
    final user = _authService.user;

    if (token == null || user == null) {
      _showSnackBar(_localeService.get('please_login_again'), Colors.red);
      return;
    }

    HapticFeedback.heavyImpact();
    // Show uploading state and go to stage 3
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadError = null;
      _uploadSuccess = false;
      _uploadCompleted = false;
      _isResuming = false;
    });
    _goToNextStage();

    // ACTUAL UPLOAD - uses chunked upload for resumability and real progress
    final description = _descriptionController.text.trim();
    final categoryIds = _selectedCategoryIds.toList();
    final userId = user['id'].toString();
    
    // Calculate thumbnail timestamp from selected frame (in seconds)
    final double? thumbTimestamp = (_selectedThumbnail == null && _framePositions.isNotEmpty)
        ? _framePositions[_selectedFrameIndex].inMilliseconds / 1000.0
        : null;
    
    Future<void> performUpload() async {
      try {
        print('[UPLOAD] Starting chunked upload for ${_selectedVideo!.name}');
        
        // If custom thumbnail is provided, upload it separately first via the
        // original non-chunked endpoint (thumbnail is small, no need for chunks).
        // Otherwise use chunked upload for the video.
        if (_selectedThumbnail != null) {
          // Custom thumbnail flow: use original upload-with-thumbnail endpoint
          // wrapped with a simple progress simulation since it's a single request
          await _videoService.uploadVideoWithThumbnail(
            videoFile: _selectedVideo!,
            thumbnailFile: _selectedThumbnail,
            userId: userId,
            title: description,
            description: description,
            token: token,
            categoryIds: categoryIds.isNotEmpty ? categoryIds : null,
            visibility: _selectedVisibility,
            allowComments: _allowComments,
          );
        } else {
          // Chunked upload with real progress tracking
          // Step 1: Init upload session and save state (so Resume works on failure)
          final state = _chunkedUploadState ?? await _videoService.initChunkedUpload(
            videoFile: _selectedVideo!,
            userId: userId,
            title: description ?? '',
            description: description,
            token: token,
            categoryIds: categoryIds.isNotEmpty ? categoryIds : null,
            thumbnailTimestamp: thumbTimestamp,
            visibility: _selectedVisibility,
            allowComments: _allowComments,
          );

          // Save state BEFORE uploading chunks — critical for Resume
          if (mounted) setState(() => _chunkedUploadState = state);

          // Step 2: Upload all chunks
          await _videoService.uploadChunks(
            state: state,
            token: token,
            onProgress: (progress) {
              if (mounted) setState(() => _uploadProgress = progress);
            },
          );

          // Step 3: Complete (merge chunks on server)
          final result = await _videoService.completeChunkedUpload(
            uploadId: state.uploadId,
            token: token,
          );

          if (result['success'] != true) {
            throw Exception(result['message'] ?? 'Upload failed');
          }
        }

        print('[UPLOAD] Upload success');
        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadSuccess = true;
            _uploadCompleted = true;
            _chunkedUploadState = null; // Clear state on success
          });
          _successAnimController.forward();
          HapticFeedback.heavyImpact();
        }
      } catch (e) {
        print('[UPLOAD] Upload failed: $e');
        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadError = e.toString();
          });
        }
      }
    }
    
    _backgroundUploadFuture = performUpload();
  }

  /// Resume a failed chunked upload from where it left off
  Future<void> _resumeUpload() async {
    if (_chunkedUploadState == null || _selectedVideo == null) {
      // No resumable state — fall back to full retry
      _retryUpload();
      return;
    }

    final token = await _authService.getToken();
    if (token == null) {
      _showSnackBar(_localeService.get('please_login_again'), Colors.red);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isUploading = true;
      _uploadError = null;
      _isResuming = true;
    });

    Future<void> performResume() async {
      try {
        print('[UPLOAD] Resuming chunked upload: ${_chunkedUploadState!.uploadId}');
        print('[UPLOAD] Already uploaded: ${_chunkedUploadState!.uploadedChunks.length}/${_chunkedUploadState!.totalChunks} chunks');

        // Resume uploading remaining chunks
        await _videoService.uploadChunks(
          state: _chunkedUploadState!,
          token: token,
          onProgress: (progress) {
            if (mounted) setState(() => _uploadProgress = progress);
          },
        );

        // Complete
        final result = await _videoService.completeChunkedUpload(
          uploadId: _chunkedUploadState!.uploadId,
          token: token,
        );

        if (result['success'] != true) {
          throw Exception(result['message'] ?? 'Complete failed');
        }

        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadSuccess = true;
            _uploadCompleted = true;
            _chunkedUploadState = null;
          });
          _successAnimController.forward();
          HapticFeedback.heavyImpact();
        }
      } catch (e) {
        print('[UPLOAD] Resume failed: $e');
        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadError = e.toString();
          });
        }
      }
    }

    _backgroundUploadFuture = performResume();
  }

  /// Full retry — discards existing state and starts fresh
  void _retryUpload() {
    setState(() {
      _uploadError = null;
      _chunkedUploadState = null;
      _currentStage = 1;
    });
    _pageController.jumpToPage(1);
    _uploadVideo();
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

          // Privacy settings
          _buildPrivacySection(isDark),
          const SizedBox(height: 32),

          // Upload button
          _buildUploadButtonStage2(),
        ],
      ),
    );
  }

  Widget _buildThumbnailPicker(bool isDark) {
    if (_selectedThumbnail != null) {
      return _buildCustomThumbnailView(isDark);
    }
    return Column(
      children: [
        _buildFramePicker(isDark),
        const SizedBox(height: 12),
        _buildCustomThumbnailButton(isDark),
      ],
    );
  }

  Widget _buildCustomThumbnailView(bool isDark) {
    return GestureDetector(
      onTap: _pickCustomThumbnail,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThemeService.accentColor, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(_selectedThumbnail!.path), fit: BoxFit.cover),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                    ),
                  ),
                ),
              ),
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
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Row(
                  children: [
                    _buildOverlayButton(
                      icon: Icons.close,
                      label: _localeService.isVietnamese ? 'Xóa' : 'Remove',
                      onTap: _removeCustomThumbnail,
                    ),
                    const SizedBox(width: 8),
                    _buildOverlayButton(
                      icon: Icons.camera_alt_rounded,
                      label: _localeService.isVietnamese ? 'Đổi' : 'Change',
                      onTap: _pickCustomThumbnail,
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

  Widget _buildOverlayButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildFramePicker(bool isDark) {
    final isReady = _thumbnailController?.value.isInitialized == true && _framePositions.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected frame preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: SizedBox(
              width: double.infinity,
              height: 180,
              child: isReady
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
                        // Frame counter badge
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${_selectedFrameIndex + 1}/${_framePositions.length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Timestamp badge
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formatDuration(_framePositions[_selectedFrameIndex]),
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _themeService.textSecondaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _localeService.isVietnamese ? 'Đang tải...' : 'Loading...',
                              style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          // Frame selector strip
          if (isReady)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _localeService.isVietnamese ? 'Chọn khung hình' : 'Select frame',
                    style: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _framePositions.length,
                      itemBuilder: (context, index) {
                        final isSelected = index == _selectedFrameIndex;
                        return GestureDetector(
                          onTap: () => _selectFrame(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 48,
                            height: 48,
                            margin: EdgeInsets.only(right: index < _framePositions.length - 1 ? 8 : 0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? ThemeService.accentColor : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                width: isSelected ? 2.5 : 1,
                              ),
                              color: isSelected
                                  ? ThemeService.accentColor.withOpacity(0.1)
                                  : (isDark ? Colors.grey[800] : Colors.grey[100]),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isSelected ? ThemeService.accentColor : _themeService.textSecondaryColor,
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildCustomThumbnailButton(bool isDark) {
    return GestureDetector(
      onTap: _pickCustomThumbnail,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThemeService.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.add_photo_alternate_rounded, size: 22, color: ThemeService.accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _localeService.isVietnamese ? 'Tải ảnh bìa riêng' : 'Upload custom cover',
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _localeService.isVietnamese ? 'Chọn ảnh từ thư viện' : 'Choose from gallery',
                    style: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: _themeService.textSecondaryColor, size: 22),
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

  Widget _buildPrivacySection(bool isDark) {
    final visibilityOptions = [
      {
        'value': 'public',
        'icon': Icons.public_rounded,
        'label': _localeService.isVietnamese ? 'Mọi người' : 'Everyone',
        'desc': _localeService.isVietnamese ? 'Tất cả mọi người có thể xem' : 'Anyone can view',
      },
      {
        'value': 'friends',
        'icon': Icons.people_rounded,
        'label': _localeService.isVietnamese ? 'Bạn bè' : 'Friends',
        'desc': _localeService.isVietnamese ? 'Chỉ bạn bè theo dõi lẫn nhau' : 'Only mutual followers',
      },
      {
        'value': 'private',
        'icon': Icons.lock_rounded,
        'label': _localeService.isVietnamese ? 'Chỉ mình tôi' : 'Only me',
        'desc': _localeService.isVietnamese ? 'Chỉ bạn có thể xem' : 'Only you can view',
      },
    ];

    // Find the currently selected option for preview
    final currentOption = visibilityOptions.firstWhere(
      (o) => o['value'] == _selectedVisibility,
      orElse: () => visibilityOptions.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Text(
          _localeService.isVietnamese ? 'Quyền riêng tư' : 'Privacy',
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
          child: Column(
            children: [
              // Collapsed header - shows current selection + expand arrow
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isPrivacyExpanded = !_isPrivacyExpanded);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: _isPrivacyExpanded
                        ? const BorderRadius.vertical(top: Radius.circular(16))
                        : BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_rounded, size: 18, color: _themeService.textSecondaryColor),
                      const SizedBox(width: 8),
                      Text(
                        _localeService.isVietnamese ? 'Ai có thể xem video này' : 'Who can view this video',
                        style: TextStyle(
                          color: _themeService.textSecondaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      // Current selection preview
                      Icon(
                        currentOption['icon'] as IconData,
                        size: 16,
                        color: ThemeService.accentColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        currentOption['label'] as String,
                        style: TextStyle(
                          color: ThemeService.accentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _isPrivacyExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: _themeService.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Expandable visibility options
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  children: [
                    Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                    ...visibilityOptions.map((option) {
                      final isSelected = _selectedVisibility == option['value'];
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedVisibility = option['value'] as String);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ThemeService.accentColor.withOpacity(0.08)
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                option['icon'] as IconData,
                                size: 22,
                                color: isSelected ? ThemeService.accentColor : _themeService.textSecondaryColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      option['label'] as String,
                                      style: TextStyle(
                                        color: isSelected ? ThemeService.accentColor : _themeService.textPrimaryColor,
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                    ),
                                    Text(
                                      option['desc'] as String,
                                      style: TextStyle(
                                        color: _themeService.textSecondaryColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? ThemeService.accentColor : _themeService.textSecondaryColor,
                                    width: isSelected ? 6 : 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                crossFadeState: _isPrivacyExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),

              // Divider
              Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[300]),

              // Allow comments toggle (always visible)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 22,
                      color: _themeService.textSecondaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _localeService.isVietnamese ? 'Cho phép bình luận' : 'Allow comments',
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 28,
                      child: CupertinoSwitch(
                        value: _allowComments,
                        onChanged: (val) {
                          HapticFeedback.lightImpact();
                          setState(() => _allowComments = val);
                        },
                        activeTrackColor: ThemeService.accentColor,
                        thumbColor: Colors.white,
                        trackColor: _themeService.switchInactiveTrackColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
    if (_uploadError != null) {
      return _buildErrorView(isDark);
    }

    // Unified view: shows loading → then success, in ONE screen
    return _buildUploadStatusView(isDark);
  }

  Widget _buildUploadStatusView(bool isDark) {
    final isComplete = _uploadSuccess && _uploadCompleted;
    final progressPercent = (_uploadProgress * 100).toInt();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Tick area: progress ring OR success tick
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: isComplete
                  ? Container(
                      key: const ValueKey('tick'),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: ThemeService.accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: ThemeService.accentColor.withOpacity(0.3),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded, size: 64, color: Colors.white),
                    )
                  : SizedBox(
                      key: const ValueKey('progress'),
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Determinate progress ring
                          SizedBox(
                            width: 112,
                            height: 112,
                            child: CircularProgressIndicator(
                              value: _uploadProgress > 0 ? _uploadProgress : null,
                              strokeWidth: 5,
                              color: ThemeService.accentColor,
                              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                            ),
                          ),
                          // Percentage text in center
                          if (_uploadProgress > 0)
                            Text(
                              '$progressPercent%',
                              style: TextStyle(
                                color: _themeService.textPrimaryColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 32),
            Text(
              isComplete
                  ? _localeService.get('video_uploaded')
                  : (_isResuming
                      ? _localeService.get('resuming_upload')
                      : _localeService.get('uploading')),
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isComplete
                  ? _localeService.get('video_processing')
                  : (_uploadProgress > 0
                      ? (_localeService.isVietnamese
                          ? 'Đã tải $progressPercent% \u2022 Nếu mất mạng, bạn có thể tiếp tục sau'
                          : '$progressPercent% uploaded \u2022 Can resume if interrupted')
                      : _localeService.get('upload_preparing')),
              style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // "Done" button — grey & disabled while uploading, accent when done
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isComplete ? () => Navigator.pop(context, true) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isComplete ? ThemeService.accentColor : (isDark ? Colors.grey[700] : Colors.grey[400]),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark ? Colors.grey[700] : Colors.grey[400],
                  disabledForegroundColor: Colors.white60,
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
    final canResume = _chunkedUploadState != null &&
        _chunkedUploadState!.uploadedChunks.isNotEmpty;
    final chunksInfo = canResume
        ? '${_chunkedUploadState!.uploadedChunks.length}/${_chunkedUploadState!.totalChunks}'
        : null;

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
            // Show chunk progress info if resumable
            if (canResume) ...[
              const SizedBox(height: 8),
              Text(
                _localeService.isVietnamese
                    ? 'Đã tải $chunksInfo phần \u2022 Có thể tiếp tục'
                    : '$chunksInfo parts uploaded \u2022 Can resume',
                style: TextStyle(
                  color: ThemeService.accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 40),
            // Resume button (only when chunks have been partially uploaded)
            if (canResume) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _resumeUpload,
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: Text(
                    _localeService.get('resume_upload'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeService.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
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
                      _localeService.get('back'),
                      style: TextStyle(color: _themeService.textPrimaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _retryUpload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canResume
                          ? (isDark ? Colors.grey[700] : Colors.grey[400])
                          : ThemeService.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      canResume
                          ? _localeService.get('restart_upload')
                          : _localeService.get('retry'),
                    ),
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
