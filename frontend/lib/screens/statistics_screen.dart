import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/service/expense_service.dart';
import '../data/model/category.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
      ),
      body: Consumer<ExpenseService>(
        builder: (context, service, child) {
          if (service.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No data available',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add some expenses to see statistics',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTotalSpendingCard(context, service),
                const SizedBox(height: 24),
                Text(
                  'Spending by Category',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildCategoryChart(context, service),
                const SizedBox(height: 24),
                _buildCategoryList(context, service),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotalSpendingCard(BuildContext context, ExpenseService service) {
    return Card(
      color: Theme.of(context).primaryColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Total Spending',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${service.totalSpending.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${service.expenses.length} transactions',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart(BuildContext context, ExpenseService service) {
    final spending = service.spendingByCategory;
    if (spending.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: _generatePieChartSections(spending, service.totalSpending),
        ),
      ),
    );
  }

  List<PieChartSectionData> _generatePieChartSections(
    Map<String, double> spending,
    double total,
  ) {
    return spending.entries.map((entry) {
      final category = ExpenseCategory.getCategory(entry.key);
      final percentage = (entry.value / total * 100);

      return PieChartSectionData(
        color: category.color,
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildCategoryList(BuildContext context, ExpenseService service) {
    final spending = service.spendingByCategory;
    final sortedEntries = spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category Breakdown',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...sortedEntries.map((entry) {
          final category = ExpenseCategory.getCategory(entry.key);
          final percentage = (entry.value / service.totalSpending * 100);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: category.color.withOpacity(0.2),
                child: Icon(category.icon, color: category.color),
              ),
              title: Text(
                entry.key,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${percentage.toStringAsFixed(1)}%'),
              trailing: Text(
                '\$${entry.value.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
