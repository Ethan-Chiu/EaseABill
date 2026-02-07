import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../client.dart';
import '../model/user.dart';

class AuthService extends ChangeNotifier {
  final ApiClient _client;
  User? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _error;

  AuthService(this._client);

  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null && _currentUser != null;

  /// Initialize auth state from storage
  Future<void> initialize() async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
      final userJson = prefs.getString('current_user');

      if (kDebugMode) {
        print('DEBUG: Initializing auth - token exists: $_token != null');
      }

      if (_token != null && userJson != null) {
        _client.setAuthToken(_token!);
        if (kDebugMode) print('DEBUG: Token restored and set on ApiClient');
        // Optionally verify token with server
        // For now, just restore from local storage
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('Error initializing auth: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Login with username and password
  Future<bool> login(String username, String password) async {
    _setLoading(true);
    try {
      final response = await _client.login(username, password);
      _token = response['token'];
      _currentUser = User.fromJson(response['user']);

      _client.setAuthToken(_token!);
      await _saveAuthState();
      _error = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('Login error: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Register new user
  Future<bool> register(String username, String password) async {
    _setLoading(true);
    try {
      final response = await _client.register(username, password);
      _token = response['token'];
      _currentUser = User.fromJson(response['user']);

      _client.setAuthToken(_token!);
      await _saveAuthState();
      _error = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('Register error: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Update user profile (onboarding data)
  Future<bool> updateProfile({
    String? location,
    double? latitude,
    double? longitude,
    double? monthlyIncome,
    double? budgetGoal,
  }) async {
    _setLoading(true);
    try {
      final response = await _client.updateUserProfile(
        location: location,
        latitude: latitude,
        longitude: longitude,
        monthlyIncome: monthlyIncome,
        budgetGoal: budgetGoal,
        isOnboarded: true,
      );
      _currentUser = User.fromJson(response);
      await _saveAuthState();
      _error = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('Update profile error: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    _client.setAuthToken('');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('current_user');

    notifyListeners();
  }

  /// Save auth state to local storage
  Future<void> _saveAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) {
      await prefs.setString('auth_token', _token!);
    }
    if (_currentUser != null) {
      await prefs.setString('current_user', _currentUser!.toJson().toString());
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
