class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool _isLoggedIn = false;
  String? _username;
  String? _token;
  DateTime? _tokenExpiry;

  bool get isLoggedIn => _isLoggedIn && _isTokenValid();
  bool _isTokenValid() {
    if (_token == null || _tokenExpiry == null) return false;
    return DateTime.now().isBefore(_tokenExpiry!);
  }
  String? get username => _username;

  void login(String username) {
    _isLoggedIn = true;
    _username = username;
  }

  void logout() {
    _isLoggedIn = false;
    _username = null;
    _token = null;
    _tokenExpiry = null;
  }
}
