import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

/// TikTok-style video options bottom sheet shown on long press
class VideoOptionsSheet extends StatefulWidget {
  final String videoId;
  final String? videoOwnerId;
  final bool isOwnVideo;
  final VoidCallback? onReport;
  final VoidCallback? onCopyLink;
  final ValueChanged<double>? onSpeedChanged;
  final double currentSpeed;
  final bool autoScroll;
  final ValueChanged<bool>? onAutoScrollChanged;

  const VideoOptionsSheet({
    super.key,
    required this.videoId,
    this.videoOwnerId,
    this.isOwnVideo = false,
    this.onReport,
    this.onCopyLink,
    this.onSpeedChanged,
    this.currentSpeed = 1.0,
    this.autoScroll = false,
    this.onAutoScrollChanged,
  });

  @override
  State<VideoOptionsSheet> createState() => _VideoOptionsSheetState();
}

class _VideoOptionsSheetState extends State<VideoOptionsSheet> {
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  late double _selectedSpeed;
  late bool _autoScroll;

  @override
  void initState() {
    super.initState();
    _selectedSpeed = widget.currentSpeed;
    _autoScroll = widget.autoScroll;
  }

  // -- Theme-aware colors --
  Color get _sheetBg => _themeService.isLightMode
      ? const Color(0xFFF1F1F2)
      : const Color(0xFF1C1C1E);

  Color get _cardBg => _themeService.isLightMode
      ? Colors.white
      : const Color(0xFF2C2C2E);

  Color get _textColor => _themeService.isLightMode
      ? const Color(0xFF161823)
      : const Color(0xFFE8E8E8);

  Color get _iconColor => _themeService.isLightMode
      ? const Color(0xFF3A3A3C)
      : const Color(0xFFAEAEB2);

  Color get _chipBg => _themeService.isLightMode
      ? const Color(0xFFEFEFF0)
      : const Color(0xFF3A3A3C);

  Color get _chipSelectedBg => _themeService.isLightMode
      ? const Color(0xFF161823)
      : Colors.white;

  Color get _chipSelectedText => _themeService.isLightMode
      ? Colors.white
      : const Color(0xFF161823);

  Color get _chipText => _themeService.isLightMode
      ? const Color(0xFF61666D)
      : const Color(0xFF8A8B91);

  Color get _inCardDivider => _themeService.isLightMode
      ? const Color(0xFFE8E8E8)
      : const Color(0xFF3A3A3C);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _themeService.isLightMode
                      ? const Color(0xFFD1D1D1)
                      : const Color(0xFF48484A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Group 1: Report & Copy link
            _buildCardGroup([
              if (!widget.isOwnVideo) ...[
                _buildOptionRow(
                  icon: Icons.outlined_flag_rounded,
                  label: _localeService.get('report'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onReport?.call();
                  },
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 0.5,
                  color: _inCardDivider,
                ),
              ],
              _buildOptionRow(
                icon: Icons.link_rounded,
                label: _localeService.get('copy_link'),
                onTap: () {
                  Clipboard.setData(ClipboardData(
                      text: 'https://app.example.com/video/${widget.videoId}'));
                  Navigator.pop(context);
                  widget.onCopyLink?.call();
                },
              ),
            ]),

            const SizedBox(height: 10),

            // Group 2: Speed + Auto scroll
            _buildCardGroup([
              // Speed control row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                child: Row(
                  children: [
                    Icon(Icons.slow_motion_video_rounded,
                        size: 22, color: _iconColor),
                    const SizedBox(width: 14),
                    Text(
                      _localeService.get('speed'),
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    _buildSpeedChips(),
                  ],
                ),
              ),
              // Thin divider inside card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 0.5,
                color: _inCardDivider,
              ),
              // Auto scroll toggle
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
                child: Row(
                  children: [
                    Icon(Icons.swap_vert_rounded,
                        size: 22, color: _iconColor),
                    const SizedBox(width: 14),
                    Text(
                      _localeService.get('auto_scroll'),
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    Transform.scale(
                      scale: 0.78,
                      child: CupertinoSwitch(
                        value: _autoScroll,
                        onChanged: (val) {
                          setState(() => _autoScroll = val);
                          widget.onAutoScrollChanged?.call(val);
                        },
                        activeTrackColor: _themeService.switchActiveTrackColor,
                        thumbColor: Colors.white,
                        trackColor: _themeService.switchInactiveTrackColor,
                      ),
                    ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Wraps children inside a rounded card
  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildOptionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: _iconColor),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedChips() {
    final speeds = [0.5, 1.0, 1.5, 2.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: speeds.map((speed) {
        final isSelected = _selectedSpeed == speed;
        final label = speed == speed.toInt()
            ? '${speed.toInt()}.0x'
            : '${speed}x';
        return GestureDetector(
          onTap: () {
            setState(() => _selectedSpeed = speed);
            widget.onSpeedChanged?.call(speed);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? _chipSelectedBg : _chipBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? _chipSelectedText : _chipText,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
