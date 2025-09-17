import 'package:flutter/material.dart';

class OptionsMenuWidget extends StatelessWidget {
  const OptionsMenuWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2E),
        borderRadius: BorderRadius.only(
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
                  color: Colors.grey,
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
                    children: const [
                      _TopOptionItem(icon: Icons.bookmark_border, label: 'Lưu'),
                      _TopOptionItem(icon: Icons.repeat, label: 'Remix'),
                      _TopOptionItem(icon: Icons.link, label: 'GhéP nối'),
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

  const _TopOptionItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
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
