import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

class ReportReason {
  final String id;
  final String label;
  final String labelVi;
  final IconData icon;

  const ReportReason({
    required this.id,
    required this.label,
    required this.labelVi,
    required this.icon,
  });
}

class ReportUserScreen extends StatefulWidget {
  final String reportedUserId;
  final String reportedUsername;
  final String? reportedAvatar;

  const ReportUserScreen({
    super.key,
    required this.reportedUserId,
    required this.reportedUsername,
    this.reportedAvatar,
  });

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final TextEditingController _descriptionController = TextEditingController();
  
  String? _selectedReason;
  bool _isSubmitting = false;

  final List<ReportReason> _reasons = [
    ReportReason(id: 'spam', label: 'Spam', labelVi: 'Tin rác / Spam', icon: Icons.mark_email_unread_outlined),
    ReportReason(id: 'harassment', label: 'Harassment', labelVi: 'Quấy rối', icon: Icons.sentiment_very_dissatisfied_outlined),
    ReportReason(id: 'inappropriate_content', label: 'Inappropriate Content', labelVi: 'Nội dung không phù hợp', icon: Icons.block_outlined),
    ReportReason(id: 'fake_account', label: 'Fake Account', labelVi: 'Tài khoản giả mạo', icon: Icons.person_off_outlined),
    ReportReason(id: 'scam', label: 'Scam', labelVi: 'Lừa đảo', icon: Icons.warning_amber_outlined),
    ReportReason(id: 'violence', label: 'Violence', labelVi: 'Bạo lực', icon: Icons.dangerous_outlined),
    ReportReason(id: 'hate_speech', label: 'Hate Speech', labelVi: 'Phát ngôn thù ghét', icon: Icons.speaker_notes_off_outlined),
    ReportReason(id: 'other', label: 'Other', labelVi: 'Lý do khác', icon: Icons.more_horiz_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _descriptionController.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      _showSnackBar(
        _localeService.isVietnamese 
            ? 'Vui lòng chọn lý do báo cáo' 
            : 'Please select a report reason',
        Colors.orange,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        _showSnackBar(
          _localeService.isVietnamese ? 'Vui lòng đăng nhập lại' : 'Please login again',
          Colors.red,
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final success = await _apiService.reportUser(
        reporterId: currentUser['id'].toString(),
        reportedUserId: widget.reportedUserId,
        reason: _selectedReason!,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
      );

      if (mounted) {
        if (success) {
          _showSuccessDialog();
        } else {
          _showSnackBar(
            _localeService.isVietnamese 
                ? 'Có lỗi xảy ra. Vui lòng thử lại sau.' 
                : 'An error occurred. Please try again later.',
            Colors.red,
          );
        }
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          e.toString().contains('24 giờ') || e.toString().contains('24 hours')
              ? (_localeService.isVietnamese 
                  ? 'Bạn đã báo cáo người này gần đây. Vui lòng đợi 24 giờ.' 
                  : 'You have reported this user recently. Please wait 24 hours.')
              : (_localeService.isVietnamese 
                  ? 'Có lỗi xảy ra. Vui lòng thử lại sau.' 
                  : 'An error occurred. Please try again later.'),
          Colors.red,
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _localeService.isVietnamese ? 'Cảm ơn bạn!' : 'Thank you!',
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _localeService.isVietnamese 
                  ? 'Báo cáo của bạn đã được gửi thành công. Chúng tôi sẽ xem xét và xử lý trong thời gian sớm nhất.'
                  : 'Your report has been submitted successfully. We will review and take action as soon as possible.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close report screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _localeService.isVietnamese ? 'Đã hiểu' : 'Got it',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = widget.reportedAvatar != null 
        ? _apiService.getAvatarUrl(widget.reportedAvatar!) 
        : null;

    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: _themeService.iconColor, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _localeService.isVietnamese ? 'Báo cáo' : 'Report',
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User being reported
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _themeService.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _themeService.isLightMode 
                        ? Colors.grey[300] 
                        : Colors.grey[800],
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null 
                        ? Icon(Icons.person, color: _themeService.textSecondaryColor, size: 24)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _localeService.isVietnamese ? 'Báo cáo người dùng' : 'Report user',
                          style: TextStyle(
                            color: _themeService.textSecondaryColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.reportedUsername,
                          style: TextStyle(
                            color: _themeService.textPrimaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Section title
            Text(
              _localeService.isVietnamese 
                  ? 'Tại sao bạn muốn báo cáo người này?' 
                  : 'Why are you reporting this user?',
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _localeService.isVietnamese 
                  ? 'Chọn lý do phù hợp nhất với tình huống của bạn'
                  : 'Select the reason that best describes your situation',
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 13,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Reason options
            Container(
              decoration: BoxDecoration(
                color: _themeService.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: _reasons.asMap().entries.map((entry) {
                  final index = entry.key;
                  final reason = entry.value;
                  final isSelected = _selectedReason == reason.id;
                  final isLast = index == _reasons.length - 1;
                  
                  return Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() => _selectedReason = reason.id);
                        },
                        borderRadius: BorderRadius.vertical(
                          top: index == 0 ? const Radius.circular(16) : Radius.zero,
                          bottom: isLast ? const Radius.circular(16) : Radius.zero,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? Colors.orange.withOpacity(0.2)
                                      : _themeService.isLightMode 
                                          ? Colors.grey[200]
                                          : Colors.grey[800],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  reason.icon,
                                  color: isSelected ? Colors.orange : _themeService.textSecondaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _localeService.isVietnamese ? reason.labelVi : reason.label,
                                  style: TextStyle(
                                    color: _themeService.textPrimaryColor,
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? Colors.orange : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected ? Colors.orange : _themeService.dividerColor,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected 
                                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          indent: 60,
                          color: _themeService.dividerColor,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Additional details
            Text(
              _localeService.isVietnamese 
                  ? 'Chi tiết bổ sung (không bắt buộc)' 
                  : 'Additional details (optional)',
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: _themeService.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 500,
                style: TextStyle(color: _themeService.textPrimaryColor),
                decoration: InputDecoration(
                  hintText: _localeService.isVietnamese 
                      ? 'Mô tả chi tiết hơn về vấn đề...'
                      : 'Describe the issue in more detail...',
                  hintStyle: TextStyle(color: _themeService.textSecondaryColor.withOpacity(0.6)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  counterStyle: TextStyle(color: _themeService.textSecondaryColor),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.orange.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _localeService.isVietnamese ? 'Gửi báo cáo' : 'Submit Report',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Info text
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _localeService.isVietnamese 
                          ? 'Báo cáo của bạn sẽ được giữ bí mật. Người dùng bị báo cáo sẽ không biết ai đã báo cáo họ.'
                          : 'Your report will be kept confidential. The reported user will not know who reported them.',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 13,
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
