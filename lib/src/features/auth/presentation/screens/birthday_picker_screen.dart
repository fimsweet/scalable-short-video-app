import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'username_creation_screen.dart';

/// TikTok-style birthday picker screen
/// Step 2: Select birthday with iOS-style picker wheels
class BirthdayPickerScreen extends StatefulWidget {
  final String registrationMethod; // 'email', 'phone', 'google', 'facebook', 'apple'
  final Map<String, dynamic>? oauthData; // OAuth data containing provider, providerId, email, displayName, photoUrl

  const BirthdayPickerScreen({
    super.key,
    required this.registrationMethod,
    this.oauthData,
  });

  @override
  State<BirthdayPickerScreen> createState() => _BirthdayPickerScreenState();
}

class _BirthdayPickerScreenState extends State<BirthdayPickerScreen> {
  final _themeService = ThemeService();
  final _localeService = LocaleService();
  
  late DateTime _selectedDate;
  late int _selectedDay;
  late int _selectedMonth;
  late int _selectedYear;
  
  // Fixed picker controllers
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _yearController;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onServiceChanged);
    _localeService.addListener(_onServiceChanged);
    
    // Default to 18 years ago (minimum age for most apps)
    final now = DateTime.now();
    _selectedDate = DateTime(now.year - 18, now.month, now.day);
    _selectedDay = _selectedDate.day;
    _selectedMonth = _selectedDate.month;
    _selectedYear = _selectedDate.year;
    
    _dayController = FixedExtentScrollController(initialItem: _selectedDay - 1);
    _monthController = FixedExtentScrollController(initialItem: _selectedMonth - 1);
    _yearController = FixedExtentScrollController(initialItem: _getYearIndex(_selectedYear));
  }

  @override
  void dispose() {
    _themeService.removeListener(_onServiceChanged);
    _localeService.removeListener(_onServiceChanged);
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  int _getYearIndex(int year) {
    final currentYear = DateTime.now().year;
    // Years from 1920 to current year - 13 (minimum age 13)
    return currentYear - 13 - year;
  }

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  bool _isValidAge() {
    final now = DateTime.now();
    final age = now.year - _selectedYear - 
        ((now.month < _selectedMonth || 
          (now.month == _selectedMonth && now.day < _selectedDay)) ? 1 : 0);
    return age >= 13; // Minimum age 13
  }

  String _getAgeText() {
    final now = DateTime.now();
    final age = now.year - _selectedYear - 
        ((now.month < _selectedMonth || 
          (now.month == _selectedMonth && now.day < _selectedDay)) ? 1 : 0);
    
    if (age < 13) {
      return _localeService.get('age_requirement');
    }
    return _localeService.get('your_birthday_wont_be_shown');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = !_themeService.isLightMode;
    final accentColor = ThemeService.accentColor;
    final currentYear = DateTime.now().year;

    // Vietnamese month names
    final monthNames = [
      'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6',
      'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'
    ];
    
    final englishMonthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    final isVietnamese = _localeService.currentLocale == 'vi';
    final displayMonths = isVietnamese ? monthNames : englishMonthNames;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // Title
              Text(
                _localeService.get('whats_your_birthday'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Subtitle
              Text(
                _getAgeText(),
                style: TextStyle(
                  fontSize: 14,
                  color: _isValidAge() 
                      ? (isDarkMode ? Colors.grey[400] : Colors.grey[600])
                      : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Birthday picker wheels
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Month picker
                      Expanded(
                        flex: 3,
                        child: _buildPicker(
                          controller: _monthController,
                          itemCount: 12,
                          itemBuilder: (context, index) {
                            return Center(
                              child: Text(
                                displayMonths[index],
                                style: TextStyle(
                                  fontSize: 20,
                                  color: _selectedMonth == index + 1
                                      ? (isDarkMode ? Colors.white : Colors.black)
                                      : (isDarkMode ? Colors.grey[600] : Colors.grey[400]),
                                  fontWeight: _selectedMonth == index + 1
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          },
                          onSelectedItemChanged: (index) {
                            setState(() {
                              _selectedMonth = index + 1;
                              // Adjust day if needed
                              final daysInMonth = _getDaysInMonth(_selectedYear, _selectedMonth);
                              if (_selectedDay > daysInMonth) {
                                _selectedDay = daysInMonth;
                                _dayController.jumpToItem(_selectedDay - 1);
                              }
                            });
                          },
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      
                      // Day picker
                      Expanded(
                        flex: 2,
                        child: _buildPicker(
                          controller: _dayController,
                          itemCount: _getDaysInMonth(_selectedYear, _selectedMonth),
                          itemBuilder: (context, index) {
                            final day = index + 1;
                            return Center(
                              child: Text(
                                day.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 20,
                                  color: _selectedDay == day
                                      ? (isDarkMode ? Colors.white : Colors.black)
                                      : (isDarkMode ? Colors.grey[600] : Colors.grey[400]),
                                  fontWeight: _selectedDay == day
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          },
                          onSelectedItemChanged: (index) {
                            setState(() {
                              _selectedDay = index + 1;
                            });
                          },
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      
                      // Year picker
                      Expanded(
                        flex: 2,
                        child: _buildPicker(
                          controller: _yearController,
                          itemCount: currentYear - 13 - 1920 + 1, // From 1920 to currentYear - 13
                          itemBuilder: (context, index) {
                            final year = currentYear - 13 - index;
                            return Center(
                              child: Text(
                                year.toString(),
                                style: TextStyle(
                                  fontSize: 20,
                                  color: _selectedYear == year
                                      ? (isDarkMode ? Colors.white : Colors.black)
                                      : (isDarkMode ? Colors.grey[600] : Colors.grey[400]),
                                  fontWeight: _selectedYear == year
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          },
                          onSelectedItemChanged: (index) {
                            setState(() {
                              _selectedYear = currentYear - 13 - index;
                              // Adjust day if needed (for leap years)
                              final daysInMonth = _getDaysInMonth(_selectedYear, _selectedMonth);
                              if (_selectedDay > daysInMonth) {
                                _selectedDay = daysInMonth;
                                _dayController.jumpToItem(_selectedDay - 1);
                              }
                            });
                          },
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Next button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: ElevatedButton(
                  onPressed: _isValidAge() ? _onNextPressed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isValidAge() ? accentColor : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _localeService.get('next'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPicker({
    required FixedExtentScrollController controller,
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    required void Function(int) onSelectedItemChanged,
    required bool isDarkMode,
  }) {
    return Stack(
      children: [
        // Selection indicator
        Center(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                ),
                bottom: BorderSide(
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
            ),
          ),
        ),
        // Picker
        CupertinoPicker.builder(
          scrollController: controller,
          itemExtent: 40,
          onSelectedItemChanged: onSelectedItemChanged,
          childCount: itemCount,
          itemBuilder: itemBuilder,
          selectionOverlay: null,
          backgroundColor: Colors.transparent,
        ),
      ],
    );
  }

  void _onNextPressed() {
    final selectedDate = DateTime(_selectedYear, _selectedMonth, _selectedDay);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UsernameCreationScreen(
          registrationMethod: widget.registrationMethod,
          dateOfBirth: selectedDate,
          oauthData: widget.oauthData,
        ),
      ),
    );
  }
}
