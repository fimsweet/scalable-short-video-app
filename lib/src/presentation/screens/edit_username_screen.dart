import 'package:flutter/material.dart';
import 'dart:async';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

class EditUsernameScreen extends StatefulWidget {
  const EditUsernameScreen({super.key});

  @override
  State<EditUsernameScreen> createState() => _EditUsernameScreenState();
}

class _EditUsernameScreenState extends State<EditUsernameScreen> {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  
  late TextEditingController _usernameController;
  
  bool _isLoading = false;
  bool _isCheckingAvailability = false;
  bool _canChangeUsername = true;
  int _daysUntilChange = 0;
  DateTime? _nextChangeDate;
  
  String? _errorMessage;
  String? _successMessage;
  bool? _isUsernameAvailable;
  
  Timer? _debounceTimer;
  
  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: _authService.username ?? '');
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _loadUsernameChangeInfo();
  }
  
  void _onThemeChanged() {
    if (mounted) setState(() {});
  }
  
  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }
  
  @override
  void dispose() {
    _usernameController.dispose();
    _debounceTimer?.cancel();
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }
  
  Future<void> _loadUsernameChangeInfo() async {
    final token = await _authService.getToken();
    if (token == null) return;
    
    try {
      final result = await _apiService.getUsernameChangeInfo(token: token);
      if (mounted && result['success'] == true) {
        setState(() {
          _canChangeUsername = result['canChange'] ?? true;
          _daysUntilChange = result['daysUntilChange'] ?? 0;
          if (result['nextChangeDate'] != null) {
            _nextChangeDate = DateTime.tryParse(result['nextChangeDate']);
          }
        });
      }
    } catch (e) {
      print('Error loading username change info: $e');
    }
  }
  
  void _onUsernameChanged(String value) {
    // Reset states
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isUsernameAvailable = null;
    });
    
    // Debounce the availability check
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _checkUsernameAvailability(value);
    });
  }
  
  Future<void> _checkUsernameAvailability(String username) async {
    if (username.isEmpty) return;
    
    // Validate format first
    final validationError = _validateUsername(username);
    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
        _isUsernameAvailable = false;
      });
      return;
    }
    
    // Check if same as current
    if (username.toLowerCase() == (_authService.username ?? '').toLowerCase()) {
      setState(() {
        _errorMessage = _localeService.isVietnamese 
            ? 'Tên người dùng mới phải khác tên hiện tại' 
            : 'New username must be different from current';
        _isUsernameAvailable = false;
      });
      return;
    }
    
    setState(() => _isCheckingAvailability = true);
    
    try {
      final isAvailable = await _authService.checkUsernameAvailable(username);
      if (mounted) {
        setState(() {
          _isCheckingAvailability = false;
          _isUsernameAvailable = isAvailable;
          if (!isAvailable) {
            _errorMessage = _localeService.isVietnamese 
                ? 'Tên người dùng này đã được sử dụng' 
                : 'This username is already taken';
          } else {
            _successMessage = _localeService.isVietnamese 
                ? 'Tên người dùng có sẵn' 
                : 'Username is available';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingAvailability = false;
          _errorMessage = _localeService.isVietnamese 
              ? 'Lỗi kiểm tra tên người dùng' 
              : 'Error checking username';
        });
      }
    }
  }
  
  String? _validateUsername(String username) {
    if (username.length < 3) {
      return _localeService.isVietnamese 
          ? 'Tên người dùng phải có ít nhất 3 ký tự' 
          : 'Username must be at least 3 characters';
    }
    
    if (username.length > 24) {
      return _localeService.isVietnamese 
          ? 'Tên người dùng không được quá 24 ký tự' 
          : 'Username must not exceed 24 characters';
    }
    
    final regex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!regex.hasMatch(username)) {
      return _localeService.isVietnamese 
          ? 'Chỉ được dùng chữ cái, số và dấu gạch dưới' 
          : 'Only letters, numbers, and underscores allowed';
    }
    
    if (RegExp(r'^\d+$').hasMatch(username)) {
      return _localeService.isVietnamese 
          ? 'Tên người dùng không được chỉ chứa số' 
          : 'Username cannot contain only numbers';
    }
    
    return null;
  }
  
  Future<void> _saveUsername() async {
    final newUsername = _usernameController.text.trim();
    
    // Validate
    final validationError = _validateUsername(newUsername);
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }
    
    if (_isUsernameAvailable != true) {
      setState(() {
        _errorMessage = _localeService.isVietnamese 
            ? 'Vui lòng kiểm tra tên người dùng' 
            : 'Please verify username availability';
      });
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final token = await _authService.getToken();
      if (token == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = _localeService.isVietnamese 
              ? 'Vui lòng đăng nhập lại' 
              : 'Please login again';
        });
        return;
      }
      
      final result = await _apiService.changeUsername(
        token: token,
        newUsername: newUsername,
      );
      
      if (result['success'] == true) {
        await _authService.updateUsername(newUsername.toLowerCase());
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_localeService.isVietnamese 
                  ? 'Đổi tên người dùng thành công' 
                  : 'Username changed successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? (_localeService.isVietnamese 
              ? 'Đổi tên người dùng thất bại' 
              : 'Failed to change username');
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = _localeService.isVietnamese 
            ? 'Lỗi: $e' 
            : 'Error: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.isLightMode 
          ? const Color(0xFFF5F5F5) 
          : _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: _themeService.iconColor, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _localeService.isVietnamese ? 'Đổi tên người dùng' : 'Change Username',
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: (_isLoading || !_canChangeUsername || _isUsernameAvailable != true) 
                ? null 
                : _saveUsername,
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _themeService.textPrimaryColor,
                    ),
                  )
                : Text(
                    _localeService.isVietnamese ? 'Lưu' : 'Save',
                    style: TextStyle(
                      color: (_canChangeUsername && _isUsernameAvailable == true)
                          ? Colors.blue
                          : _themeService.textSecondaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cooldown warning
            if (!_canChangeUsername) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.orange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _localeService.isVietnamese 
                                ? 'Chưa thể đổi tên người dùng' 
                                : 'Cannot change username yet',
                            style: TextStyle(
                              color: _themeService.textPrimaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _localeService.isVietnamese 
                                ? 'Bạn có thể đổi sau $_daysUntilChange ngày nữa' 
                                : 'You can change again in $_daysUntilChange days',
                            style: TextStyle(
                              color: _themeService.textSecondaryColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Info box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _themeService.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _localeService.isVietnamese ? 'Lưu ý' : 'Note',
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoItem(
                    _localeService.isVietnamese 
                        ? 'Bạn chỉ có thể đổi tên người dùng mỗi 30 ngày' 
                        : 'You can only change username every 30 days',
                  ),
                  _buildInfoItem(
                    _localeService.isVietnamese 
                        ? 'Độ dài 3-24 ký tự' 
                        : '3-24 characters long',
                  ),
                  _buildInfoItem(
                    _localeService.isVietnamese 
                        ? 'Chỉ dùng chữ cái, số và dấu gạch dưới (_)' 
                        : 'Only letters, numbers, and underscores (_)',
                  ),
                  _buildInfoItem(
                    _localeService.isVietnamese 
                        ? 'Không được chỉ chứa số' 
                        : 'Cannot contain only numbers',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Username input
            Text(
              _localeService.isVietnamese ? 'Tên người dùng mới' : 'New Username',
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _themeService.inputBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _errorMessage != null 
                      ? Colors.red.withOpacity(0.5)
                      : _isUsernameAvailable == true 
                          ? Colors.green.withOpacity(0.5)
                          : _themeService.dividerColor,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _usernameController,
                enabled: _canChangeUsername,
                onChanged: _onUsernameChanged,
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: _localeService.isVietnamese 
                      ? 'Nhập tên người dùng mới' 
                      : 'Enter new username',
                  hintStyle: TextStyle(
                    color: _themeService.textSecondaryColor,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  prefixText: '@',
                  prefixStyle: TextStyle(
                    color: _themeService.textSecondaryColor,
                    fontSize: 16,
                  ),
                  suffixIcon: _isCheckingAvailability
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _themeService.textSecondaryColor,
                            ),
                          ),
                        )
                      : _isUsernameAvailable == true
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : _isUsernameAvailable == false
                              ? const Icon(Icons.cancel, color: Colors.red)
                              : null,
                ),
              ),
            ),
            
            // Error/Success message
            if (_errorMessage != null || _successMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? _successMessage ?? '',
                style: TextStyle(
                  color: _errorMessage != null ? Colors.red : Colors.green,
                  fontSize: 13,
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Current username
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _themeService.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    _localeService.isVietnamese ? 'Tên hiện tại: ' : 'Current: ',
                    style: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '@${_authService.username ?? ''}',
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
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
  
  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
