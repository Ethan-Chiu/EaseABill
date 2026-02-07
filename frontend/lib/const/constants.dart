/// API Configuration
class ApiConfig {
  // Update this URL to match your backend server
  static const String baseUrl = 'http://localhost:8000/api';
  
  // Alternative configurations for different environments
  static const String devUrl = 'http://localhost:8000/api';
  static const String prodUrl = 'https://your-production-server.com/api';
  
  // Timeout durations
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Get current environment URL
  static String get currentUrl => baseUrl;
}

/// App Constants
class AppConstants {
  // App Information
  static const String appName = 'EaseABill';
  static const String appVersion = '1.0.0';
  
  // Pagination
  static const int itemsPerPage = 20;
  
  // Date Formats
  static const String dateFormat = 'MMM dd, yyyy';
  static const String monthYearFormat = 'MMM yyyy';
  
  // Currency
  static const String currencySymbol = '\$';
  static const String currencyCode = 'USD';
  
  // Budget Periods
  static const List<String> budgetPeriods = ['weekly', 'monthly', 'yearly'];
  
  // Warning Thresholds
  static const double budgetWarningThreshold = 80.0; // 80% of budget
  static const double budgetDangerThreshold = 100.0; // 100% of budget
}

/// Local Storage Keys
class StorageKeys {
  static const String authToken = 'auth_token';
  static const String userId = 'user_id';
  static const String userName = 'user_name';
  static const String lastSyncTime = 'last_sync_time';
  static const String selectedCurrency = 'selected_currency';
}
