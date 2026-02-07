import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/client.dart';
import 'data/service/expense_service.dart';
import 'data/service/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the same ApiClient instance for all services
    final apiClient = ApiClient();

    return MultiProvider(
      providers: [
        // Provide ApiClient as a singleton
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider(
          create: (_) => AuthService(apiClient),
        ),
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
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialize auth service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthService>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    if (authService.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!authService.isAuthenticated) {
      return const LoginScreen();
    }

    // Check if user needs onboarding
    if (authService.currentUser?.isOnboarded == false) {
      return const OnboardingScreen();
    }

    return const HomeScreen();
  }
}
