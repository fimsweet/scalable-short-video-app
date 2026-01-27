import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../services/locale_service.dart';

class SelectInterestsScreen extends StatefulWidget {
  final bool isOnboarding; // true if shown after registration
  
  const SelectInterestsScreen({
    super.key,
    this.isOnboarding = true,
  });

  @override
  State<SelectInterestsScreen> createState() => _SelectInterestsScreenState();
}

class _SelectInterestsScreenState extends State<SelectInterestsScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();

  List<Map<String, dynamic>> _categories = [];
  Set<int> _selectedCategoryIds = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _loadCategories();
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final result = await _apiService.getCategories();
      
      if (result['success']) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _isLoading = false;
        });

        // Load existing interests if editing
        if (!widget.isOnboarding) {
          await _loadExistingInterests();
        }
      } else {
        setState(() {
          _error = result['message'] ?? 'Failed to load categories';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadExistingInterests() async {
    try {
      final user = _authService.user;
      if (user == null) return;

      final result = await _apiService.getUserInterests(user['id']);
      
      if (result['success']) {
        final interests = List<Map<String, dynamic>>.from(result['data'] ?? []);
        setState(() {
          _selectedCategoryIds = interests
              .map((i) => i['categoryId'] as int)
              .toSet();
        });
      }
    } catch (e) {
      print('Error loading existing interests: $e');
    }
  }

  void _toggleCategory(int categoryId) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });
  }

  Future<void> _saveInterests() async {
    if (_selectedCategoryIds.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_localeService.get('select_at_least_3_interests')),
          backgroundColor: ThemeService.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = _authService.user;
      if (user == null) {
        throw Exception('User not found');
      }

      final token = await _authService.getToken();
      final result = await _apiService.setUserInterests(
        user['id'],
        _selectedCategoryIds.toList(),
        token ?? '',
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (result['success']) {
          if (widget.isOnboarding) {
            // Navigate to main screen after onboarding (no snackbar)
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          } else {
            // Show snackbar only when editing interests from settings
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_localeService.get('interests_saved')),
                backgroundColor: ThemeService.successColor,
              ),
            );
            Navigator.of(context).pop(true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to save interests'),
              backgroundColor: ThemeService.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: ThemeService.errorColor,
          ),
        );
      }
    }
  }

  String _getCategoryDisplayName(Map<String, dynamic> category) {
    if (_localeService.currentLocale == 'vi' && category['displayNameVi'] != null) {
      return category['displayNameVi'];
    }
    return category['displayName'] ?? category['name'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      body: SafeArea(
        child: _buildBody(),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: ThemeService.accentColor,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: ThemeService.errorColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: ThemeService.errorColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _error!,
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadCategories,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(_localeService.get('retry')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeService.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          // Title
          Text(
            _localeService.get('what_interests_you'),
            style: TextStyle(
              color: _themeService.textPrimaryColor,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _localeService.get('select_interests_description'),
            style: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // Progress indicator
          _buildProgressIndicator(),
          const SizedBox(height: 24),
          
          // Categories as Chips (Wrap layout)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _categories.map((category) {
              final isSelected = _selectedCategoryIds.contains(category['id']);
              return _buildCategoryChip(category, isSelected);
            }).toList(),
          ),
          
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(Map<String, dynamic> category, bool isSelected) {
    final displayName = _getCategoryDisplayName(category);
    final icon = category['icon'] ?? '🎬';

    return GestureDetector(
      onTap: () => _toggleCategory(category['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? ThemeService.accentColor.withOpacity(0.12)
              : _themeService.cardColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected
                ? ThemeService.accentColor
                : _themeService.dividerColor.withOpacity(0.6),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: ThemeService.accentColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 8),
            Text(
              displayName,
              style: TextStyle(
                color: isSelected
                    ? ThemeService.accentColor
                    : _themeService.textPrimaryColor,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final progress = math.min(_selectedCategoryIds.length / 3, 1.0);
    final isComplete = _selectedCategoryIds.length >= 3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isComplete
            ? ThemeService.successColor.withOpacity(0.1)
            : _themeService.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete
              ? ThemeService.successColor.withOpacity(0.3)
              : _themeService.dividerColor,
        ),
      ),
      child: Row(
        children: [
          // Circular progress
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: _themeService.dividerColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isComplete ? ThemeService.successColor : ThemeService.accentColor,
                  ),
                ),
                Text(
                  '${_selectedCategoryIds.length}',
                  style: TextStyle(
                    color: isComplete
                        ? ThemeService.successColor
                        : ThemeService.accentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isComplete
                      ? _localeService.get('great_choices')
                      : '${_localeService.get('selected')}: ${_selectedCategoryIds.length}/3',
                  style: TextStyle(
                    color: isComplete
                        ? ThemeService.successColor
                        : _themeService.textPrimaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isComplete
                      ? _localeService.get('add_more_if_you_want')
                      : _localeService.get('pick_3_to_continue'),
                  style: TextStyle(
                    color: _themeService.textSecondaryColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (isComplete)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThemeService.successColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isComplete = _selectedCategoryIds.length >= 3;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: _themeService.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Continue button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: isComplete && !_isSaving ? _saveInterests : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeService.accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _themeService.dividerColor,
                disabledForegroundColor: _themeService.textSecondaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.isOnboarding
                              ? _localeService.get('continue')
                              : _localeService.get('save'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (isComplete) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ],
                    ),
            ),
          ),
          // Skip button for onboarding
          if (widget.isOnboarding) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                // Skip for now - go to main screen
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                _localeService.get('skip_for_now'),
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
