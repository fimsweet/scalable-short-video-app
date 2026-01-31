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

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _descriptionFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  final VideoService _videoService = VideoService();
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final ApiService _apiService = ApiService();

  XFile? _selectedVideo;
  bool _isUploading = false;
  bool _isDescriptionFocused = false;

  // Category selection
  List<Map<String, dynamic>> _categories = [];
  Set<int> _selectedCategoryIds = {};
  bool _isCategoriesLoading = true;

  // Video thumbnail
  VideoPlayerController? _thumbnailController;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _descriptionBorderController;
  late AnimationController _uploadButtonController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _borderAnimation;
  late Animation<double> _uploadButtonAnimation;

  // Check if form has unsaved changes
  bool get _hasUnsavedChanges =>
      _selectedVideo != null || _descriptionController.text.trim().isNotEmpty;

  // Check if form is ready to upload
  bool get _canUpload =>
      _selectedVideo != null && _descriptionController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _loadCategories();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _descriptionBorderController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _borderAnimation = CurvedAnimation(
      parent: _descriptionBorderController,
      curve: Curves.easeInOut,
    );

    _uploadButtonController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _uploadButtonAnimation = CurvedAnimation(
      parent: _uploadButtonController,
      curve: Curves.elasticOut,
    );

    _descriptionFocusNode.addListener(_onDescriptionFocusChange);
    _descriptionController.addListener(_onFormChanged);

    _fadeController.forward();
  }

  void _onDescriptionFocusChange() {
    setState(() {
      _isDescriptionFocused = _descriptionFocusNode.hasFocus;
    });
    if (_descriptionFocusNode.hasFocus) {
      _descriptionBorderController.forward();
    } else {
      _descriptionBorderController.reverse();
    }
  }

  void _onFormChanged() {
    if (_canUpload && !_uploadButtonController.isCompleted) {
      _uploadButtonController.forward();
    } else if (!_canUpload && _uploadButtonController.isCompleted) {
      _uploadButtonController.reverse();
    }
    setState(() {});
  }

  Future<bool> _handleBackPressed() async {
    if (!_hasUnsavedChanges) {
      return true;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_rounded,
              color: Colors.orange,
              size: 24,
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
          style: TextStyle(
            color: _themeService.textSecondaryColor,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              _localeService.get('continue_editing'),
              style: TextStyle(
                color: ThemeService.accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              _localeService.get('discard'),
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return shouldExit ?? false;
  }

  Future<void> _loadCategories() async {
    try {
      final result = await _apiService.getCategories();
      if (result['success'] && mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _isCategoriesLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isCategoriesLoading = false;
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        setState(() {
          _isCategoriesLoading = false;
        });
      }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localeService.get('max_3_categories')),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  String _getCategoryDisplayName(Map<String, dynamic> category) {
    if (_localeService.currentLocale == 'vi' &&
        category['displayNameVi'] != null) {
      return category['displayNameVi'];
    }
    return category['displayName'] ?? category['name'] ?? '';
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickVideo() async {
    try {
      HapticFeedback.selectionClick();
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );

      if (video != null) {
        // On web, video.path is a blob URL, so we need to check video.name instead
        final fileName = video.name.toLowerCase();
        final extension = fileName.contains('.') 
            ? fileName.split('.').last 
            : '';
        
        // Check valid video extensions
        final validExtensions = ['mp4', 'mov', 'avi', 'webm', 'mkv', 'm4v', '3gp', 'wmv', 'flv'];
        final isValidFormat = validExtensions.contains(extension);

        // Debug log for web
        print('Video selected:');
        print('   Name: ${video.name}');
        print('   Path: ${video.path}');
        print('   Extension: $extension');
        print('   Is valid: $isValidFormat');

        if (!isValidFormat) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${_localeService.get('video_format_not_supported')}: $extension'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              SnackBar(
                content: Text(_localeService.get('video_max_size')),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
          return;
        }

        HapticFeedback.mediumImpact();
        setState(() {
          _selectedVideo = video;
        });
        _onFormChanged();
        _generateThumbnail(video);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_localeService.get('error_selecting_video')}: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
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

  Future<void> _uploadVideo() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_localeService.get('please_select_video')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _isUploading = true;
    });

    try {
      final token = await _authService.getToken();
      final user = _authService.user;

      if (token == null || user == null) {
        throw Exception(_localeService.get('please_login_again'));
      }

      final description = _descriptionController.text.trim();
      final result = await _videoService.uploadVideo(
        videoFile: _selectedVideo!,
        userId: user['id'].toString(),
        title: description,
        description: description,
        token: token,
        categoryIds:
            _selectedCategoryIds.isNotEmpty ? _selectedCategoryIds.toList() : null,
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
        });

        if (result['success']) {
          await _showSuccessSheet();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${_localeService.get('upload_failed')}: ${result['message']}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_localeService.get('error')}: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _showSuccessSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade500,
              Colors.teal.shade500,
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _localeService.get('video_uploaded'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _localeService.get('video_processing'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _localeService.get('done'),
                    style: const TextStyle(
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
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onFormChanged);
    _descriptionController.dispose();
    _descriptionFocusNode.dispose();
    _fadeController.dispose();
    _descriptionBorderController.dispose();
    _uploadButtonController.dispose();
    _thumbnailController?.dispose();
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = !_themeService.isLightMode;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackPressed();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: _themeService.backgroundColor,
        appBar: _buildAppBar(isDark),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video Picker Section
                    _buildVideoPickerSection(isDark),
                    const SizedBox(height: 28),

                    // Description Section
                    _buildDescriptionSection(isDark),
                    const SizedBox(height: 28),

                    // Categories Section
                    _buildCategoriesSection(isDark),
                    const SizedBox(height: 32),

                    // Upload Button - always visible
                    _buildUploadButton(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
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
          Icons.close_rounded,
          color: _themeService.iconColor,
          size: 26,
        ),
        onPressed: () async {
          final shouldPop = await _handleBackPressed();
          if (shouldPop && mounted) {
            Navigator.pop(context);
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

  Widget _buildVideoPickerSection(bool isDark) {
    return GestureDetector(
      onTap: _isUploading ? null : _pickVideo,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: double.infinity,
        height: _selectedVideo == null ? 280 : 200,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _selectedVideo != null
                ? Colors.green.withValues(alpha: 0.5)
                : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
            width: _selectedVideo != null ? 2 : 1.5,
          ),
          boxShadow: [
            if (_selectedVideo != null)
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 0,
              ),
          ],
        ),
        child: _selectedVideo == null
            ? _buildVideoPickerEmpty(isDark)
            : _buildVideoPickerSelected(isDark),
      ),
    );
  }

  Widget _buildVideoPickerEmpty(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Upload icon
        Icon(
          Icons.cloud_upload_outlined,
          size: 64,
          color: _themeService.textSecondaryColor,
        ),
        const SizedBox(height: 20),
        Text(
          _localeService.get('select_video_from_library'),
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: _themeService.textSecondaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                _localeService.get('max_size_format'),
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 16,
                color: _themeService.textSecondaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                _localeService.get('tap_to_select_video'),
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPickerSelected(bool isDark) {
    return Stack(
      children: [
        // Video thumbnail
        if (_thumbnailController != null && _thumbnailController!.value.isInitialized)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _thumbnailController!.value.size.width,
                  height: _thumbnailController!.value.size.height,
                  child: VideoPlayer(_thumbnailController!),
                ),
              ),
            ),
          )
        else
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: ThemeService.accentColor,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        // Overlay with controls
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ),
        // Video info at bottom
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedVideo!.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _pickVideo,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(
                  Icons.swap_horiz_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  _localeService.get('select_another_video'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Upload overlay
        if (_isUploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: ThemeService.accentColor,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _localeService.get('uploading'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDescriptionSection(bool isDark) {
    final textLength = _descriptionController.text.length;
    final progress = textLength / 2200;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(
              Icons.edit_note_rounded,
              size: 20,
              color: _themeService.textSecondaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              _localeService.get('video_description'),
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Animated description field
        AnimatedBuilder(
          animation: _borderAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Color.lerp(
                    isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    ThemeService.accentColor,
                    _borderAnimation.value,
                  )!,
                  width: 1.5 + (_borderAnimation.value * 0.5),
                ),
                boxShadow: _isDescriptionFocused
                    ? [
                        BoxShadow(
                          color: ThemeService.accentColor.withValues(alpha: 0.1 * _borderAnimation.value),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: child,
            );
          },
          child: TextFormField(
            controller: _descriptionController,
            focusNode: _descriptionFocusNode,
            enabled: !_isUploading,
            cursorColor: ThemeService.accentColor,
            style: TextStyle(
              color: _themeService.textPrimaryColor,
              fontSize: 15,
              height: 1.5,
            ),
            maxLength: 2200,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: _localeService.get('describe_your_video'),
              hintStyle: TextStyle(
                color: _themeService.textSecondaryColor.withValues(alpha: 0.7),
                fontSize: 15,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(18),
              counterText: '',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return _localeService.get('please_enter_description');
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 10),

        // Animated character counter
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress > 0.9
                        ? Colors.orange
                        : progress > 0.95
                            ? Colors.red
                            : ThemeService.accentColor.withValues(alpha: 0.6),
                  ),
                  minHeight: 3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$textLength/2200',
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoriesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(
              Icons.category_outlined,
              size: 20,
              color: _themeService.textSecondaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              _localeService.get('select_categories'),
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _selectedCategoryIds.isNotEmpty
                    ? ThemeService.accentColor.withValues(alpha: 0.1)
                    : (isDark ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_selectedCategoryIds.length}/3',
                style: TextStyle(
                  color: _selectedCategoryIds.isNotEmpty
                      ? ThemeService.accentColor
                      : _themeService.textSecondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _localeService.get('optional'),
          style: TextStyle(
            color: _themeService.textSecondaryColor,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),

        // Category chips
        if (_isCategoriesLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: ThemeService.accentColor,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _categories.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value;
              final isSelected = _selectedCategoryIds.contains(category['id']);
              return _buildCategoryChip(category, isSelected, index);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildCategoryChip(
      Map<String, dynamic> category, bool isSelected, int index) {
    final displayName = _getCategoryDisplayName(category);
    final icon = category['icon'] ?? '🎬';
    final isDark = !_themeService.isLightMode;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: _isUploading ? null : () => _toggleCategory(category['id']),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      ThemeService.accentColor.withValues(alpha: 0.15),
                      Colors.purple.withValues(alpha: 0.1),
                    ],
                  )
                : null,
            color: isSelected
                ? null
                : (isDark ? const Color(0xFF1A1A1A) : Colors.grey[50]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? ThemeService.accentColor
                  : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: ThemeService.accentColor.withValues(alpha: 0.15),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Text(
                displayName,
                style: TextStyle(
                  color: isSelected
                      ? ThemeService.accentColor
                      : _themeService.textPrimaryColor,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    final isEnabled = _canUpload && !_isUploading;
    final buttonColor = isEnabled ? ThemeService.accentColor : Colors.grey[400]!;
    
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isEnabled ? _uploadVideo : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: isEnabled ? 2 : 0,
        ),
        child: _isUploading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _localeService.get('upload_video'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
