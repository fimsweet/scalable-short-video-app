import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/screens/register_screen.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();

  void _login() {
    final username = _usernameController.text.trim().isEmpty ? 'user_demo' : _usernameController.text.trim();
    _auth.login(username);
    Navigator.pop(context, true); // Trả về thành công
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Đăng nhập'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            TextField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Tên người dùng hoặc email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Mật khẩu'),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)), // Chữ màu trắng
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: () {}, child: const Text('Quên mật khẩu?', style: TextStyle(color: Colors.grey))),
            const SizedBox(height: 32),
            const Text('Hoặc đăng nhập bằng', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SocialButton(icon: Icons.facebook, label: 'Facebook', onTap: _login),
                _SocialButton(icon: Icons.g_mobiledata, label: 'Google', onTap: _login),
                _SocialButton(icon: Icons.phone, label: 'Số ĐT', onTap: _login),
              ],
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _navigateToRegister,
              child: const Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Chưa có tài khoản? ', style: TextStyle(color: Colors.grey)),
                  TextSpan(text: 'Đăng ký', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[900],
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
  const _SocialButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[700]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
