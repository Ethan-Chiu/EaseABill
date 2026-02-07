import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'model/expense.dart';
import 'model/budget.dart';

class ApiClient {
  final String baseUrl;
  String? _authToken;

  ApiClient({
    String? baseUrl,
  }) : baseUrl = baseUrl ?? _defaultBaseUrl();

  static String _defaultBaseUrl() {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://localhost:8000/api';
  }

  // Set authentication token
  void setAuthToken(String token) {
    _authToken = token;
  }

  // Get headers with authentication
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // Generic error handler
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return json.decode(response.body);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: response.body.isNotEmpty
            ? json.decode(response.body)['message'] ?? 'Unknown error'
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

    final response = await http.get(uri, headers: _headers);
    final data = _handleResponse(response) as List;
    return data.map((json) => Expense.fromJson(json)).toList();
  }

  /// Get a single expense by ID
  Future<Expense> getExpense(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/expenses/$id'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    return Expense.fromJson(data);
  }

  /// Create a new expense
  Future<Expense> createExpense(Expense expense) async {
    final response = await http.post(
      Uri.parse('$baseUrl/expenses'),
      headers: _headers,
      body: json.encode(expense.toJson()),
    );
    final data = _handleResponse(response);
    return Expense.fromJson(data);
  }

  /// Update an existing expense
  Future<Expense> updateExpense(String id, Expense expense) async {
    final response = await http.put(
      Uri.parse('$baseUrl/expenses/$id'),
      headers: _headers,
      body: json.encode(expense.toJson()),
    );
    final data = _handleResponse(response);
    return Expense.fromJson(data);
  }

  /// Delete an expense
  Future<void> deleteExpense(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/expenses/$id'),
      headers: _headers,
    );
    _handleResponse(response);
  }

  // ==================== Budget Endpoints ====================

  /// Get all budgets
  Future<List<Budget>> getBudgets() async {
    final response = await http.get(
      Uri.parse('$baseUrl/budgets'),
      headers: _headers,
    );
    final data = _handleResponse(response) as List;
    return data.map((json) => Budget.fromJson(json)).toList();
  }

  /// Get a single budget by ID
  Future<Budget> getBudget(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/budgets/$id'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    return Budget.fromJson(data);
  }

  /// Create a new budget
  Future<Budget> createBudget(Budget budget) async {
    final response = await http.post(
      Uri.parse('$baseUrl/budgets'),
      headers: _headers,
      body: json.encode(budget.toJson()),
    );
    final data = _handleResponse(response);
    return Budget.fromJson(data);
  }

  /// Update an existing budget
  Future<Budget> updateBudget(String id, Budget budget) async {
    final response = await http.put(
      Uri.parse('$baseUrl/budgets/$id'),
      headers: _headers,
      body: json.encode(budget.toJson()),
    );
    final data = _handleResponse(response);
    return Budget.fromJson(data);
  }

  /// Delete a budget
  Future<void> deleteBudget(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/budgets/$id'),
      headers: _headers,
    );
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

  // ==================== OCR & Receipt Endpoints ====================

  /// Upload receipt image for OCR processing
  Future<Map<String, dynamic>> uploadReceiptImage(
    String imagePath, {
    String? expenseId,
  }) async {
    final file = await _readFile(imagePath);
    
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/ocr/process-receipt'),
    );

    // Add headers
    _headers.forEach((key, value) {
      request.headers[key] = value;
    });

    // Add file
    request.files.add(
      http.MultipartFile(
        'receipt',
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
            ? json.decode(responseBody)['message'] ?? 'Failed to process receipt'
            : 'Failed to upload receipt image',
      );
    }
  }

  // Helper method to read file
  Future<File> _readFile(String filePath) async {
    return File(filePath);
  }

  // Helper method to extract filename from path
  String _getFileName(String path) {
    return path.split('/').last;
  }
}

// Custom exception for API errors
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}
