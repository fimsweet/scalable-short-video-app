import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/screens/register_screen.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();
  final _apiService = ApiService();
  final _themeService = ThemeService();
  final _localeService = LocaleService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (result['success']) {
        // Lấy dữ liệu người dùng từ API response
        final responseData = result['data'];
        final userData = responseData['user'];
        final token = responseData['access_token'];
        await _auth.login(userData, token);
        if (mounted) {
          Navigator.pop(context, true); // Trả về thành công
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? _localeService.get('login_failed')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_localeService.get('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToRegister() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (result == true) {
      Navigator.pop(context, true); // Đăng ký thành công -> tự động đăng nhập và quay lại
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        title: Text(_localeService.get('login'), style: TextStyle(color: _themeService.textPrimaryColor)),
        iconTheme: IconThemeData(color: _themeService.iconColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 40),
              TextFormField(
                controller: _usernameController,
                style: TextStyle(color: _themeService.textPrimaryColor),
                decoration: _inputDecoration(_localeService.get('email')),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return _localeService.get('please_enter_email');
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return _localeService.get('invalid_email');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                style: TextStyle(color: _themeService.textPrimaryColor),
                decoration: _inputDecoration(_localeService.get('password')),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return _localeService.get('please_enter_password');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_localeService.get('login'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: () {}, child: Text(_localeService.get('forgot_password'), style: TextStyle(color: _themeService.textSecondaryColor))),
              const SizedBox(height: 32),
              Text(_localeService.get('or_login_with'), style: TextStyle(color: _themeService.textSecondaryColor)),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12.0,
                runSpacing: 12.0,
                children: [
                  _SocialButton(icon: Icons.facebook, label: _localeService.get('facebook'), onTap: () {}, themeService: _themeService),
                  _SocialButton(icon: Icons.g_mobiledata, label: _localeService.get('google'), onTap: () {}, themeService: _themeService),
                  _SocialButton(icon: Icons.phone, label: _localeService.get('phone'), onTap: () {}, themeService: _themeService),
                ],
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _navigateToRegister,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: _localeService.get('no_account'), style: TextStyle(color: _themeService.textSecondaryColor)),
                    TextSpan(text: _localeService.get('register'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _themeService.textSecondaryColor),
        filled: true,
        fillColor: _themeService.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ThemeService themeService;
  const _SocialButton({required this.icon, required this.label, required this.onTap, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: themeService.dividerColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: themeService.textPrimaryColor),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: themeService.textPrimaryColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
