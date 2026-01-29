import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/config/app_config.dart';

class ChatMediaScreen extends StatefulWidget {
  final String recipientId;
  final String recipientUsername;

  const ChatMediaScreen({
    super.key,
    required this.recipientId,
    required this.recipientUsername,
  });

  @override
  State<ChatMediaScreen> createState() => _ChatMediaScreenState();
}

class _ChatMediaScreenState extends State<ChatMediaScreen> {
  final MessageService _messageService = MessageService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  
  List<String> _mediaUrls = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 30;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _loadMedia();
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMedia() async {
    setState(() => _isLoading = true);
    
    try {
      final messages = await _messageService.getMediaMessages(
        widget.recipientId,
        limit: _limit,
        offset: _offset,
      );
      
      final urls = <String>[];
      for (var message in messages) {
        final imageUrls = message['imageUrls'];
        if (imageUrls != null) {
          if (imageUrls is List) {
            for (var url in imageUrls) {
              if (url != null && url.toString().isNotEmpty) {
                urls.add(url.toString());
              }
            }
          } else if (imageUrls is String && imageUrls.isNotEmpty) {
            // Handle comma-separated string
            urls.addAll(imageUrls.split(',').where((u) => u.isNotEmpty));
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _mediaUrls.addAll(urls);
          _hasMore = messages.length >= _limit;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading media: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;
    _offset += _limit;
    await _loadMedia();
  }

  String _getFullImageUrl(String url) {
    if (url.startsWith('http')) return url;
    return '${AppConfig.videoServiceUrl}$url';
  }

  void _showImageViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageViewerScreen(
          imageUrls: _mediaUrls.map(_getFullImageUrl).toList(),
          initialIndex: initialIndex,
          themeService: _themeService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: _themeService.textPrimaryColor, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _localeService.isVietnamese ? 'File phương tiện' : 'Media Files',
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading && _mediaUrls.isEmpty
          ? Center(
              child: CircularProgressIndicator(
                color: Colors.blue,
              ),
            )
          : _mediaUrls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 64,
                        color: _themeService.textSecondaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _localeService.isVietnamese 
                            ? 'Chưa có hình ảnh nào' 
                            : 'No media yet',
                        style: TextStyle(
                          color: _themeService.textSecondaryColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollEndNotification) {
                      if (notification.metrics.pixels >= 
                          notification.metrics.maxScrollExtent - 200) {
                        _loadMore();
                      }
                    }
                    return false;
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(2),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: _mediaUrls.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _mediaUrls.length) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: Colors.blue,
                            strokeWidth: 2,
                          ),
                        );
                      }
                      
                      return GestureDetector(
                        onTap: () => _showImageViewer(index),
                        child: Hero(
                          tag: 'media_$index',
                          child: Image.network(
                            _getFullImageUrl(_mediaUrls[index]),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: _themeService.inputBackground,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: _themeService.textSecondaryColor,
                              ),
                            ),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: _themeService.inputBackground,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded / 
                                          progress.expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2,
                                    color: Colors.blue,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _ImageViewerScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final ThemeService themeService;

  const _ImageViewerScreen({
    required this.imageUrls,
    required this.initialIndex,
    required this.themeService,
  });

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Hero(
                tag: 'media_$index',
                child: Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
