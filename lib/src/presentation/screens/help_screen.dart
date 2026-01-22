import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();

  // Track expanded FAQ items
  final Set<int> _expandedItems = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _themeService.iconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _localeService.get('help'),
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header section
          _buildHeaderSection(),
          const SizedBox(height: 24),
          
          // FAQ Section
          _buildSectionTitle(_localeService.get('faq_title')),
          const SizedBox(height: 12),
          ..._buildFAQItems(),
          const SizedBox(height: 24),
          
          // Quick Help Section
          _buildSectionTitle(_localeService.get('quick_help')),
          const SizedBox(height: 12),
          _buildQuickHelpCard(
            icon: Icons.account_circle_outlined,
            title: _localeService.get('account_help'),
            subtitle: _localeService.get('account_help_desc'),
          ),
          _buildQuickHelpCard(
            icon: Icons.videocam_outlined,
            title: _localeService.get('video_help'),
            subtitle: _localeService.get('video_help_desc'),
          ),
          _buildQuickHelpCard(
            icon: Icons.security_outlined,
            title: _localeService.get('privacy_security_help'),
            subtitle: _localeService.get('privacy_security_help_desc'),
          ),
          _buildQuickHelpCard(
            icon: Icons.chat_bubble_outline,
            title: _localeService.get('messaging_help'),
            subtitle: _localeService.get('messaging_help_desc'),
          ),
          const SizedBox(height: 24),
          
          // Contact Section
          _buildSectionTitle(_localeService.get('need_more_help')),
          const SizedBox(height: 12),
          _buildContactCard(),
          const SizedBox(height: 24),
          
          // App Info Section
          _buildAppInfoSection(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ThemeService.accentColor.withValues(alpha: 0.8),
            ThemeService.accentColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.help_outline,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            _localeService.get('help_center'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _localeService.get('help_center_desc'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: _themeService.textPrimaryColor,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  List<Widget> _buildFAQItems() {
    final faqItems = [
      {
        'question': _localeService.get('faq_upload'),
        'answer': _localeService.get('faq_upload_answer'),
      },
      {
        'question': _localeService.get('faq_followers'),
        'answer': _localeService.get('faq_followers_answer'),
      },
      {
        'question': _localeService.get('faq_private'),
        'answer': _localeService.get('faq_private_answer'),
      },
      {
        'question': _localeService.get('faq_delete'),
        'answer': _localeService.get('faq_delete_answer'),
      },
      {
        'question': _localeService.get('faq_report'),
        'answer': _localeService.get('faq_report_answer'),
      },
    ];

    return faqItems.asMap().entries.map((entry) {
      final index = entry.key;
      final faq = entry.value;
      final isExpanded = _expandedItems.contains(index);

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _themeService.isLightMode 
              ? Colors.grey[100] 
              : Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _themeService.isLightMode
                ? Colors.grey[300]!
                : Colors.grey[700]!,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedItems.remove(index);
                  } else {
                    _expandedItems.add(index);
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        faq['question']!,
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: _themeService.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  faq['answer']!,
                  style: TextStyle(
                    color: _themeService.textSecondaryColor,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildQuickHelpCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Show a simple dialog with more info
          _showHelpDialog(title, subtitle);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _themeService.isLightMode
                ? Colors.white
                : Colors.grey[850],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _themeService.isLightMode
                  ? Colors.grey[300]!
                  : Colors.grey[700]!,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThemeService.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: ThemeService.accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _themeService.textPrimaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: _themeService.textSecondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          content,
          style: TextStyle(
            color: _themeService.textSecondaryColor,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _localeService.get('ok'),
              style: const TextStyle(color: ThemeService.accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _themeService.isLightMode
            ? Colors.white
            : Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _themeService.isLightMode
              ? Colors.grey[300]!
              : Colors.grey[700]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.email_outlined,
                color: ThemeService.accentColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                _localeService.get('contact_us'),
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _localeService.get('contact_us_desc'),
            style: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_localeService.get('feature_developing')),
                        backgroundColor: ThemeService.accentColor,
                      ),
                    );
                  },
                  icon: const Icon(Icons.send, size: 18),
                  label: Text(_localeService.get('send_feedback')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeService.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _themeService.isLightMode 
            ? Colors.grey[100] 
            : Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.play_circle_filled,
            color: ThemeService.accentColor,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'ShortVideo',
            style: TextStyle(
              color: _themeService.textPrimaryColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _localeService.get('app_version'),
            style: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '© 2025 ShortVideo. ${_localeService.get('all_rights_reserved')}',
            style: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
