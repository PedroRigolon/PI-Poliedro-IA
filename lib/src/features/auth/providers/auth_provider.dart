import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  UserModel? _user;
  bool _isLoading = false;
  String? _cachedPassword;

  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get password => _cachedPassword;

  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      _user = await _authService.login(email, password);
      _cachedPassword = password;

      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      _user = await _authService.register(email, password);
      _cachedPassword = password;

      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.logout();
      _user = null;
      _cachedPassword = null;

      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteAccount() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.deleteAccount();
      _user = null;
      _cachedPassword = null;

      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.changePassword(currentPassword, newPassword);
      _cachedPassword = newPassword;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
