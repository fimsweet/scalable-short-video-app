import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _ChatMediaScreenState extends State<ChatMediaScreen> with SingleTickerProviderStateMixin {
  final MessageService _messageService = MessageService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  
  late TabController _tabController;
  
  // Images data
  List<String> _mediaUrls = [];
  bool _isLoadingImages = true;
  bool _hasMoreImages = true;
  int _imagesOffset = 0;
  
  // Links data  
  List<Map<String, dynamic>> _links = [];
  bool _isLoadingLinks = true;
  
  static const int _limit = 30;
  
  // URL regex pattern
  final RegExp _urlRegex = RegExp(
    r'https?://[^\s<>"{}|\\^`\[\]]+',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _themeService.addListener(_onThemeChanged);
    _loadImages();
    _loadLinks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadImages() async {
    setState(() => _isLoadingImages = true);
    
    try {
      print('DEBUG ChatMediaScreen: ===== LOADING MEDIA =====');
      print('DEBUG ChatMediaScreen: recipientId passed to screen: ${widget.recipientId}');
      print('DEBUG ChatMediaScreen: recipientUsername: ${widget.recipientUsername}');
      print('DEBUG ChatMediaScreen: MessageService currentUserId: ${_messageService.currentUserId}');
      
      if (_messageService.currentUserId == null || _messageService.currentUserId!.isEmpty) {
        print('DEBUG ChatMediaScreen: ERROR - currentUserId is null or empty!');
      }
      
      final messages = await _messageService.getMediaMessages(
        widget.recipientId,
        limit: _limit,
        offset: _imagesOffset,
      );
      
      print('DEBUG ChatMediaScreen: Media messages received: ${messages.length}');
      if (messages.isNotEmpty) {
        print('DEBUG ChatMediaScreen: First message senderId: ${messages[0]['senderId']}, recipientId: ${messages[0]['recipientId']}');
        print('DEBUG ChatMediaScreen: First message conversationId: ${messages[0]['conversationId']}');
      }
      
      final urls = <String>[];
      for (var message in messages) {
        print('DEBUG: Processing message - content: ${message['content']}, imageUrls: ${message['imageUrls']}');
        
        final imageUrls = message['imageUrls'];
        if (imageUrls != null) {
          if (imageUrls is List) {
            for (var url in imageUrls) {
              if (url != null && url.toString().isNotEmpty) {
                final urlStr = url.toString();
                // Check for duplicates against both new list and existing _mediaUrls
                if (!urls.contains(urlStr) && !_mediaUrls.contains(urlStr)) {
                  urls.add(urlStr);
                }
              }
            }
          } else if (imageUrls is String && imageUrls.isNotEmpty) {
            for (var u in imageUrls.split(',')) {
              if (u.isNotEmpty && !urls.contains(u) && !_mediaUrls.contains(u)) {
                urls.add(u);
              }
            }
          }
        }
        
        // Also check content for [IMAGE:...] format
        final content = message['content']?.toString() ?? '';
        if (content.startsWith('[IMAGE:') && content.endsWith(']')) {
          final url = content.substring(7, content.length - 1);
          if (url.isNotEmpty && !urls.contains(url) && !_mediaUrls.contains(url)) {
            print('DEBUG: Found image URL from content: $url');
            urls.add(url);
          }
        }
        
        // Check for stacked images
        if (content.startsWith('[STACKED_IMAGE:') && content.endsWith(']')) {
          final urlsStr = content.substring(15, content.length - 1);
          for (var url in urlsStr.split(',')) {
            if (url.isNotEmpty && !urls.contains(url) && !_mediaUrls.contains(url)) {
              print('DEBUG: Found stacked image URL: $url');
              urls.add(url);
            }
          }
        }
      }
      
      print('DEBUG: Total image URLs found: ${urls.length}');
      
      if (mounted) {
        setState(() {
          _mediaUrls.addAll(urls);
          _hasMoreImages = messages.length >= _limit;
          _isLoadingImages = false;
        });
      }
    } catch (e) {
      print('Error loading media: $e');
      if (mounted) {
        setState(() => _isLoadingImages = false);
      }
    }
  }

  Future<void> _loadLinks() async {
    setState(() => _isLoadingLinks = true);
    
    try {
      final messages = await _messageService.searchMessages(widget.recipientId, 'http');
      
      final links = <Map<String, dynamic>>[];
      for (var message in messages) {
        final content = message['content']?.toString() ?? '';
        final matches = _urlRegex.allMatches(content);
        
        for (var match in matches) {
          final url = match.group(0) ?? '';
          if (url.isNotEmpty) {
            // Don't add image URLs as links
            final lowerUrl = url.toLowerCase();
            if (!lowerUrl.endsWith('.jpg') && 
                !lowerUrl.endsWith('.jpeg') && 
                !lowerUrl.endsWith('.png') && 
                !lowerUrl.endsWith('.gif') &&
                !lowerUrl.contains('/uploads/')) {
              links.add({
                'url': url,
                'content': content,
                'createdAt': message['createdAt'],
                'senderId': message['senderId'],
              });
            }
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _links = links;
          _isLoadingLinks = false;
        });
      }
    } catch (e) {
      print('Error loading links: $e');
      if (mounted) {
        setState(() => _isLoadingLinks = false);
      }
    }
  }

  Future<void> _loadMoreImages() async {
    if (!_hasMoreImages || _isLoadingImages) return;
    _imagesOffset += _limit;
    await _loadImages();
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

  Future<void> _openLink(String url) async {
    // Copy link to clipboard and show snackbar
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _localeService.isVietnamese 
                ? 'Đã sao chép liên kết' 
                : 'Link copied to clipboard',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return url;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays == 0) {
        final hour = date.hour.toString().padLeft(2, '0');
        final minute = date.minute.toString().padLeft(2, '0');
        return '$hour:$minute';
      } else if (diff.inDays < 7) {
        return '${date.day}/${date.month}';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: _themeService.textSecondaryColor,
          indicatorColor: Colors.blue,
          indicatorWeight: 3,
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          tabs: [
            Tab(
              icon: Icon(Icons.photo_library_outlined),
              text: _localeService.isVietnamese ? 'Hình ảnh' : 'Images',
            ),
            Tab(
              icon: Icon(Icons.link),
              text: _localeService.isVietnamese ? 'Liên kết' : 'Links',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildImagesTab(),
          _buildLinksTab(),
        ],
      ),
    );
  }

  Widget _buildImagesTab() {
    if (_isLoadingImages && _mediaUrls.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: Colors.blue),
      );
    }
    
    if (_mediaUrls.isEmpty) {
      return Center(
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
                  : 'No images yet',
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          if (notification.metrics.pixels >= 
              notification.metrics.maxScrollExtent - 200) {
            _loadMoreImages();
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
        itemCount: _mediaUrls.length + (_hasMoreImages ? 1 : 0),
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
    );
  }

  Widget _buildLinksTab() {
    if (_isLoadingLinks) {
      return Center(
        child: CircularProgressIndicator(color: Colors.blue),
      );
    }
    
    if (_links.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_off,
              size: 64,
              color: _themeService.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              _localeService.isVietnamese 
                  ? 'Chưa có liên kết nào' 
                  : 'No links yet',
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _links.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final link = _links[index];
        final url = link['url']?.toString() ?? '';
        final domain = _extractDomain(url);
        
        return InkWell(
          onTap: () => _openLink(url),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _themeService.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _themeService.dividerColor,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.link,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Link info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        domain,
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        url,
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(link['createdAt']?.toString()),
                        style: TextStyle(
                          color: _themeService.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Open icon
                Icon(
                  Icons.open_in_new,
                  color: _themeService.textSecondaryColor,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
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
