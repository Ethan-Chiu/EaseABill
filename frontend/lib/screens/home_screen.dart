import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/service/expense_service.dart';
import 'expenses_screen.dart';
import 'budgets_screen.dart';
import 'statistics_screen.dart';
import 'add_expense_screen.dart';
import '../components/voice_record_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ExpensesScreen(),
    const BudgetsScreen(),
    const StatisticsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<ExpenseService>();
      service.loadExpenses();
      service.loadBudgets();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Budgets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Statistics',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: _selectedIndex == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VoiceRecordButton(
                  onAudioRecorded: (audioPath) async {
                    final service = context.read<ExpenseService>();
                    try {
                      // print debug message
                      print('Uploading audio recording: $audioPath');

                      await service.uploadAudioRecording(audioPath);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Audio sent for processing.'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error sending audio: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'add_expense_button',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddExpenseScreen(),
                      ),
                    );
                  },
                  child: const Icon(Icons.add),
                ),
              ],
            )
          : null,
    );
  }
}
