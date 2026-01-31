import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

/// A minimal, modern custom snackbar helper
/// Uses neutral colors (gray/white) based on theme for a cleaner look
class AppSnackBar {
  static final ThemeService _themeService = ThemeService();
  
  /// Show a success snackbar - minimal style
  static void showSuccess(BuildContext context, String message, {Duration duration = const Duration(seconds: 2)}) {
    _showSnackBar(
      context: context,
      message: message,
      icon: Icons.check_rounded,
      isSuccess: true,
      duration: duration,
    );
  }
  
  /// Show an error snackbar
  static void showError(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
    _showSnackBar(
      context: context,
      message: message,
      icon: Icons.close_rounded,
      isError: true,
      duration: duration,
    );
  }
  
  /// Show a warning snackbar
  static void showWarning(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
    _showSnackBar(
      context: context,
      message: message,
      icon: Icons.warning_amber_rounded,
      isWarning: true,
      duration: duration,
    );
  }
  
  /// Show an info snackbar
  static void showInfo(BuildContext context, String message, {Duration duration = const Duration(seconds: 2)}) {
    _showSnackBar(
      context: context,
      message: message,
      icon: Icons.info_outline_rounded,
      duration: duration,
    );
  }
  
  static void _showSnackBar({
    required BuildContext context,
    required String message,
    required IconData icon,
    required Duration duration,
    bool isSuccess = false,
    bool isError = false,
    bool isWarning = false,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    final isLightMode = _themeService.isLightMode;
    
    // Minimal color scheme based on theme
    Color backgroundColor;
    Color textColor;
    Color iconColor;
    
    if (isLightMode) {
      // Light mode: dark background
      backgroundColor = const Color(0xFF2D2D2D);
      textColor = Colors.white;
      if (isSuccess) {
        iconColor = const Color(0xFF4CAF50); // Subtle green
      } else if (isError) {
        iconColor = const Color(0xFFEF5350); // Subtle red
      } else if (isWarning) {
        iconColor = const Color(0xFFFFB74D); // Subtle orange
      } else {
        iconColor = Colors.white70;
      }
    } else {
      // Dark mode: light background
      backgroundColor = const Color(0xFFF5F5F5);
      textColor = const Color(0xFF1A1A1A);
      if (isSuccess) {
        iconColor = const Color(0xFF43A047);
      } else if (isError) {
        iconColor = const Color(0xFFE53935);
      } else if (isWarning) {
        iconColor = const Color(0xFFFF9800);
      } else {
        iconColor = const Color(0xFF616161);
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: duration,
        elevation: 2,
      ),
    );
  }
}

/// A modern confirmation dialog
class AppDialog {
  static final LocaleService _localeService = LocaleService();
  
  /// Show a delete confirmation dialog
  static Future<bool?> showDeleteConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _ModernDialog(
        title: title,
        message: message,
        confirmText: confirmText ?? (_localeService.isVietnamese ? 'Xóa' : 'Delete'),
        cancelText: cancelText ?? (_localeService.isVietnamese ? 'Hủy' : 'Cancel'),
        confirmColor: const Color(0xFFFF4444),
        icon: Icons.delete_outline_rounded,
        iconColor: const Color(0xFFFF4444),
      ),
    );
  }
  
  /// Show a generic confirmation dialog
  static Future<bool?> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    Color? confirmColor,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _ModernDialog(
        title: title,
        message: message,
        confirmText: confirmText ?? (_localeService.isVietnamese ? 'Xác nhận' : 'Confirm'),
        cancelText: cancelText ?? (_localeService.isVietnamese ? 'Hủy' : 'Cancel'),
        confirmColor: confirmColor ?? ThemeService.accentColor,
        icon: icon,
      ),
    );
  }
}

class _ModernDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final Color confirmColor;
  final IconData? icon;
  final Color? iconColor;
  
  const _ModernDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.confirmColor,
    this.icon,
    this.iconColor,
  });
  
  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: themeService.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon header (if provided)
            if (icon != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 28, bottom: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (iconColor ?? confirmColor).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: iconColor ?? confirmColor,
                    ),
                  ),
                ),
              ),
            
            // Title
            Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: icon != null ? 8 : 28,
                bottom: 8,
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: themeService.textPrimaryColor,
                ),
              ),
            ),
            
            // Message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: themeService.textSecondaryColor,
                  height: 1.4,
                ),
              ),
            ),
            
            const SizedBox(height: 28),
            
            // Divider
            Container(
              height: 1,
              color: themeService.isLightMode 
                  ? Colors.grey[200] 
                  : Colors.grey[800],
            ),
            
            // Buttons
            IntrinsicHeight(
              child: Row(
                children: [
                  // Cancel button
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(context, false),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          cancelText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: themeService.textSecondaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Vertical divider
                  Container(
                    width: 1,
                    color: themeService.isLightMode 
                        ? Colors.grey[200] 
                        : Colors.grey[800],
                  ),
                  
                  // Confirm button
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(context, true),
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(20),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          confirmText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: confirmColor,
                          ),
                        ),
                      ),
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
}
