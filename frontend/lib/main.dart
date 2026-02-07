import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/client.dart';
import 'data/service/expense_service.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize API client
    final apiClient = ApiClient(
      baseUrl: 'http://localhost:8000/api', // Update with your server URL
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ExpenseService(apiClient),
        ),
      ],
      child: MaterialApp(
        title: 'EaseABill - Budget Manager',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          // cardTheme: CardTheme(
          //   elevation: 2,
          //   shape: RoundedRectangleBorder(
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          // ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
