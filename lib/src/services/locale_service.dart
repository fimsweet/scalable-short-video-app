import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';

class LocaleService extends ChangeNotifier {
  static final LocaleService _instance = LocaleService._internal();
  factory LocaleService() => _instance;
  LocaleService._internal() {
    print('🌐 LocaleService._internal() constructor called - registering listeners');
    _authService.addLogoutListener(_onLogout);
    _authService.addLoginListener(_onLogin);
    print('✅ LocaleService listeners registered');
  }

  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  String _currentLocale = 'vi';
  
  String get currentLocale => _currentLocale;
  bool get isVietnamese => _currentLocale == 'vi';
  bool get isEnglish => _currentLocale == 'en';

  void _onLogin() {
    // Load language from backend when user logs in
    print('👤 Login detected in LocaleService - loading language from backend');
    _loadLanguageFromBackend().catchError((error) {
      print('❌ Error in _onLogin while loading language: $error');
    });
  }

  void _onLogout() {
    // Reset to Vietnamese when user logs out
    print('🌐 Logout detected - resetting to Vietnamese');
    _currentLocale = 'vi';
    SharedPreferences.getInstance().then((prefs) async {
      await prefs.setString('app_locale', 'vi');
      print('💾 Vietnamese locale saved to storage');
    });
    notifyListeners();
    print('📢 Locale listeners notified - currentLocale: $_currentLocale');
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLocale = prefs.getString('app_locale') ?? 'vi';
    print('🌐 LocaleService initialized - local locale: $_currentLocale');
    notifyListeners();
  }

