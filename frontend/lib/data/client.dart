import 'dart:convert';
import 'dart:io';
import 'package:frontend/environments/environment_singleton.dart';
import 'package:http/http.dart' as http;
import 'model/expense.dart';
import 'model/budget.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  final String baseUrl;
  String? _authToken;

  ApiClient._internal({String? baseUrl})
      : baseUrl = baseUrl ?? _defaultBaseUrl();

  factory ApiClient() {
    return _instance;
  }

  static String _defaultBaseUrl() {
    String url = Environment().config.baseUrl;
    print('Base Url: $url');

    if (url.isNotEmpty) return url;

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://localhost:8000/api';
  }

  // Set authentication token
  void setAuthToken(String token) {
    print('Setting auth token: $token');
    _authToken = token;
  }

  // Get headers with authentication
  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Map<String, String> get _multipartHeaders {
    final headers = <String, String>{};
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  void _logRequest(String method, Uri uri, [String? body]) {
    print('HTTP $method: $uri');
    if (body != null) {
      print('Body: $body');
    }
  }

  // Generic error handler
  // dynamic _handleResponse(http.Response response) {
  //   if (response.statusCode >= 200 && response.statusCode < 300) {
  //     if (response.body.isEmpty) return null;
  //     return json.decode(response.body);
  //   } else {
  //     throw ApiException(
  //       statusCode: response.statusCode,
  //       message: response.body.isNotEmpty
  //           ? json.decode(response.body)['message'] ?? 'Unknown error'
  //           : 'Request failed with status: ${response.statusCode}',
  //     );
  //   }
  // }

  dynamic _handleResponse(http.Response response) {
  if (response.statusCode >= 200 && response.statusCode < 300) {
    try {
      return response.body.isEmpty ? null : json.decode(response.body);
    } catch (e) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Invalid JSON response',
      );
    }
  } else {
    throw ApiException(
      statusCode: response.statusCode,
      message: response.body.isNotEmpty
          ? response.body
          : 'Request failed with status: ${response.statusCode}',
    );
  }
}

  // ==================== Expense Endpoints ====================

  /// Get all expenses
  Future<List<Expense>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) async {
    var uri = Uri.parse('$baseUrl/expenses');
    final queryParams = <String, String>{};

    if (startDate != null) {
      queryParams['startDate'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParams['endDate'] = endDate.toIso8601String();
    }
    if (category != null) {
      queryParams['category'] = category;
    }

    if (queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    _logRequest('GET', uri);
    final response = await http.get(uri, headers: _headers);
    final data = _handleResponse(response) as List;
    return data.map((json) => Expense.fromJson(json)).toList();
  }

  /// Get a single expense by ID
  Future<Expense> getExpense(String id) async {
    final uri = Uri.parse('$baseUrl/expenses/$id');
    _logRequest('GET', uri);
    final response = await http.get(uri, headers: _headers);
    final data = _handleResponse(response);
    return Expense.fromJson(data);
  }

  /// Create a new expense
  Future<Expense> createExpense(Expense expense) async {
    final uri = Uri.parse('$baseUrl/expenses');
    final body = json.encode(expense.toJson());
    _logRequest('POST', uri, body);
    final response = await http.post(uri, headers: _headers, body: body);
    final data = _handleResponse(response);
    return Expense.fromJson(data);
  }

  /// Update an existing expense
  Future<Expense> updateExpense(String id, Expense expense) async {
    final uri = Uri.parse('$baseUrl/expenses/$id');
    final body = json.encode(expense.toJson());
    _logRequest('PUT', uri, body);
    final response = await http.put(uri, headers: _headers, body: body);
    final data = _handleResponse(response);
    return Expense.fromJson(data);
  }

  /// Delete an expense
  Future<void> deleteExpense(String id) async {
    final uri = Uri.parse('$baseUrl/expenses/$id');
    _logRequest('DELETE', uri);
    final response = await http.delete(uri, headers: _headers);
    _handleResponse(response);
  }

  // ==================== Budget Endpoints ====================

  /// Get all budgets
  Future<List<Budget>> getBudgets() async {
    final uri = Uri.parse('$baseUrl/budgets');
    _logRequest('GET', uri);
    final response = await http.get(uri, headers: _headers);
    final data = _handleResponse(response) as List;
    return data.map((json) => Budget.fromJson(json)).toList();
  }

  /// Get a single budget by ID
  Future<Budget> getBudget(String id) async {
    final uri = Uri.parse('$baseUrl/budgets/$id');
    _logRequest('GET', uri);
    final response = await http.get(uri, headers: _headers);
    final data = _handleResponse(response);
    return Budget.fromJson(data);
  }

  /// Create a new budget
  Future<Budget> createBudget(Budget budget) async {
    final uri = Uri.parse('$baseUrl/budgets');
    final body = json.encode(budget.toJson());
    _logRequest('POST', uri, body);
    final response = await http.post(uri, headers: _headers, body: body);
    final data = _handleResponse(response);
    return Budget.fromJson(data);
  }

  /// Update an existing budget
  Future<Budget> updateBudget(String id, Budget budget) async {
    final uri = Uri.parse('$baseUrl/budgets/$id');
    final body = json.encode(budget.toJson());
    _logRequest('PUT', uri, body);
    final response = await http.put(uri, headers: _headers, body: body);
    final data = _handleResponse(response);
    return Budget.fromJson(data);
  }

  /// Delete a budget
  Future<void> deleteBudget(String id) async {
    final uri = Uri.parse('$baseUrl/budgets/$id');
    _logRequest('DELETE', uri);
    final response = await http.delete(uri, headers: _headers);
    _handleResponse(response);
  }

  // ==================== Statistics Endpoints ====================

  /// Get spending summary by category
  Future<Map<String, double>> getSpendingByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var uri = Uri.parse('$baseUrl/statistics/spending-by-category');
    final queryParams = <String, String>{};

    if (startDate != null) {
      queryParams['startDate'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParams['endDate'] = endDate.toIso8601String();
    }

    if (queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final response = await http.get(uri, headers: _headers);
    final data = _handleResponse(response) as Map<String, dynamic>;
    return data.map((key, value) => MapEntry(key, (value as num).toDouble()));
  }

  /// Get monthly spending trend
  Future<Map<String, double>> getMonthlySpending({int months = 6}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/statistics/monthly-spending?months=$months'),
      headers: _headers,
    );
    final data = _handleResponse(response) as Map<String, dynamic>;
    return data.map((key, value) => MapEntry(key, (value as num).toDouble()));
  }

  /// Get pie chart data for spending by category
  Future<Map<String, dynamic>> getStatsPie({
    DateTime? start,
    DateTime? end,
    int topN = 5,
    bool includeOther = true,
  }) async {
    var uri = Uri.parse('$baseUrl/stats/pie');
    final queryParams = <String, String>{
      'topN': topN.toString(),
      'includeOther': includeOther.toString(),
    };

    if (start != null) {
      queryParams['start'] = start.toIso8601String();
    }
    if (end != null) {
      queryParams['end'] = end.toIso8601String();
    }

    uri = uri.replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);
    return _handleResponse(response) as Map<String, dynamic>;
  }

  /// Get weekly spending series for line chart
  Future<Map<String, dynamic>> getStatsWeekly({
    int weeks = 8,
    String? category,
  }) async {
    var uri = Uri.parse('$baseUrl/stats/weekly');
    final queryParams = <String, String>{
      'weeks': weeks.toString(),
    };

    if (category != null) {
      queryParams['category'] = category;
    }

    uri = uri.replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);
    return _handleResponse(response) as Map<String, dynamic>;
  }

  // ==================== OCR & Receipt Endpoints ====================

  /// Upload receipt image for OCR processing
  Future<Map<String, dynamic>> uploadReceiptImage(
    String imagePath, {
    String? expenseId,
  }) async {
    final file = await _readFile(imagePath);

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/ocr/ocr_to_entry'),
    );

    // Add headers
    _multipartHeaders.forEach((key, value) {
      request.headers[key] = value;
    });

    // Add file
    request.files.add(
      http.MultipartFile(
        'file',
        file.openRead(),
        file.lengthSync(),
        filename: _getFileName(imagePath),
      ),
    );

    // Add optional parameters
    if (expenseId != null) {
      request.fields['expenseId'] = expenseId;
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(responseBody);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: responseBody.isNotEmpty
            ? json.decode(responseBody)['message'] ??
                  'Failed to process receipt'
            : 'Failed to upload receipt image',
      );
    }
  }

  // Helper method to read file
  Future<File> _readFile(String filePath) async {
    return File(filePath);
  }

  /// Upload audio recording for server-side processing
  Future<Map<String, dynamic>> uploadAudioRecording(String audioPath) async {
    final file = await _readFile(audioPath);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/speech/upload_audio'),
    );

    _multipartHeaders.forEach((key, value) {
      request.headers[key] = value;
    });

    request.files.add(
      http.MultipartFile(
        'file',
        file.openRead(),
        file.lengthSync(),
        filename: _getFileName(audioPath),
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (responseBody.isEmpty) return {};
      return json.decode(responseBody);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: responseBody.isNotEmpty
            ? json.decode(responseBody)['message'] ?? 'Failed to upload audio'
            : 'Failed to upload audio',
      );
    }
  }

  // Helper method to extract filename from path
  String _getFileName(String path) {
    return path.split('/').last;
  }

  // ==================== Authentication Endpoints ====================

  /// Login with username and password
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );
    return _handleResponse(response);
  }

  /// Register new user
  Future<Map<String, dynamic>> register(
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );
    return _handleResponse(response);
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateUserProfile({
    String? location,
    double? latitude,
    double? longitude,
    double? monthlyIncome,
    double? budgetGoal,
    bool? isOnboarded,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/user/profile'),
      headers: _headers,
      body: json.encode({
        if (location != null) 'location': location,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (monthlyIncome != null) 'monthlyIncome': monthlyIncome,
        if (budgetGoal != null) 'budgetGoal': budgetGoal,
        if (isOnboarded != null) 'isOnboarded': isOnboarded,
      }),
    );
    return _handleResponse(response);
  }

  // ==================== Notification Endpoints ====================

  /// Get all budget status notifications for a user on a specific date
  Future<List<Map<String, dynamic>>> getNotifications({DateTime? date}) async {
    var uri = Uri.parse('$baseUrl/notifications');
    
    if (date != null) {
      final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      uri = uri.replace(queryParameters: {'date': dateStr});
    }
    
    _logRequest('GET', uri);
    final response = await http.get(uri, headers: _headers);
    final data = _handleResponse(response) as List;
    return data.cast<Map<String, dynamic>>();
  }

  // ==================== Streak Endpoints ====================

  /// Get user's current streak
  Future<Map<String, dynamic>> getUserStreak() async {
    final uri = Uri.parse('$baseUrl/user/streak');
    _logRequest('GET', uri);
    final response = await http.get(uri, headers: _headers);
    return _handleResponse(response);
  }

  /// Get daily budget compliance status for calendar
  Future<List<Map<String, dynamic>>> getDailyStatus({int days = 30, DateTime? end, String? today}) async {
    var uri = Uri.parse('$baseUrl/stats/daily-status');
    
    final params = <String, String>{
      'days': days.toString(),
    };
    
    if (end != null) {
      params['end'] = end.toIso8601String();
    }
    
    if (today != null) {
      params['today'] = today;
    }
    
    uri = uri.replace(queryParameters: params);
    
    _logRequest('GET', uri);
    final response = await http.get(uri, headers: _headers);
    final data = _handleResponse(response) as List;
    return data.cast<Map<String, dynamic>>();
  }
}

// Custom exception for API errors
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}
