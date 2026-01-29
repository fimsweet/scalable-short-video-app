import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../services/locale_service.dart';

class LoggedDevicesScreen extends StatefulWidget {
  const LoggedDevicesScreen({super.key});

  @override
  State<LoggedDevicesScreen> createState() => _LoggedDevicesScreenState();
}

class _LoggedDevicesScreenState extends State<LoggedDevicesScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();

  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        setState(() {
          _error = _localeService.get('please_login_again');
          _isLoading = false;
        });
        return;
      }

      final result = await _apiService.getSessions(token: token);
      
      if (result['success'] == true) {
        setState(() {
          _sessions = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result['message'] ?? _localeService.get('error');
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = _localeService.get('error');
        _isLoading = false;
      });
    }
  }

  Future<void> _logoutSession(int sessionId) async {
    final confirmed = await _showConfirmDialog(
      title: _localeService.get('logout_device'),
      message: _localeService.get('logout_device_confirm'),
    );

    if (!confirmed) return;

    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final result = await _apiService.logoutSession(token: token, sessionId: sessionId);
      
      if (result['success'] == true) {
        _showSnackBar(_localeService.get('device_logged_out'), Colors.green);
        _loadSessions();
      } else {
        _showSnackBar(result['message'] ?? _localeService.get('error'), Colors.red);
      }
    } catch (e) {
      _showSnackBar(_localeService.get('error'), Colors.red);
    }
  }

  Future<void> _logoutOtherDevices() async {
    final confirmed = await _showConfirmDialog(
      title: _localeService.get('logout_other_devices'),
      message: _localeService.get('logout_other_devices_confirm'),
    );

    if (!confirmed) return;

    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final result = await _apiService.logoutOtherSessions(token: token);
      
      if (result['success'] == true) {
        _showSnackBar(result['message'] ?? _localeService.get('success'), Colors.green);
        _loadSessions();
      } else {
        _showSnackBar(result['message'] ?? _localeService.get('error'), Colors.red);
      }
    } catch (e) {
      _showSnackBar(_localeService.get('error'), Colors.red);
    }
  }

  Future<void> _logoutAllDevices() async {
    final confirmed = await _showConfirmDialog(
      title: _localeService.get('logout_all_devices'),
      message: _localeService.get('logout_all_devices_confirm'),
    );

    if (!confirmed) return;

    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final result = await _apiService.logoutAllSessions(token: token);
      
      if (result['success'] == true) {
        _showSnackBar(result['message'] ?? _localeService.get('success'), Colors.green);
        // Log out current user
        await _authService.logout();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        _showSnackBar(result['message'] ?? _localeService.get('error'), Colors.red);
      }
    } catch (e) {
      _showSnackBar(_localeService.get('error'), Colors.red);
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: TextStyle(color: _themeService.textPrimaryColor)),
        content: Text(message, style: TextStyle(color: _themeService.textSecondaryColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_localeService.get('cancel'), style: TextStyle(color: _themeService.textSecondaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(_localeService.get('logout')),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.phone_android;
      case 'ios':
        return Icons.phone_iphone;
      case 'web':
        return Icons.computer;
      case 'windows':
        return Icons.desktop_windows;
      case 'macos':
        return Icons.desktop_mac;
      case 'linux':
        return Icons.computer;
      default:
        return Icons.devices;
    }
  }

  Color _getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Colors.green;
      case 'ios':
        return Colors.blue;
      case 'web':
        return Colors.purple;
      case 'windows':
        return Colors.cyan;
      case 'macos':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _getPlatformName(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return 'Android';
      case 'ios':
        return 'iOS';
      case 'web':
        return 'Web Browser';
      case 'windows':
        return 'Windows';
      case 'macos':
        return 'macOS';
      case 'linux':
        return 'Linux';
      default:
        return _localeService.get('unknown_device');
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) {
        return _localeService.get('just_now');
      } else if (diff.inHours < 1) {
        return '${diff.inMinutes} ${_localeService.get('minutes_ago')}';
      } else if (diff.inDays < 1) {
        return '${diff.inHours} ${_localeService.get('hours_ago')}';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} ${_localeService.get('days_ago')}';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: _themeService.textPrimaryColor, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _localeService.get('logged_devices'),
          style: TextStyle(color: _themeService.textPrimaryColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_sessions.length > 1)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: _themeService.textPrimaryColor),
              color: _themeService.cardColor,
              onSelected: (value) {
                if (value == 'logout_others') {
                  _logoutOtherDevices();
                } else if (value == 'logout_all') {
                  _logoutAllDevices();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'logout_others',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      Text(_localeService.get('logout_other_devices'), 
                        style: TextStyle(color: _themeService.textPrimaryColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout_all',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Text(_localeService.get('logout_all_devices'),
                        style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _themeService.primaryAccentColor))
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: _themeService.textSecondaryColor),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: _themeService.textSecondaryColor)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadSessions,
              icon: const Icon(Icons.refresh),
              label: Text(_localeService.get('retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: _themeService.primaryAccentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices, size: 64, color: _themeService.textSecondaryColor),
            const SizedBox(height: 16),
            Text(
              _localeService.get('no_devices_found'),
              style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current device section
          Text(
            _localeService.get('current_device'),
            style: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ..._sessions.where((s) => s['isCurrent'] == true).map((session) => _buildDeviceCard(session, isCurrent: true)),
          
          // Other devices section
          if (_sessions.any((s) => s['isCurrent'] != true)) ...[
            const SizedBox(height: 24),
            Text(
              _localeService.get('other_devices'),
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ..._sessions.where((s) => s['isCurrent'] != true).map((session) => _buildDeviceCard(session)),
          ],
          
          const SizedBox(height: 24),
          
          // Info text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _localeService.get('device_security_tip'),
                    style: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> session, {bool isCurrent = false}) {
    final platform = session['platform']?.toString() ?? 'unknown';
    final deviceName = session['deviceName']?.toString() ?? _getPlatformName(platform);
    final deviceModel = session['deviceModel']?.toString();
    final osVersion = session['osVersion']?.toString();
    final loginAt = session['loginAt']?.toString();
    final lastActivityAt = session['lastActivityAt']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _themeService.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent ? Border.all(color: Colors.green, width: 2) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Platform icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getPlatformColor(platform).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getPlatformIcon(platform),
                color: _getPlatformColor(platform),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            
            // Device info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          deviceModel ?? deviceName,
                          style: TextStyle(
                            color: _themeService.textPrimaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _localeService.get('this_device'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_getPlatformName(platform)}${osVersion != null ? ' • $osVersion' : ''}',
                    style: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_localeService.get('last_active')}: ${_formatDate(lastActivityAt ?? loginAt)}',
                    style: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Logout button (only for non-current devices)
            if (!isCurrent)
              IconButton(
                onPressed: () => _logoutSession(session['id']),
                icon: const Icon(Icons.logout, color: Colors.red),
                tooltip: _localeService.get('logout'),
              ),
          ],
        ),
      ),
    );
  }
}
