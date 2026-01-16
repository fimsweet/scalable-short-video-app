import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/screens/login_screen.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

class LoginRequiredDialog extends StatelessWidget {
  final String actionKey; // "like", "save", "share", "comment", "follow", "post"
  
  const LoginRequiredDialog({
    super.key,
    required this.actionKey,
  });

  static Future<bool?> show(BuildContext context, String actionKey) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => LoginRequiredDialog(actionKey: actionKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final localeService = LocaleService();
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: themeService.isLightMode ? Colors.white : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            
            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D55).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFFFF2D55),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              localeService.get('login_required'),
              style: TextStyle(
                color: themeService.textPrimaryColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                localeService.get('login_to_$actionKey'),
                style: TextStyle(
                  color: themeService.textSecondaryColor,
                  fontSize: 15,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            
            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context); // Close dialog first
                        
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                        
                        // Return true if login successful
                        if (result == true && context.mounted) {
                          // User logged in successfully
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2D55),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        localeService.get('login'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Stay as guest button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: themeService.textPrimaryColor,
                        side: BorderSide(color: themeService.dividerColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        localeService.get('continue_as_guest'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
