class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool _isLoggedIn = false;
  String? _username;

  bool get isLoggedIn => _isLoggedIn;
  String? get username => _username;

  void login(String username) {
    _isLoggedIn = true;
    _username = username;
  }

  void logout() {
    _isLoggedIn = false;
    _username = null;
  }
}
