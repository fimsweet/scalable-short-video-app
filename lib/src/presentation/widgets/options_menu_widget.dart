import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';

class OptionsMenuWidget extends StatefulWidget {
  final String? videoId;
  final String? userId;
  final bool? isSaved;
  final VoidCallback? onSaveToggle;

  const OptionsMenuWidget({
    super.key,
    this.videoId,
    this.userId,
    this.isSaved,
    this.onSaveToggle,
  });

  @override
  State<OptionsMenuWidget> createState() => _OptionsMenuWidgetState();
}

class _OptionsMenuWidgetState extends State<OptionsMenuWidget> {
  late bool _isSaved;
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _isSaved = widget.isSaved ?? false;
    _themeService.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _handleSaveToggle() {
    setState(() {
      _isSaved = !_isSaved; // Toggle local state immediately
    });
    widget.onSaveToggle?.call(); // Call parent callback
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _themeService.backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: _themeService.textSecondaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _TopOptionItem(
                        icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                        label: _isSaved ? 'Đã lưu' : 'Lưu',
                        isActive: _isSaved,
                        onTap: _handleSaveToggle, // Use local handler
                      ),
                      const _TopOptionItem(icon: Icons.repeat, label: 'Remix'),
                      const _TopOptionItem(icon: Icons.link, label: 'Ghép nối'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _ListOptionItem(
                      icon: Icons.closed_caption_outlined, label: 'Phụ đề'),
                  const _ListOptionItem(
                      icon: Icons.fullscreen, label: 'Xem toàn màn hình'),
                  const _ListOptionItem(icon: Icons.qr_code, label: 'Mã QR'),
                  const Divider(color: Colors.grey),
                  const _ListOptionItem(
                      icon: Icons.visibility_outlined, label: 'Quan tâm'),
                  const _ListOptionItem(
                      icon: Icons.visibility_off_outlined,
                      label: 'Không quan tâm'),
                  const _ListOptionItem(
                    icon: Icons.report_gmailerrorred,
                    label: 'Báo cáo',
                    color: Colors.red,
                  ),
                  const Divider(color: Colors.grey),
                  const _ListOptionItem(
                      icon: Icons.settings_outlined,
                      label: 'Quản lý tùy chọn nội dung'),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TopOptionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive; // Add this parameter

  const _TopOptionItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false, // Add default value
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon, 
              size: 28,
              color: isActive ? Colors.amber : Colors.white, // Change color when active
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label, 
            style: TextStyle(
              fontSize: 13,
              color: isActive ? Colors.amber : Colors.white, // Change text color too
            ),
          ),
        ],
      ),
    );
  }
}

class _ListOptionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _ListOptionItem({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white),
      title: Text(
        label,
        style: TextStyle(color: color ?? Colors.white, fontSize: 16),
      ),
      onTap: () {
        Navigator.pop(context);
      },
    );
  }
}
