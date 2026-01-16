import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../services/locale_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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
    _emailController.dispose();
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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_localeService.get('register_success')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Quay về với success
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? _localeService.get('register_failed')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        title: Text(_localeService.get('register'), style: TextStyle(color: _themeService.textPrimaryColor)),
        iconTheme: IconThemeData(color: _themeService.iconColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                style: TextStyle(color: _themeService.textPrimaryColor),
                decoration: _inputDecoration(_localeService.get('username')),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return _localeService.get('please_enter_username');
                  }
                  if (value.length < 3) {
                    return _localeService.get('username_min_length');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                style: TextStyle(color: _themeService.textPrimaryColor),
                decoration: _inputDecoration(_localeService.get('email')),
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
                  if (value.length < 6) {
                    return _localeService.get('password_min_length');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_localeService.get('create_account'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: _localeService.get('have_account'), style: TextStyle(color: _themeService.textSecondaryColor)),
                      TextSpan(text: _localeService.get('login'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ]),
                  ),
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


