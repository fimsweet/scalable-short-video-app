import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

/// Result of the unsaved changes dialog
enum UnsavedChangesResult {
  save,
  discard,
  cancel,
}

/// A reusable dialog to confirm exiting when there are unsaved changes
/// Similar to TikTok's workflow
class UnsavedChangesDialog extends StatelessWidget {
  final ThemeService themeService;
  final LocaleService localeService;

  const UnsavedChangesDialog({
    super.key,
    required this.themeService,
    required this.localeService,
  });

  /// Shows the dialog and returns the user's choice
  static Future<UnsavedChangesResult?> show(BuildContext context) async {
    final themeService = ThemeService();
    final localeService = LocaleService();
    
    return showDialog<UnsavedChangesResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UnsavedChangesDialog(
        themeService: themeService,
        localeService: localeService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: themeService.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              localeService.isVietnamese ? 'Thay đổi chưa lưu' : 'Unsaved Changes',
              style: TextStyle(
                color: themeService.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        localeService.isVietnamese 
            ? 'Bạn có thay đổi chưa được lưu. Bạn muốn lưu trước khi rời đi không?' 
            : 'You have unsaved changes. Do you want to save before leaving?',
        style: TextStyle(
          color: themeService.textSecondaryColor,
          fontSize: 15,
          height: 1.4,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: [
        // Discard button
        TextButton(
          onPressed: () => Navigator.pop(context, UnsavedChangesResult.discard),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Text(
            localeService.isVietnamese ? 'Bỏ thay đổi' : 'Discard',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Cancel button
        TextButton(
          onPressed: () => Navigator.pop(context, UnsavedChangesResult.cancel),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Text(
            localeService.isVietnamese ? 'Tiếp tục chỉnh sửa' : 'Keep Editing',
            style: TextStyle(
              color: themeService.textSecondaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Save button
        ElevatedButton(
          onPressed: () => Navigator.pop(context, UnsavedChangesResult.save),
          style: ElevatedButton.styleFrom(
            backgroundColor: ThemeService.accentColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            localeService.isVietnamese ? 'Lưu' : 'Save',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// A mixin that provides unsaved changes functionality
/// Usage: 
/// 1. Add `with UnsavedChangesMixin` to your State class
/// 2. Override `hasUnsavedChanges` getter
/// 3. Override `saveChanges` method
/// 4. Wrap your Scaffold with `buildWithUnsavedChangesProtection`
mixin UnsavedChangesMixin<T extends StatefulWidget> on State<T> {
  ThemeService get themeService;
  LocaleService get localeService;
  
  /// Override this to check if there are unsaved changes
  bool get hasUnsavedChanges;
  
  /// Override this to save changes
  Future<void> saveChanges();
  
  /// Check and handle back navigation
  Future<bool> handleBackNavigation() async {
    if (!hasUnsavedChanges) {
      return true;
    }
    
    final result = await UnsavedChangesDialog.show(context);
    
    switch (result) {
      case UnsavedChangesResult.save:
        await saveChanges();
        return false; // saveChanges should handle navigation
      case UnsavedChangesResult.discard:
        return true;
      case UnsavedChangesResult.cancel:
      case null:
        return false;
    }
  }
  
  /// Build a back button that checks for unsaved changes
  Widget buildBackButton({
    IconData icon = Icons.close,
    VoidCallback? onBackPressed,
  }) {
    return IconButton(
      icon: Icon(icon, color: themeService.iconColor),
      onPressed: () async {
        final shouldPop = await handleBackNavigation();
        if (shouldPop && context.mounted) {
          if (onBackPressed != null) {
            onBackPressed();
          } else {
            Navigator.pop(context);
          }
        }
      },
    );
  }
}