  Future<void> _loadLanguageFromBackend() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        print('⚠️ No token found, skipping backend language load');
        return;
      }

      print('🔄 Loading language from backend...');
      final response = await _apiService.getUserSettings(token);
      print('📦 Backend language response: $response');
      
      if (response['success'] == true && response['settings'] != null) {
        final language = response['settings']['language'] as String?;
        if (language != null && language.isNotEmpty) {
          final wasLocale = _currentLocale;
          _currentLocale = language;
          
          // Save to local storage
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('app_locale', language);
          
          print('✅ Language loaded from backend: $language (changed from $wasLocale to $_currentLocale)');
          
          // Notify listeners if locale changed
          if (wasLocale != _currentLocale) {
            print('📢 Locale changed - notifying listeners');
            notifyListeners();
          }
        }
      }
    } catch (e, stackTrace) {
      print('⚠️ Failed to load language from backend: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Load language from backend settings (called after login)
  Future<void> loadFromBackend(String? language) async {
    if (language != null && language.isNotEmpty && language != _currentLocale) {
      _currentLocale = language;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_locale', language);
      notifyListeners();
      print('✅ LocaleService: Loaded language from backend: $language');
    }
  }

  Future<void> setLocale(String locale) async {
    if (_currentLocale == locale) return;
    
    _currentLocale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', locale);
    
    // Sync to backend if user is logged in
    if (_authService.isLoggedIn) {
      _syncLanguageToBackend(locale);
    }
    
    notifyListeners();
  }

  Future<void> _syncLanguageToBackend(String language) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      await _apiService.updateUserSettings(token, {
        'language': language,
      });
      print('✅ Language synced to backend: $language');
    } catch (e) {
      print('⚠️ Failed to sync language to backend: $e');
    }
  }

  String get(String key) {
    final translations = _currentLocale == 'vi' ? _viTranslations : _enTranslations;
    return translations[key] ?? key;
  }

  // Vietnamese translations
  static const Map<String, String> _viTranslations = {
    // Common
    'app_name': 'ShortVideo',
    'save': 'Lưu',
    'cancel': 'Hủy',
    'confirm': 'Xác nhận',
    'delete': 'Xóa',
    'edit': 'Chỉnh sửa',
    'back': 'Quay lại',
    'done': 'Xong',
    'loading': 'Đang tải...',
    'error': 'Lỗi',
    'success': 'Thành công',
    'ok': 'OK',
    'yes': 'Có',
    'no': 'Không',
    'search': 'Tìm kiếm',
    'search_hint': 'Tìm kiếm video, người dùng...',
    'recent_searches': 'Tìm kiếm gần đây',
    'clear_history': 'Xóa lịch sử',
    'no_results': 'Không tìm thấy kết quả',
    'videos_tab': 'Video',
    'users_tab': 'Tài khoản',
    'following_tab': 'Đã follow',
    'for_you_tab': 'Đề xuất',
    'friends_tab': 'Bạn bè',
    'suggested_for_you': 'Bạn có thể thích',
    'see_more': 'Xem thêm',
    'refresh': 'Làm mới',
    'settings': 'Cài đặt',
    'profile': 'Hồ sơ',
    'home': 'Trang chủ',
    'messages': 'Tin nhắn',
    'notifications': 'Thông báo',
    'help': 'Trợ giúp',

    // Auth
    'login': 'Đăng nhập',
    'logout': 'Đăng xuất',
    'register': 'Đăng ký',
    'email': 'Email',
    'password': 'Mật khẩu',
    'username': 'Tên người dùng',
    'forgot_password': 'Quên mật khẩu?',
    'login_success': 'Đăng nhập thành công',
    'please_login': 'Vui lòng đăng nhập',
    
    // Forgot Password
    'forgot_password_description': 'Nhập địa chỉ email của bạn và chúng tôi sẽ gửi mã xác nhận để đặt lại mật khẩu.',
    'send_code': 'Gửi mã xác nhận',
    'reset_code_sent': 'Mã xác nhận đã được gửi đến email của bạn',
    'enter_verification_code_desc': 'Nhập mã 6 chữ số đã được gửi đến email của bạn.',
    'invalid_code': 'Mã xác nhận không hợp lệ',
    'verify': 'Xác nhận',
    'resend_code': 'Gửi lại mã',
    'create_new_password_desc': 'Tạo mật khẩu mới cho tài khoản của bạn.',
    'reset_password': 'Đặt lại mật khẩu',
    'password_reset_success': 'Mật khẩu đã được đặt lại thành công',
    'change': 'Thay đổi',
    
    // Registration
    'full_name': 'Họ và tên',
    'phone_number': 'Số điện thoại',
    'date_of_birth': 'Ngày sinh',
    'confirm_password': 'Xác nhận mật khẩu',
    'please_enter_full_name': 'Vui lòng nhập họ và tên',
    'please_enter_phone': 'Vui lòng nhập số điện thoại',
    'invalid_phone': 'Số điện thoại không hợp lệ',
    'please_select_dob': 'Vui lòng chọn ngày sinh',
    'must_be_13_years': 'Bạn phải đủ 13 tuổi để đăng ký',
    'passwords_not_match': 'Mật khẩu không khớp',
    'password_requirements': 'Mật khẩu phải có ít nhất 8 ký tự, bao gồm chữ hoa, chữ thường và số',
    'username_requirements': 'Tên người dùng chỉ chứa chữ cái, số và dấu gạch dưới',
    'optional': '(Tùy chọn)',
    'required_fields': 'Các trường bắt buộc',
    'select_date': 'Chọn ngày',
    'whats_your_birthday': 'Ngày sinh của bạn là?',
    'birthday_description': 'Chúng tôi sẽ không hiển thị thông tin này công khai. Bạn cần ít nhất 13 tuổi để đăng ký.',
    'create_username': 'Tạo tên người dùng',
    'username_description': 'Bạn có thể thay đổi tên người dùng sau. Chọn tên dễ nhớ nhé!',
    'email_hint': 'email@example.com',
    'select_birthday': 'Chọn ngày sinh',
    'sign_up': 'Đăng ký',
    'terms_agree_prefix': 'Khi tiếp tục, bạn đồng ý với ',
    'terms_of_service': 'Điều khoản dịch vụ',
    'and': ' và ',
    'privacy_policy': 'Chính sách bảo mật',
    'additional_info': 'Thông tin bổ sung',

    // Profile
    'edit_profile': 'Sửa hồ sơ',
    'view_profile': 'Xem hồ sơ',
    'bio': 'Tiểu sử',
    'website': 'Website',
    'location': 'Vị trí',
    'gender': 'Giới tính',
    'male': 'Nam',
    'female': 'Nữ',
    'other': 'Khác',
    'prefer_not_to_say': 'Không muốn tiết lộ',
    'select_gender': 'Chọn giới tính',
    'basic_info': 'Thông tin cơ bản',
    'change_photo': 'Thay đổi ảnh',
    'following': 'Đang follow',
    'followers': 'Follower',
    'likes': 'Thích',
    'follow': 'Follow',
    'unfollow': 'Bỏ follow',
    'friends': 'Bạn bè',
    'message': 'Nhắn tin',
    'share_profile': 'Chia sẻ trang cá nhân',
    'no_videos': 'Chưa có video nào',
    'update_success': 'Cập nhật thông tin thành công!',
    'update_failed': 'Cập nhật thất bại',
    'avatar_update_success': 'Cập nhật ảnh đại diện thành công!',

    // Settings
    'account': 'Tài khoản',
    'account_settings': 'Cài đặt tài khoản',
    'account_management': 'Quản lý tài khoản',
    'account_management_subtitle': 'Bảo mật, mật khẩu, xóa tài khoản',
    'my_profile': 'Hồ sơ cá nhân',
    'privacy': 'Quyền riêng tư',
    'private_account': 'Tài khoản riêng tư',
    'private_account_desc': 'Chỉ người theo dõi mới có thể xem video của bạn',
    'who_can_view_videos': 'Ai có thể xem video của bạn',
    'who_can_send_messages': 'Ai có thể gửi tin nhắn cho bạn',
    'who_can_comment': 'Ai có thể bình luận',
    'comments': 'Bình luận',
    'filter_comments': 'Lọc bình luận',
    'filter_comments_desc': 'Tự động ẩn các bình luận có thể gây khó chịu',
    'push_notifications': 'Thông báo đẩy',
    'push_notifications_desc': 'Nhận thông báo về hoạt động mới',
    'content_display': 'Nội dung và hiển thị',
    'light_mode': 'Chế độ sáng',
    'light_mode_desc': 'Chuyển đổi giữa giao diện sáng và tối',
    'language': 'Ngôn ngữ',
    'vietnamese': 'Tiếng Việt',
    'english': 'English',
    'everyone': 'Mọi người',
    'no_one': 'Không ai',
    'only_me': 'Chỉ mình tôi',
    'updated': 'Đã cập nhật',
    'enabled': 'Đã bật',
    'disabled': 'Đã tắt',
    'private_account_enabled': 'Đã bật tài khoản riêng tư',
    'private_account_disabled': 'Đã tắt tài khoản riêng tư',
    'filter_comments_enabled': 'Đã bật lọc bình luận',
    'filter_comments_disabled': 'Đã tắt lọc bình luận',
    'push_notifications_enabled': 'Đã bật thông báo đẩy',
    'push_notifications_disabled': 'Đã tắt thông báo đẩy',
    'light_mode_enabled': 'Đã bật chế độ sáng',
    'dark_mode_enabled': 'Đã bật chế độ tối',
    'who_can_view_videos_title': 'Ai có thể xem video của bạn',
    'who_can_send_messages_title': 'Ai có thể gửi tin nhắn cho bạn',
    'who_can_comment_title': 'Ai có thể bình luận video của bạn',

    // Change Password
    'change_password': 'Đổi mật khẩu',
    'change_password_subtitle': 'Cập nhật mật khẩu của bạn',
    'current_password': 'Mật khẩu hiện tại',
    'new_password': 'Mật khẩu mới',
    'confirm_new_password': 'Xác nhận mật khẩu mới',
    'password_change_success': 'Đổi mật khẩu thành công',
    'password_change_failed': 'Đổi mật khẩu thất bại',
    'password_mismatch': 'Mật khẩu xác nhận không khớp',
    'password_too_short': 'Mật khẩu mới phải có ít nhất 8 ký tự',
    'fill_all_fields': 'Vui lòng điền đầy đủ thông tin',
    'session_expired': 'Phiên đăng nhập hết hạn',

    // Security
    'security': 'Bảo mật',
    'two_factor_auth': 'Xác thực hai yếu tố',
    'biometric_login': 'Đăng nhập sinh trắc học',
    'devices': 'Thiết bị đã đăng nhập',
    'devices_subtitle': 'Quản lý các thiết bị đã đăng nhập',

    // Account Info
    'account_info': 'Thông tin tài khoản',
    'not_linked': 'Chưa liên kết',

    // Delete Account
    'delete_account': 'Xóa tài khoản',
    'delete_account_warning': 'Hành động này không thể hoàn tác',

    // Chat
    'chat_options': 'Tùy chọn',
    'mute_notifications': 'Tắt thông báo',
    'muted': 'Đã tắt',
    'unmuted': 'Đang bật',
    'pin_conversation': 'Ghim lên đầu',
    'pinned': 'Đã ghim',
    'not_pinned': 'Chưa ghim',
    'block': 'Chặn',
    'block_user': 'Chặn người dùng',
    'block_user_desc': 'Chặn người dùng này',
    'unblock': 'Bỏ chặn',
    'unblock_user': 'Bỏ chặn người dùng',
    'blocked_list': 'Danh sách chặn',
    'blocked_list_subtitle': 'Quản lý người dùng đã chặn',
    'block_confirm': 'Bạn có chắc muốn chặn',
    'block_effects': 'Họ sẽ không thể:\n• Gửi tin nhắn cho bạn\n• Xem trang cá nhân của bạn\n• Tìm thấy bạn trong tìm kiếm',
    'unblock_confirm': 'Bạn có chắc muốn bỏ chặn',
    'unblock_effects': 'Họ sẽ có thể gửi tin nhắn cho bạn.',
    'blocked_success': 'Đã chặn',
    'unblocked_success': 'Đã bỏ chặn',
    'block_failed': 'Không thể chặn người dùng',
    'unblock_failed': 'Không thể bỏ chặn người dùng',
    'settings_update_failed': 'Không thể cập nhật cài đặt',
    'user_not_found': 'Không tìm thấy người dùng',
    'type_message': 'Nhắn tin...',
    'send': 'Gửi',
    'inbox': 'Hộp thư',
    'online': 'Đang hoạt động',
    'offline': 'Ngoại tuyến',
    'tap_to_view': 'Nhấn để xem',
    'sent': 'Đã gửi',
    'you': 'Bạn',
    'commented': 'đã bình luận',
    'no_notifications': 'Chưa có thông báo nào',
    'no_messages': 'Chưa có tin nhắn nào',
    'no_blocked_users': 'Không có người dùng nào bị chặn',
    'blocked_users_hint': 'Khi bạn chặn ai đó, họ sẽ xuất hiện ở đây',
    'blocked': 'Đã chặn',
    'you_blocked_user': 'Bạn đã chặn người dùng này.',
    'cannot_contact': 'Hiện tại không thể liên lạc với người này',
    'unblocked_user_success': 'Bạn đã bỏ chặn',
    'allow_contact': 'Cho phép người này liên hệ với bạn',

    // Video
    'upload_video': 'Đăng video',
    'video_description': 'Mô tả video',
    'posting': 'Đang đăng...',
    'post': 'Đăng',
    'views': 'lượt xem',
    'like': 'Thích',
    'comment': 'Bình luận',
    'share': 'Chia sẻ',
    'share_to': 'Chia sẻ đến',
    'please_select_at_least_one': 'Vui lòng chọn ít nhất một người',
    'selected_x_people': 'Đã chọn',
    'people': 'người',
    'shared_to_x_people': 'Đã chia sẻ cho',
    'cannot_share_video': 'Không thể chia sẻ video',
    'no_followers_yet': 'Chưa có người theo dõi',
    'no_results_found': 'Không tìm thấy kết quả',
    'confirm_share': 'Xác nhận chia sẻ',
    'share_video_to': 'Chia sẻ video này đến',
    'and_x_others': 'và',
    'others': 'người khác',
    'clear': 'Xóa',
    'please_login_to_follow': 'Vui lòng đăng nhập để theo dõi',
    'report': 'Báo cáo',
    'delete_video': 'Xóa video',
    'delete_video_confirm': 'Bạn có chắc muốn xóa video này?',
    'video_deleted': 'Đã xóa video',
    'video_delete_failed': 'Không thể xóa video',
    'select_video_from_library': 'Chọn video từ thư viện',
    'max_size_format': 'Tối đa 500MB • MP4, MOV, AVI',
    'tap_to_select_video': 'Nhấn để chọn video',
    'video_selected': 'Video đã chọn',
    'select_another_video': 'Chọn video khác',
    'uploading': 'Đang upload...',
    'video_uploaded': 'Video đã được tải lên!',
    'video_processing': 'Video của bạn đang được xử lý và sẽ xuất hiện sớm thôi!',
    'close': 'Đóng',
    'upload_failed': 'Upload thất bại',
    'video_format_not_supported': 'Định dạng video không được hỗ trợ',
    'video_max_size': 'Kích thước video tối đa 500MB',
    'error_selecting_video': 'Lỗi chọn video',
    'please_select_video': 'Vui lòng chọn video',
    'please_login_again': 'Vui lòng đăng nhập lại',
    'describe_your_video': 'Kể về video của bạn...',
    'please_enter_description': 'Vui lòng nhập mô tả cho video',
    'loading_video': 'Đang tải video...',
    'no_videos_following': 'Chưa có video từ người bạn theo dõi',
    'no_videos_yet': 'Chưa có video nào',
    'cannot_load_video': 'Không thể tải video. Vui lòng thử lại.',
    'follow_others_hint': 'Hãy theo dõi người khác để xem video của họ!',
    'be_first_upload': 'Hãy là người đầu tiên upload video!',
    'reload': 'Tải lại',
    'following_status': 'Đang theo dõi',

    // Comments
    'add_comment': 'Thêm bình luận...',
    'no_comments': 'Chưa có bình luận nào',
    'reply': 'Trả lời',
    'delete_comment': 'Xóa bình luận',
    'need_login_to_comment': 'Bạn cần đăng nhập để bình luận',
    'replying_to': 'Đang trả lời',
    'be_first_comment': 'Hãy là người đầu tiên bình luận!',
    'x_comments': 'bình luận',
    'pinned_by_author': 'Ghim bởi tác giả',
    'comment_error': 'Lỗi gửi bình luận',
    'please_login_to_comment': 'Vui lòng đăng nhập để bình luận',

    // Chat
    'typing': 'Đang nhập...',
    'add': 'Thêm',
    'add_message': 'Thêm tin nhắn...',
    'emoji': 'Biểu tượng cảm xúc',
    'sending': 'Đang gửi',
    'seen': 'Đã xem',
    'not_available': 'Không khả dụng',
    'video_not_exist': 'Video không còn tồn tại',
    'cannot_open_video': 'Không thể mở video',
    'cannot_select_image': 'Không thể chọn ảnh',
    'cannot_take_photo': 'Không thể chụp ảnh',
    'cannot_load_image': 'Không thể tải ảnh',

    // Errors
    'network_error': 'Không thể kết nối đến server',
    'unknown_error': 'Đã xảy ra lỗi',
    'try_again': 'Thử lại',
    'server_connection_error': 'Không thể kết nối đến máy chủ. Vui lòng thử lại.',
    'change_password_failed': 'Đổi mật khẩu thất bại',

    // Two Factor Auth
    'select_2fa_method': 'Chọn phương thức xác thực:',
    'sms_subtitle': 'Nhận mã qua tin nhắn',
    'email_subtitle': 'Nhận mã qua email',
    'authenticator_app': 'Ứng dụng xác thực',
    '2fa_sms_enabled': 'Đã bật xác thực qua SMS',
    '2fa_email_enabled': 'Đã bật xác thực qua Email',
    '2fa_app_enabled': 'Đã bật xác thực qua ứng dụng',

    // Account Management
    'security_section': 'Bảo mật',
    'two_factor_on': 'Đang bật - Bảo vệ tài khoản với xác thực 2 lớp',
    'two_factor_off': 'Tắt - Bật để bảo vệ tài khoản của bạn',
    'biometric_desc': 'Đăng nhập bằng vân tay hoặc FaceID',
    'login_alert': 'Cảnh báo đăng nhập',
    'login_alert_desc': 'Thông báo khi có đăng nhập mới',
    'not_set': 'Chưa cài đặt',
    'data_privacy': 'Dữ liệu & Quyền riêng tư',
    'download_data': 'Tải dữ liệu của bạn',
    'download_data_desc': 'Tải xuống bản sao dữ liệu cá nhân',
    'activity_history': 'Lịch sử hoạt động',
    'activity_history_desc': 'Xem lịch sử hoạt động của bạn',
    'danger_zone': 'Vùng nguy hiểm',
    'deactivate_account': 'Vô hiệu hóa tài khoản',
    'deactivate_account_desc': 'Tạm thời vô hiệu hóa tài khoản',
    'delete_account_desc': 'Xóa vĩnh viễn tài khoản và dữ liệu',
    'feature_developing': 'Tính năng đang phát triển',
    'action_cannot_undo': 'Hành động này không thể hoàn tác!',
    'delete_permanently': 'Xóa vĩnh viễn',
    'logout_confirm': 'Bạn chắc chắn muốn đăng xuất?',
    'request': 'Yêu cầu',

    // Edit Profile
    'name': 'Tên',
    'add_name': 'Thêm Tên',
    'add_bio': 'Thêm tiểu sử để giới thiệu về bạn',
    'add_website': 'Thêm đường dẫn website',
    'add_location': 'Thêm vị trí của bạn',

    // Followers/Following
    'no_followers': 'Chưa có người theo dõi',
    'no_following': 'Chưa theo dõi ai',
    'posts': 'Bài viết',
    'no_posts': 'Chưa có bài viết',

    // Login
    'please_enter_email': 'Vui lòng nhập email',
    'invalid_email': 'Email không hợp lệ',
    'please_enter_password': 'Vui lòng nhập mật khẩu',
    'login_failed': 'Đăng nhập thất bại',
    'or_login_with': 'Hoặc đăng nhập bằng',
    'facebook': 'Facebook',
    'google': 'Google',
    'phone': 'Số ĐT',
    'no_account': 'Chưa có tài khoản? ',
    'have_account': 'Đã có tài khoản? ',

    // Register
    'please_enter_username': 'Vui lòng nhập tên đăng nhập',
    'username_min_length': 'Tên đăng nhập phải có ít nhất 3 ký tự',
    'password_min_length': 'Mật khẩu phải có ít nhất 6 ký tự',
    'register_success': 'Đăng ký thành công!',
    'register_failed': 'Đăng ký thất bại',
    'create_account': 'Tạo tài khoản',

    // Video Detail
    'invalid_video': 'Video không hợp lệ',
    'video_unavailable': 'Video không khả dụng',

    // Login Required Dialog
    'login_required': 'Cần đăng nhập',
    'login_to_like': 'Đăng nhập để thích video này',
    'login_to_share': 'Đăng nhập để chia sẻ video này',
    'login_to_post': 'Đăng nhập để đăng video',
    'login_to_save': 'Đăng nhập để lưu video này',
    'login_to_follow': 'Đăng nhập để theo dõi người dùng này',
    'login_to_comment': 'Đăng nhập để bình luận',
    'login_to_view_profile': 'Đăng nhập để xem hồ sơ',
    'follow_others_like_videos': 'Theo dõi người khác, thích video và tạo nội dung của riêng bạn.',
    'continue_as_guest': 'Tiếp tục xem với chế độ khách',
  };

  // English translations
  static const Map<String, String> _enTranslations = {
    // Common
    'app_name': 'ShortVideo',
    'save': 'Save',
    'cancel': 'Cancel',
    'confirm': 'Confirm',
    'delete': 'Delete',
    'edit': 'Edit',
    'back': 'Back',
    'done': 'Done',
    'loading': 'Loading...',
    'error': 'Error',
    'success': 'Success',
    'ok': 'OK',
    'yes': 'Yes',
    'no': 'No',
    'search': 'Search',
    'search_hint': 'Search videos, users...',
    'recent_searches': 'Recent searches',
    'clear_history': 'Clear history',
    'no_results': 'No results found',
    'videos_tab': 'Videos',
    'users_tab': 'Accounts',
    'following_tab': 'Following',
    'for_you_tab': 'For You',
    'friends_tab': 'Friends',
    'suggested_for_you': 'You may like',
    'see_more': 'See more',
    'refresh': 'Refresh',
    'settings': 'Settings',
    'profile': 'Profile',
    'home': 'Home',
    'messages': 'Messages',
    'notifications': 'Notifications',
    'help': 'Help',

    // Auth
    'login': 'Login',
    'logout': 'Logout',
    'register': 'Register',
    'email': 'Email',
    'password': 'Password',
    'username': 'Username',
    'forgot_password': 'Forgot password?',
    'login_success': 'Login successful',
    'please_login': 'Please login',
    
    // Forgot Password
    'forgot_password_description': 'Enter your email address and we will send you a verification code to reset your password.',
    'send_code': 'Send Code',
    'reset_code_sent': 'Verification code has been sent to your email',
    'enter_verification_code_desc': 'Enter the 6-digit code sent to your email.',
    'invalid_code': 'Invalid verification code',
    'verify': 'Verify',
    'resend_code': 'Resend Code',
    'create_new_password_desc': 'Create a new password for your account.',
    'reset_password': 'Reset Password',
    'password_reset_success': 'Password has been reset successfully',
    'change': 'Change',
    
    // Registration
    'full_name': 'Full Name',
    'phone_number': 'Phone Number',
    'date_of_birth': 'Date of Birth',
    'confirm_password': 'Confirm Password',
    'please_enter_full_name': 'Please enter your full name',
    'please_enter_phone': 'Please enter your phone number',
    'invalid_phone': 'Invalid phone number',
    'please_select_dob': 'Please select your date of birth',
    'must_be_13_years': 'You must be at least 13 years old to register',
    'passwords_not_match': 'Passwords do not match',
    'password_requirements': 'Password must be at least 8 characters with uppercase, lowercase and number',
    'username_requirements': 'Username can only contain letters, numbers and underscores',
    'optional': '(Optional)',
    'required_fields': 'Required fields',
    'select_date': 'Select date',
    'whats_your_birthday': 'When\'s your birthday?',
    'birthday_description': 'Your birthday won\'t be shown publicly. You need to be at least 13 to sign up.',
    'create_username': 'Create username',
    'username_description': 'You can always change this later. Pick something memorable!',
    'email_hint': 'email@example.com',
    'select_birthday': 'Select your birthday',
    'sign_up': 'Sign up',
    'terms_agree_prefix': 'By continuing, you agree to our ',
    'terms_of_service': 'Terms of Service',
    'and': ' and ',
    'privacy_policy': 'Privacy Policy',

    // Profile
    'edit_profile': 'Edit Profile',
    'view_profile': 'View Profile',
    'bio': 'Bio',
    'website': 'Website',
    'location': 'Location',
    'gender': 'Gender',
    'male': 'Male',
    'female': 'Female',
    'other': 'Other',
    'prefer_not_to_say': 'Prefer not to say',
    'select_gender': 'Select gender',
    'basic_info': 'Basic Info',
    'additional_info': 'Additional Info',
    'change_photo': 'Change Photo',
    'following': 'Following',
    'followers': 'Followers',
    'likes': 'Likes',
    'follow': 'Follow',
    'unfollow': 'Unfollow',
    'friends': 'Friends',
    'message': 'Message',
    'share_profile': 'Share Profile',
    'no_videos': 'No videos yet',
    'update_success': 'Profile updated successfully!',
    'update_failed': 'Update failed',
    'avatar_update_success': 'Avatar updated successfully!',

    // Settings
    'account': 'Account',
    'account_settings': 'Account Settings',
    'account_management': 'Account Management',
    'account_management_subtitle': 'Security, password, delete account',
    'my_profile': 'My Profile',
    'privacy': 'Privacy',
    'private_account': 'Private Account',
    'private_account_desc': 'Only followers can see your videos',
    'who_can_view_videos': 'Who can view your videos',
    'who_can_send_messages': 'Who can send you messages',
    'who_can_comment': 'Who can comment',
    'comments': 'Comments',
    'filter_comments': 'Filter Comments',
    'filter_comments_desc': 'Automatically hide potentially offensive comments',
    'push_notifications': 'Push Notifications',
    'push_notifications_desc': 'Receive notifications about new activities',
    'content_display': 'Content & Display',
    'light_mode': 'Light Mode',
    'light_mode_desc': 'Switch between light and dark theme',
    'language': 'Language',
    'vietnamese': 'Vietnamese',
    'english': 'English',
    'everyone': 'Everyone',
    'no_one': 'No one',
    'only_me': 'Only me',
    'updated': 'Updated',
    'enabled': 'Enabled',
    'disabled': 'Disabled',
    'private_account_enabled': 'Private account enabled',
    'private_account_disabled': 'Private account disabled',
    'filter_comments_enabled': 'Comment filter enabled',
    'filter_comments_disabled': 'Comment filter disabled',
    'push_notifications_enabled': 'Push notifications enabled',
    'push_notifications_disabled': 'Push notifications disabled',
    'light_mode_enabled': 'Light mode enabled',
    'dark_mode_enabled': 'Dark mode enabled',
    'who_can_view_videos_title': 'Who can view your videos',
    'who_can_send_messages_title': 'Who can send you messages',
    'who_can_comment_title': 'Who can comment on your videos',

    // Change Password
    'change_password': 'Change Password',
    'change_password_subtitle': 'Update your password',
    'current_password': 'Current Password',
    'new_password': 'New Password',
    'confirm_new_password': 'Confirm New Password',
    'password_change_success': 'Password changed successfully',
    'password_change_failed': 'Password change failed',
    'password_mismatch': 'Passwords do not match',
    'password_too_short': 'New password must be at least 8 characters',
    'fill_all_fields': 'Please fill in all fields',
    'session_expired': 'Session expired',

    // Security
    'security': 'Security',
    'two_factor_auth': 'Two-Factor Authentication',
    'biometric_login': 'Biometric Login',
    'devices': 'Logged in Devices',
    'devices_subtitle': 'Manage your logged in devices',

    // Account Info
    'account_info': 'Account Information',
    'not_linked': 'Not linked',

    // Delete Account
    'delete_account': 'Delete Account',
    'delete_account_warning': 'This action cannot be undone',

    // Chat
    'chat_options': 'Options',
    'mute_notifications': 'Mute Notifications',
    'muted': 'Muted',
    'unmuted': 'Unmuted',
    'pin_conversation': 'Pin Conversation',
    'pinned': 'Pinned',
    'not_pinned': 'Not pinned',
    'block': 'Block',
    'block_user': 'Block User',
    'block_user_desc': 'Block this user',
    'unblock': 'Unblock',
    'unblock_user': 'Unblock User',
    'blocked_list': 'Blocked List',
    'blocked_list_subtitle': 'Manage blocked users',
    'block_confirm': 'Are you sure you want to block',
    'block_effects': 'They will not be able to:\n• Send you messages\n• View your profile\n• Find you in search',
    'unblock_confirm': 'Are you sure you want to unblock',
    'unblock_effects': 'They will be able to send you messages.',
    'blocked_success': 'Blocked',
    'unblocked_success': 'Unblocked',
    'block_failed': 'Could not block user',
    'unblock_failed': 'Could not unblock user',
    'settings_update_failed': 'Could not update settings',
    'user_not_found': 'User not found',
    'type_message': 'Message...',
    'send': 'Send',
    'inbox': 'Inbox',
    'online': 'Online',
    'offline': 'Offline',
    'tap_to_view': 'Tap to view',
    'sent': 'Sent',
    'you': 'You',
    'commented': 'commented',
    'no_notifications': 'No notifications yet',
    'no_messages': 'No messages yet',
    'no_blocked_users': 'No blocked users',
    'blocked_users_hint': 'When you block someone, they will appear here',
    'blocked': 'Blocked',
    'you_blocked_user': 'You blocked this user.',
    'cannot_contact': 'Cannot contact this person right now',
    'unblocked_user_success': 'You unblocked',
    'allow_contact': 'Allow this person to contact you',

    // Video
    'upload_video': 'Upload Video',
    'video_description': 'Video Description',
    'posting': 'Posting...',
    'post': 'Post',
    'views': 'views',
    'like': 'Like',
    'comment': 'Comment',
    'share': 'Share',
    'share_to': 'Share to',
    'please_select_at_least_one': 'Please select at least one person',
    'selected_x_people': 'Selected',
    'people': 'people',
    'shared_to_x_people': 'Shared to',
    'cannot_share_video': 'Cannot share video',
    'no_followers_yet': 'No followers yet',
    'no_results_found': 'No results found',
    'confirm_share': 'Confirm share',
    'share_video_to': 'Share this video to',
    'and_x_others': 'and',
    'others': 'others',
    'clear': 'Clear',
    'please_login_to_follow': 'Please login to follow',
    'report': 'Report',
    'delete_video': 'Delete Video',
    'delete_video_confirm': 'Are you sure you want to delete this video?',
    'video_deleted': 'Video deleted',
    'video_delete_failed': 'Could not delete video',
    'select_video_from_library': 'Select video from library',
    'max_size_format': 'Max 500MB • MP4, MOV, AVI',
    'tap_to_select_video': 'Tap to select video',
    'video_selected': 'Video selected',
    'select_another_video': 'Select another video',
    'uploading': 'Uploading...',
    'video_uploaded': 'Video uploaded!',
    'video_processing': 'Your video is being processed and will appear soon!',
    'close': 'Close',
    'upload_failed': 'Upload failed',
    'video_format_not_supported': 'Video format not supported',
    'video_max_size': 'Maximum video size is 500MB',
    'error_selecting_video': 'Error selecting video',
    'please_select_video': 'Please select a video',
    'please_login_again': 'Please login again',
    'describe_your_video': 'Describe your video...',
    'please_enter_description': 'Please enter a description for your video',
    'loading_video': 'Loading video...',
    'no_videos_following': 'No videos from people you follow yet',
    'no_videos_yet': 'No videos yet',
    'cannot_load_video': 'Cannot load video. Please try again.',
    'follow_others_hint': 'Follow others to see their videos!',
    'be_first_upload': 'Be the first to upload a video!',
    'reload': 'Reload',
    'following_status': 'Following',

    // Comments
    'add_comment': 'Add a comment...',
    'no_comments': 'No comments yet',
    'reply': 'Reply',
    'delete_comment': 'Delete comment',
    'need_login_to_comment': 'You need to login to comment',
    'replying_to': 'Replying to',
    'be_first_comment': 'Be the first to comment!',
    'x_comments': 'comments',
    'pinned_by_author': 'Pinned by author',
    'comment_error': 'Error sending comment',
    'please_login_to_comment': 'Please login to comment',

    // Chat
    'typing': 'Typing...',
    'add': 'Add',
    'add_message': 'Add a message...',
    'emoji': 'Emoji',
    'sending': 'Sending',
    'seen': 'Seen',
    'not_available': 'Not available',
    'video_not_exist': 'Video no longer exists',
    'cannot_open_video': 'Cannot open video',
    'cannot_select_image': 'Cannot select image',
    'cannot_take_photo': 'Cannot take photo',
    'cannot_load_image': 'Cannot load image',

    // Errors
    'network_error': 'Cannot connect to server',
    'unknown_error': 'An error occurred',
    'try_again': 'Try again',
    'server_connection_error': 'Cannot connect to server. Please try again.',
    'change_password_failed': 'Change password failed',

    // Two Factor Auth
    'select_2fa_method': 'Select authentication method:',
    'sms_subtitle': 'Receive code via SMS',
    'email_subtitle': 'Receive code via email',
    'authenticator_app': 'Authenticator App',
    '2fa_sms_enabled': 'SMS authentication enabled',
    '2fa_email_enabled': 'Email authentication enabled',
    '2fa_app_enabled': 'App authentication enabled',

    // Account Management
    'security_section': 'Security',
    'two_factor_on': 'On - Protect your account with 2-factor authentication',
    'two_factor_off': 'Off - Enable to protect your account',
    'biometric_desc': 'Login with fingerprint or FaceID',
    'login_alert': 'Login Alerts',
    'login_alert_desc': 'Get notified of new logins',
    'not_set': 'Not set',
    'data_privacy': 'Data & Privacy',
    'download_data': 'Download Your Data',
    'download_data_desc': 'Download a copy of your personal data',
    'activity_history': 'Activity History',
    'activity_history_desc': 'View your activity history',
    'danger_zone': 'Danger Zone',
    'deactivate_account': 'Deactivate Account',
    'deactivate_account_desc': 'Temporarily deactivate your account',
    'delete_account_desc': 'Permanently delete account and data',
    'feature_developing': 'Feature in development',
    'action_cannot_undo': 'This action cannot be undone!',
    'delete_permanently': 'Delete Permanently',
    'logout_confirm': 'Are you sure you want to log out?',
    'request': 'Request',

    // Edit Profile
    'name': 'Name',
    'add_name': 'Add Name',
    'add_bio': 'Add a bio to introduce yourself',
    'add_website': 'Add your website link',
    'add_location': 'Add your location',

    // Followers/Following
    'no_followers': 'No followers yet',
    'no_following': 'Not following anyone',
    'posts': 'Posts',
    'no_posts': 'No posts yet',

    // Login
    'please_enter_email': 'Please enter your email',
    'invalid_email': 'Invalid email',
    'please_enter_password': 'Please enter your password',
    'login_failed': 'Login failed',
    'or_login_with': 'Or login with',
    'facebook': 'Facebook',
    'google': 'Google',
    'phone': 'Phone',
    'no_account': 'Don\'t have an account? ',
    'have_account': 'Already have an account? ',

    // Register
    'please_enter_username': 'Please enter a username',
    'username_min_length': 'Username must be at least 3 characters',
    'password_min_length': 'Password must be at least 6 characters',
    'register_success': 'Registration successful!',
    'register_failed': 'Registration failed',
    'create_account': 'Create Account',

    // Video Detail
    'invalid_video': 'Invalid video',
    'video_unavailable': 'Video unavailable',

    // Login Required Dialog
    'login_required': 'Login Required',
    'login_to_like': 'Login to like this video',
    'login_to_share': 'Login to share this video',
    'login_to_post': 'Login to post videos',
    'login_to_save': 'Login to save this video',
    'login_to_follow': 'Login to follow this user',
    'login_to_comment': 'Login to comment',
    'login_to_view_profile': 'Login to view profile',
    'follow_others_like_videos': 'Follow others, like videos and create your own content.',
    'continue_as_guest': 'Continue as guest',
  };
}

// Extension for easy access
extension LocaleServiceExtension on String {
  String tr() => LocaleService().get(this);
}
