import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../data/service/expense_service.dart';
import '../data/model/category.dart';
import '../data/client.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final ApiClient _client = ApiClient();
  bool _isLoadingWeekly = false;
  List<FlSpot> _weeklyData = [];
  List<String> _weekLabels = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    setState(() {
      _isLoadingWeekly = true;
      _error = null;
    });

    try {
      final data = await _client.getStatsWeekly(weeks: 8);
      final points = data['points'] as List;
      
      final spots = <FlSpot>[];
      final labels = <String>[];
      
      for (var i = 0; i < points.length; i++) {
        final point = points[i];
        final xValue = point['x'] as String;
        final yValue = (point['y'] as num).toDouble();
        
        spots.add(FlSpot(i.toDouble(), yValue));
        
        // Parse date and format as MM/DD
        final date = DateTime.parse(xValue);
        labels.add(DateFormat('M/d').format(date));
      }

      setState(() {
        _weeklyData = spots;
        _weekLabels = labels;
        _isLoadingWeekly = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingWeekly = false;
      });
    }
  }

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
                  'Weekly Spending Trend',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildWeeklyLineChart(context),
                const SizedBox(height: 24),
                Text(
                  'Budget Compliance Calendar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Track your daily budget adherence',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 16),
                _BudgetCalendar(),
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

  Widget _buildWeeklyLineChart(BuildContext context) {
    if (_isLoadingWeekly) {
      return const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 8),
              Text('Failed to load chart data'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loadWeeklyData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_weeklyData.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(child: Text('No data available')),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: _calculateInterval(),
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey[300]!,
                    strokeWidth: 1,
                  );
                },
                getDrawingVerticalLine: (value) {
                  return FlLine(
                    color: Colors.grey[300]!,
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < _weekLabels.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _weekLabels[index],
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: _calculateInterval(),
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '\$${value.toInt()}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey[300]!),
              ),
              minX: 0,
              maxX: (_weeklyData.length - 1).toDouble(),
              minY: 0,
              maxY: _calculateMaxY(),
              lineBarsData: [
                LineChartBarData(
                  spots: _weeklyData,
                  isCurved: true,
                  color: Theme.of(context).primaryColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Theme.of(context).primaryColor,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _calculateMaxY() {
    if (_weeklyData.isEmpty) return 100;
    final maxValue = _weeklyData.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    return (maxValue * 1.2).ceilToDouble();
  }

  double _calculateInterval() {
    final maxY = _calculateMaxY();
    if (maxY <= 50) return 10;
    if (maxY <= 100) return 20;
    if (maxY <= 500) return 100;
    return 200;
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

// Budget Calendar Widget
class _BudgetCalendar extends StatefulWidget {
  @override
  State<_BudgetCalendar> createState() => _BudgetCalendarState();
}

class _BudgetCalendarState extends State<_BudgetCalendar> {
  final _apiClient = ApiClient();
  Map<String, Map<String, dynamic>> _dailyStatusMap = {};
  bool _isLoading = false;
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadDailyStatus();
  }

  Future<void> _loadDailyStatus() async {
    setState(() => _isLoading = true);
    try {
      // Get first and last day of current month
      final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
      final days = lastDay.day;
      
      final data = await _apiClient.getDailyStatus(days: days, end: lastDay);
      
      // Convert list to map for easy lookup by date
      final statusMap = <String, Map<String, dynamic>>{};
      for (var item in data) {
        final date = DateTime.parse(item['date']);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        statusMap[dateKey] = item;
      }
      
      setState(() {
        _dailyStatusMap = statusMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(Map<String, dynamic>? day) {
    if (day == null || !day['hasData']) {
      return Colors.grey.shade200;
    }
    if (day['compliant'] == true) {
      return Colors.green.shade400;
    } else {
      return Colors.red.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDay.weekday % 7; // 0 = Sunday, 1 = Monday, etc.
    final daysInMonth = lastDay.day;
    final today = DateTime.now();
    
    // Total cells = empty cells before month + days in month
    final totalCells = firstWeekday + daysInMonth;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month/Year header
            Text(
              DateFormat('MMMM yyyy').format(_currentMonth),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem(Colors.green.shade400, 'Compliant'),
                _buildLegendItem(Colors.red.shade400, 'Overspent'),
                _buildLegendItem(Colors.grey.shade200, 'No Data'),
              ],
            ),
            const SizedBox(height: 16),
            // Weekday headers
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 7,
              itemBuilder: (context, index) {
                final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                return Center(
                  child: Text(
                    weekdays[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            // Calendar grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: totalCells,
              itemBuilder: (context, index) {
                // Empty cell before first day of month
                if (index < firstWeekday) {
                  return const SizedBox.shrink();
                }
                
                final dayNumber = index - firstWeekday + 1;
                final date = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
                final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                final dayData = _dailyStatusMap[dateKey];
                final color = _getStatusColor(dayData);
                
                // Check if this is today
                final isToday = date.year == today.year && 
                               date.month == today.month && 
                               date.day == today.day;
                
                return Tooltip(
                  message: '${DateFormat('MMM d').format(date)}\n${dayData?['compliant'] == true ? 'Budget met' : dayData?['hasData'] == true ? 'Overspent' : 'No data'}',
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isToday ? Theme.of(context).primaryColor : Colors.grey.shade300,
                        width: isToday ? 3 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                          color: dayData?['hasData'] == true ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

