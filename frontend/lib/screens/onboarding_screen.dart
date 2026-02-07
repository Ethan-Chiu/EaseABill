import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../data/service/auth_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final _locationController = TextEditingController();
  final _incomeController = TextEditingController();
  final _budgetGoalController = TextEditingController();
  
  double? _selectedLatitude;
  double? _selectedLongitude;
  bool _isLoadingLocation = false;

  @override
  void dispose() {
    _pageController.dispose();
    _locationController.dispose();
    _incomeController.dispose();
    _budgetGoalController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are denied'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _selectedLatitude = position.latitude;
      _selectedLongitude = position.longitude;

      // Reverse geocode to get address
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final locationText = '${place.locality ?? ''}, ${place.country ?? ''}'
            .replaceAll(RegExp(r'^,\s*|,\s*$'), '');
        _locationController.text = locationText;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location detected successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        _selectedLatitude = locations.first.latitude;
        _selectedLongitude = locations.first.longitude;
      }
    } catch (e) {
      // Search failed, but we can still save the text
      debugPrint('Location search failed: $e');
    }
  }

  Future<void> _completeOnboarding() async {
    final authService = context.read<AuthService>();

    final income = double.tryParse(_incomeController.text);
    final budgetGoal = double.tryParse(_budgetGoalController.text);

    if (income == null || income <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid monthly income'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (budgetGoal == null || budgetGoal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid budget goal'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await authService.updateProfile(
      location: _locationController.text.trim(),
      latitude: _selectedLatitude,
      longitude: _selectedLongitude,
      monthlyIncome: income,
      budgetGoal: budgetGoal,
    );

    if (mounted) {
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authService.error ?? 'Failed to save profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _previousPage,
                    )
                  else
                    const SizedBox(width: 48),
                  Row(
                    children: List.generate(
                      3,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Theme.of(context).primaryColor
                              : Colors.grey[300],
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                children: [
                  _buildLocationPage(),
                  _buildIncomePage(),
                  _buildBudgetGoalPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: authService.isLoading
                    ? null
                    : (_currentPage == 2 ? _completeOnboarding : _nextPage),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 0),
                ),
                child: authService.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_currentPage == 2 ? 'Get Started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(
            Icons.location_on,
            size: 80,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Where are you located?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'This helps us provide relevant budgeting tips and local insights.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _locationController,
            onChanged: (value) {
              // Debounce search location
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_locationController.text == value) {
                  _searchLocation(value);
                }
              });
            },
            decoration: const InputDecoration(
              labelText: 'City, Country',
              prefixIcon: Icon(Icons.place),
              border: OutlineInputBorder(),
              hintText: 'e.g., San Francisco, USA',
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isLoadingLocation ? null : _getCurrentLocation,
            icon: _isLoadingLocation
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(_isLoadingLocation
                ? 'Getting location...'
                : 'Use Current Location'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
          if (_selectedLatitude != null && _selectedLongitude != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Coordinates: ${_selectedLatitude!.toStringAsFixed(4)}, ${_selectedLongitude!.toStringAsFixed(4)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green[700],
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIncomePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.attach_money,
            size: 80,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            'What\'s your monthly income?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Approximate amount is fine. This helps us provide better budget recommendations.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _incomeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monthly Income',
              prefixIcon: Icon(Icons.account_balance_wallet),
              border: OutlineInputBorder(),
              prefixText: '\$ ',
              hintText: '5000',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetGoalPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flag,
            size: 80,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Set your budget goal',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'How much do you want to save or budget each month?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _budgetGoalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monthly Budget Goal',
              prefixIcon: Icon(Icons.savings),
              border: OutlineInputBorder(),
              prefixText: '\$ ',
              hintText: '1000',
            ),
          ),
        ],
      ),
    );
  }
}
