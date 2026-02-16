import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';

class ShareSheetWidget extends StatelessWidget {
  ShareSheetWidget({super.key});

  final LocaleService _localeService = LocaleService();
  final ThemeService _themeService = ThemeService();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: _themeService.surfaceColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
      ),
      child: Column(
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
          Text(
            _localeService.get('share'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: _localeService.get('search'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: _themeService.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: 15, // Mock user count
              itemBuilder: (context, index) {
                return _UserListItem(
                  username: 'nguoidung_${index + 1}',
                  fullName: 'Tên Người Dùng ${index + 1}',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserListItem extends StatelessWidget {
  final String username;
  final String fullName;
  final LocaleService _localeService = LocaleService();
  final ThemeService _themeService = ThemeService();

  _UserListItem({required this.username, required this.fullName});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey,
        // backgroundImage: NetworkImage('...'),
      ),
      title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(fullName, style: TextStyle(color: _themeService.textSecondaryColor)),
      trailing: ElevatedButton(
        onPressed: () {
          // Handle send action
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_localeService.get('sent_to_user')} $username')),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(_localeService.get('send')),
      ),
    );
  }
}
