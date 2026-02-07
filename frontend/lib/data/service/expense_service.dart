import 'package:flutter/foundation.dart';
import '../client.dart';
import '../model/expense.dart';
import '../model/budget.dart';

class ExpenseService extends ChangeNotifier {
  final ApiClient _client;
  
  List<Expense> _expenses = [];
  List<Budget> _budgets = [];
  bool _isLoading = false;
  String? _error;

  ExpenseService(this._client);

  // Getters
  List<Expense> get expenses => _expenses;
  List<Budget> get budgets => _budgets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get total spending
  double get totalSpending {
    return _expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  // Get spending by category
  Map<String, double> get spendingByCategory {
    final Map<String, double> spending = {};
    for (var expense in _expenses) {
      spending[expense.category] = 
          (spending[expense.category] ?? 0.0) + expense.amount;
    }
    return spending;
  }

  // ==================== Expense Methods ====================

  /// Load all expenses
  Future<void> loadExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) async {
    _setLoading(true);
    try {
      _expenses = await _client.getExpenses(
        startDate: startDate,
        endDate: endDate,
        category: category,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('Error loading expenses: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Add a new expense
  Future<bool> addExpense(Expense expense) async {
    _setLoading(true);
    try {
      final newExpense = await _client.createExpense(expense);
      _expenses.insert(0, newExpense);
      _error = null;
      notifyListeners();
      
      // Reload budgets to update spent amounts
      await loadBudgets();
      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('Error adding expense: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Update an existing expense
  Future<bool> updateExpense(String id, Expense expense) async {
    _setLoading(true);
    try {
      final updatedExpense = await _client.updateExpense(id, expense);
      final index = _expenses.indexWhere((e) => e.id == id);
      if (index != -1) {
        _expenses[index] = updatedExpense;
      }
      _error = null;
      notifyListeners();
      
      // Reload budgets to update spent amounts
      await loadBudgets();
      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('Error updating expense: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Delete an expense
  Future<bool> deleteExpense(String id) async {
    _setLoading(true);
    try {
      await _client.deleteExpense(id);
      _expenses.removeWhere((e) => e.id == id);
      _error = null;
      notifyListeners();
      
      // Reload budgets to update spent amounts
      await loadBudgets();
      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('Error deleting expense: $e');
      _setLoading(false);
      return false;
    }
  }

  // ==================== Budget Methods ====================

  /// Load all budgets
  Future<void> loadBudgets() async {
    _setLoading(true);
    try {
      _budgets = await _client.getBudgets();
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('Error loading budgets: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Add a new budget
  Future<bool> addBudget(Budget budget) async {
    _setLoading(true);
    try {
      final newBudget = await _client.createBudget(budget);
      _budgets.add(newBudget);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('Error adding budget: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Update an existing budget
  Future<bool> updateBudget(String id, Budget budget) async {
    _setLoading(true);
    try {
      final updatedBudget = await _client.updateBudget(id, budget);
      final index = _budgets.indexWhere((b) => b.id == id);
      if (index != -1) {
        _budgets[index] = updatedBudget;
      }
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('Error updating budget: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Delete a budget
  Future<bool> deleteBudget(String id) async {
    _setLoading(true);
    try {
      await _client.deleteBudget(id);
      _budgets.removeWhere((b) => b.id == id);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('Error deleting budget: $e');
      _setLoading(false);
      return false;
    }
  }

  // Helper method to set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ==================== OCR & Receipt Methods ====================

  /// Upload receipt image for OCR processing
  Future<Map<String, dynamic>> uploadReceiptImage(String imagePath) async {
    _setLoading(true);
    try {
      final result = await _client.uploadReceiptImage(imagePath);
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('Error uploading receipt: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Upload audio recording for server-side processing
  Future<Map<String, dynamic>> uploadAudioRecording(String audioPath) async {
    _setLoading(true);
    try {
      final result = await _client.uploadAudioRecording(audioPath);
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('Error uploading audio: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
}
