# EaseABill - Budget Management & Expense Tracking App

A comprehensive Flutter application for managing budgets and tracking expenses.

## Features

- ✅ **Expense Tracking**: Add, edit, and delete expenses with categories
- 📊 **Budget Management**: Set budgets for different categories and track spending
- 📈 **Statistics**: Visual charts and breakdowns of spending by category
- 🔄 **Real-time Updates**: Automatic budget updates when expenses change
- 🎨 **Modern UI**: Clean, intuitive interface with Material 3 design

## Project Structure

```
lib/
├── main.dart                      # App entry point
├── data/
│   ├── client.dart                # API client for server communication
│   ├── model/
│   │   ├── expense.dart           # Expense data model
│   │   ├── budget.dart            # Budget data model
│   │   └── category.dart          # Category definitions with icons/colors
│   └── service/
│       └── expense_service.dart   # Business logic & state management
└── screens/
    ├── home_screen.dart           # Main screen with bottom navigation
    ├── expenses_screen.dart       # List and manage expenses
    ├── add_expense_screen.dart    # Add/edit expense form
    ├── budgets_screen.dart        # View and manage budgets
    └── statistics_screen.dart     # Charts and spending analytics
```

## Setup Instructions

### 1. Accept Xcode License (macOS)
```bash
sudo xcodebuild -license
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Server URL
Update the base URL in `lib/main.dart` to match your backend server:
```dart
final apiClient = ApiClient(
  baseUrl: 'http://your-server-url:port/api',
);
```

### 4. Run the App
```bash
# For web
flutter run -d chrome

# For iOS simulator
flutter run -d ios

# For Android emulator
flutter run -d android

# For macOS desktop
flutter run -d macos
```

## API Client Configuration

The app uses a REST API client (`lib/data/client.dart`) that communicates with your backend server.

### Expense Endpoints
- `GET /expenses` - Get all expenses (with optional filters)
- `GET /expenses/:id` - Get a single expense
- `POST /expenses` - Create new expense
- `PUT /expenses/:id` - Update expense
- `DELETE /expenses/:id` - Delete expense

### Budget Endpoints
- `GET /budgets` - Get all budgets
- `GET /budgets/:id` - Get a single budget
- `POST /budgets` - Create new budget
- `PUT /budgets/:id` - Update budget
- `DELETE /budgets/:id` - Delete budget

### Statistics Endpoints
- `GET /statistics/spending-by-category` - Get spending grouped by category
- `GET /statistics/monthly-spending` - Get monthly spending trends

### Authentication
To add authentication, set the token:
```dart
apiClient.setAuthToken('your-jwt-token');
```

## Dependencies

- **provider**: State management
- **http**: API communication
- **intl**: Date formatting and localization
- **fl_chart**: Charts and graphs
- **shared_preferences**: Local storage

## Default Categories

The app includes 9 predefined categories:
- 🍔 Food & Dining
- 🚗 Transportation  
- 🛍️ Shopping
- 🎬 Entertainment
- 📄 Bills & Utilities
- 🏥 Healthcare
- 🎓 Education
- ✈️ Travel
- ⚙️ Other

