class MessageUtils {
  /// Format message content for preview display
  /// Converts special message types to user-friendly text
  static String formatMessagePreview(String? content) {
    if (content == null || content.isEmpty) {
      return '';
    }
    
    // Check if it's a video share message
    if (content.startsWith('[VIDEO_SHARE:') && content.endsWith(']')) {
      return '📹 Đã chia sẻ một video';
    }
    
    // Check for image share
    if (content.startsWith('[IMAGE:') && content.endsWith(']')) {
      return '🖼️ Đã gửi một hình ảnh';
    }
    
    // Check for sticker
    if (content.startsWith('[STICKER:') && content.endsWith(']')) {
      return '😀 Đã gửi một sticker';
    }
    
    // Check for voice message
    if (content.startsWith('[VOICE:') && content.endsWith(']')) {
      return '🎤 Tin nhắn thoại';
    }
    
    // Check for location share
    if (content.startsWith('[LOCATION:') && content.endsWith(']')) {
      return '📍 Đã chia sẻ vị trí';
    }
    
    // Return normal message (truncate if too long)
    if (content.length > 50) {
      return '${content.substring(0, 50)}...';
    }
    
    return content;
  }

  /// Check if message is a special type
  static bool isVideoShare(String content) {
    return content.startsWith('[VIDEO_SHARE:') && content.endsWith(']');
  }

  /// Extract video ID from video share message
  static String? extractVideoId(String content) {
    if (!isVideoShare(content)) return null;
    final start = content.indexOf(':') + 1;
    final end = content.indexOf(']');
    if (start > 0 && end > start) {
      return content.substring(start, end);
    }
    return null;
  }
}
