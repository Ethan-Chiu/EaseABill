import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../data/service/expense_service.dart';
import '../data/model/expense.dart';
import '../data/model/category.dart';
import 'add_expense_screen.dart';
import 'notifications_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String? _selectedCategory;
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'Budget Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Consumer<ExpenseService>(
        builder: (context, service, child) {
          if (service.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${service.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => service.loadExpenses(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final expenses = service.expenses;

          if (expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No expenses yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add your first expense',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => service.loadExpenses(
              category: _selectedCategory,
              startDate: _dateRange?.start,
              endDate: _dateRange?.end,
            ),
            child: ListView.builder(
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                final expense = expenses[index];
                return _buildExpenseCard(context, expense, service);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpenseCard(
    BuildContext context,
    Expense expense,
    ExpenseService service,
  ) {
    final category = ExpenseCategory.getCategory(expense.category);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: category.color.withOpacity(0.2),
          child: Icon(category.icon, color: category.color),
        ),
        title: Text(
          expense.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(expense.category),
            Text(
              dateFormat.format(expense.date),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (expense.description != null)
              Text(
                expense.description!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Text(
          '\$${expense.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Theme.of(context).primaryColor,
          ),
        ),
        onTap: () => _showExpenseDetails(context, expense, service),
      ),
    );
  }

  void _showExpenseDetails(
    BuildContext context,
    Expense expense,
    ExpenseService service,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              expense.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.attach_money,
              label: 'Amount',
              value: '\$${expense.amount.toStringAsFixed(2)}',
            ),
            _DetailRow(
              icon: Icons.category,
              label: 'Category',
              value: expense.category,
            ),
            _DetailRow(
              icon: Icons.calendar_today,
              label: 'Date',
              value: DateFormat('MMM dd, yyyy').format(expense.date),
            ),
            if (expense.description != null)
              _DetailRow(
                icon: Icons.notes,
                label: 'Description',
                value: expense.description!,
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddExpenseScreen(expense: expense),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDelete(context, expense.id!, service);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    String expenseId,
    ExpenseService service,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await service.deleteExpense(expenseId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Expense deleted successfully'
                          : 'Failed to delete expense',
                    ),
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Expenses'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...ExpenseCategory.defaultCategories.map(
                  (cat) => DropdownMenuItem(
                    value: cat.name,
                    child: Text(cat.name),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedCategory = value);
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(
                _dateRange == null
                    ? 'Select Date Range'
                    : '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}',
              ),
              trailing: const Icon(Icons.date_range),
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (range != null) {
                  setState(() => _dateRange = range);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCategory = null;
                _dateRange = null;
              });
              Navigator.pop(context);
              context.read<ExpenseService>().loadExpenses();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ExpenseService>().loadExpenses(
                    category: _selectedCategory,
                    startDate: _dateRange?.start,
                    endDate: _dateRange?.end,
                  );
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
