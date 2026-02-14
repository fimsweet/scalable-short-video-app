import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

class EditDisplayNameScreen extends StatefulWidget {
  const EditDisplayNameScreen({super.key});

  @override
  State<EditDisplayNameScreen> createState() => _EditDisplayNameScreenState();
}

class _EditDisplayNameScreenState extends State<EditDisplayNameScreen> {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();

  late TextEditingController _displayNameController;

  bool _isLoading = false;
  bool _canChange = true;
  int _daysUntilChange = 0;
  DateTime? _nextChangeDate;

  static const int _maxLength = 30;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: _authService.fullName ?? '',
    );
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _loadChangeInfo();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  Future<void> _loadChangeInfo() async {
    final token = await _authService.getToken();
    if (token == null) return;

    try {
      final result = await _apiService.getDisplayNameChangeInfo(token: token);
      if (mounted && result['success'] == true) {
        setState(() {
          _canChange = result['canChange'] ?? true;
          _daysUntilChange = result['daysUntilChange'] ?? 0;
          if (result['nextChangeDate'] != null) {
            _nextChangeDate = DateTime.tryParse(result['nextChangeDate']);
          }
        });
      }
    } catch (e) {
      print('Error loading display name change info: $e');
    }
  }

  String? _validate(String name) {
    final trimmed = name.trim();
    // Empty is allowed when removing display name
    if (trimmed.isEmpty) return null;
    if (trimmed.length < 2) {
      return _localeService.isVietnamese
          ? 'Tên hiển thị phải có ít nhất 2 ký tự'
          : 'Display name must be at least 2 characters';
    }
    if (trimmed.length > _maxLength) {
      return _localeService.isVietnamese
          ? 'Tên hiển thị không được quá $_maxLength ký tự'
          : 'Display name must not exceed $_maxLength characters';
    }
    // Allow letters (including Unicode/Vietnamese), numbers, spaces, dots, underscores, hyphens
    final regex = RegExp(r'^[\p{L}\p{N}\s._\-]+$', unicode: true);
    if (!regex.hasMatch(trimmed)) {
      return _localeService.isVietnamese
          ? 'Tên hiển thị chứa ký tự không hợp lệ'
          : 'Display name contains invalid characters';
    }
    return null;
  }

  Future<void> _save() async {
    final newName = _displayNameController.text.trim();

    // If empty → remove display name via updateProfile
    if (newName.isEmpty) {
      await _removeDisplayName();
      return;
    }

    final error = _validate(newName);
    if (error != null) {
      _showSnackBar(error, Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _authService.getToken();
      if (token == null) {
        _showSnackBar(
          _localeService.isVietnamese ? 'Vui lòng đăng nhập lại' : 'Please login again',
          Colors.red,
        );
        return;
      }

      final result = await _apiService.changeDisplayName(
        token: token,
        newDisplayName: newName,
      );

      if (result['success'] == true) {
        await _authService.updateFullName(newName);
        if (mounted) {
          _showSnackBar(
            _localeService.isVietnamese
                ? 'Đổi tên hiển thị thành công'
                : 'Display name changed successfully',
            Colors.green,
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          _showSnackBar(
            _localizeMessage(result['message']),
            Colors.red,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          _localeService.isVietnamese ? 'Đã xảy ra lỗi' : 'An error occurred',
          Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _removeDisplayName() async {
    // Check cooldown first
    if (!_canChange) {
      _showSnackBar(
        _localeService.isVietnamese
            ? 'Bạn chưa thể thay đổi tên hiển thị lúc này. Vui lòng thử lại sau ${_formatNextChangeDate()}.'
            : 'You cannot change your display name yet. Try again after ${_formatNextChangeDate()}.',
        Colors.orange,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _localeService.isVietnamese ? 'Xoá tên hiển thị?' : 'Remove display name?',
          style: TextStyle(color: _themeService.textPrimaryColor, fontSize: 17),
        ),
        content: Text(
          _localeService.isVietnamese
              ? 'Tên hiển thị sẽ bị xoá. Hồ sơ của bạn sẽ chỉ hiển thị tên người dùng (@username).'
              : 'Your display name will be removed. Your profile will only show your username.',
          style: TextStyle(
            color: _themeService.textSecondaryColor,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              _localeService.isVietnamese ? 'Huỷ' : 'Cancel',
              style: TextStyle(color: _themeService.textSecondaryColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              _localeService.isVietnamese ? 'Xoá' : 'Remove',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final token = await _authService.getToken();
      if (token == null) {
        _showSnackBar(
          _localeService.isVietnamese ? 'Vui lòng đăng nhập lại' : 'Please login again',
          Colors.red,
        );
        return;
      }

      final result = await _apiService.removeDisplayName(
        token: token,
      );

      if (result['success'] == true) {
        await _authService.updateFullName('');
        if (mounted) {
          _showSnackBar(
            _localeService.isVietnamese
                ? 'Đã xoá tên hiển thị'
                : 'Display name removed',
            Colors.green,
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          final msg = result['message'];
          if (msg == 'DISPLAY_NAME_COOLDOWN') {
            _showSnackBar(
              _localeService.isVietnamese
                  ? 'Bạn chưa thể xoá tên lúc này. Vui lòng thử lại sau.'
                  : 'You cannot remove your name yet. Please try again later.',
              Colors.orange,
            );
          } else {
            _showSnackBar(
              _localeService.isVietnamese ? 'Xoá tên thất bại' : 'Failed to remove name',
              Colors.red,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          _localeService.isVietnamese ? 'Đã xảy ra lỗi' : 'An error occurred',
          Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _localizeMessage(String? code) {
    final isVi = _localeService.isVietnamese;
    switch (code) {
      case 'DISPLAY_NAME_EMPTY':
        return isVi ? 'Tên hiển thị không được để trống' : 'Display name cannot be empty';
      case 'DISPLAY_NAME_TOO_SHORT':
        return isVi ? 'Tên hiển thị phải có ít nhất 2 ký tự' : 'Display name must be at least 2 characters';
      case 'DISPLAY_NAME_TOO_LONG':
        return isVi ? 'Tên hiển thị không được quá 30 ký tự' : 'Display name must not exceed 30 characters';
      case 'DISPLAY_NAME_INVALID_CHARS':
        return isVi ? 'Tên hiển thị chứa ký tự không hợp lệ' : 'Display name contains invalid characters';
      case 'DISPLAY_NAME_SAME':
        return isVi ? 'Tên hiển thị mới phải khác tên hiện tại' : 'New display name must be different from current';
      case 'DISPLAY_NAME_COOLDOWN':
        return isVi ? 'Bạn chưa thể thay đổi tên hiển thị lúc này' : 'You cannot change your display name yet';
      case 'DISPLAY_NAME_INAPPROPRIATE':
        return isVi ? 'Tên hiển thị chứa nội dung không phù hợp' : 'Display name contains inappropriate content';
      case 'DISPLAY_NAME_ERROR':
        return isVi ? 'Đã xảy ra lỗi khi đổi tên' : 'An error occurred while changing name';
      default:
        return isVi ? 'Đổi tên thất bại' : 'Failed to change name';
    }
  }

  String _formatNextChangeDate() {
    if (_nextChangeDate == null) return '';
    final months = _localeService.isVietnamese
        ? ['', 'tháng Một', 'tháng Hai', 'tháng Ba', 'tháng Tư', 'tháng Năm', 'tháng Sáu',
           'tháng Bảy', 'tháng Tám', 'tháng Chín', 'tháng Mười', 'tháng Mười Một', 'tháng Mười Hai']
        : ['', 'January', 'February', 'March', 'April', 'May', 'June',
           'July', 'August', 'September', 'October', 'November', 'December'];
    final d = _nextChangeDate!;
    if (_localeService.isVietnamese) {
      return 'ngày ${d.day} ${months[d.month]}, ${d.year}';
    }
    return '${months[d.month]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final currentLength = _displayNameController.text.length;
    final isFirstTime = _authService.fullName == null || _authService.fullName!.isEmpty;

    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                _localeService.isVietnamese ? 'Hủy' : 'Cancel',
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 16,
                ),
              ),
            ),
            GestureDetector(
              onTap: (_isLoading || (!_canChange && !isFirstTime)) ? null : _save,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ThemeService.accentColor,
                      ),
                    )
                  : Text(
                      _localeService.isVietnamese ? 'Lưu' : 'Save',
                      style: TextStyle(
                        color: (!_canChange && !isFirstTime)
                            ? _themeService.textSecondaryColor
                            : ThemeService.accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              _localeService.isVietnamese ? 'Tên' : 'Name',
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Description / cooldown info
            if (!_canChange && !isFirstTime)
              Text(
                _localeService.isVietnamese
                    ? 'Bạn chỉ có thể thay đổi biệt danh 7 ngày một lần. Bạn có thể tiếp tục thay đổi biệt danh sau ${_formatNextChangeDate()}.'
                    : 'You can only change your display name once every 7 days. You can change it again after ${_formatNextChangeDate()}.',
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              )
            else
              Text(
                _localeService.isVietnamese
                    ? 'Bạn chỉ có thể thay đổi biệt danh 7 ngày một lần.'
                    : 'You can only change your display name once every 7 days.',
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            const SizedBox(height: 24),

            // Input field
            TextField(
              controller: _displayNameController,
              enabled: _canChange || isFirstTime,
              maxLength: _maxLength,
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: _localeService.isVietnamese ? 'Nhập tên hiển thị' : 'Enter display name',
                hintStyle: TextStyle(
                  color: _themeService.textSecondaryColor.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: _themeService.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                counterText: '',
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_displayNameController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _displayNameController.clear();
                          setState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.cancel,
                            size: 18,
                            color: _themeService.textSecondaryColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    Text(
                      '$currentLength/$_maxLength',
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            // Remove display name option (only if user already has a name)
            if (!isFirstTime)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: GestureDetector(
                  onTap: _isLoading ? null : _removeDisplayName,
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_off_outlined,
                        size: 18,
                        color: _canChange
                            ? _themeService.textSecondaryColor
                            : _themeService.textSecondaryColor.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _localeService.isVietnamese ? 'Xoá tên hiển thị' : 'Remove display name',
                        style: TextStyle(
                          color: _canChange
                              ? _themeService.textSecondaryColor
                              : _themeService.textSecondaryColor.withValues(alpha: 0.4),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
