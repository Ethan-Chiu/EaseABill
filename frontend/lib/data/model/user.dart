class User {
  final String? id;
  final String username;
  final String? location;
  final double? monthlyIncome;
  final double? budgetGoal;
  final bool isOnboarded;

  User({
    this.id,
    required this.username,
    this.location,
    this.monthlyIncome,
    this.budgetGoal,
    this.isOnboarded = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      location: json['location'],
      monthlyIncome: json['monthlyIncome']?.toDouble(),
      budgetGoal: json['budgetGoal']?.toDouble(),
      isOnboarded: json['isOnboarded'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'username': username,
      if (location != null) 'location': location,
      if (monthlyIncome != null) 'monthlyIncome': monthlyIncome,
      if (budgetGoal != null) 'budgetGoal': budgetGoal,
      'isOnboarded': isOnboarded,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? location,
    double? monthlyIncome,
    double? budgetGoal,
    bool? isOnboarded,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      location: location ?? this.location,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      budgetGoal: budgetGoal ?? this.budgetGoal,
      isOnboarded: isOnboarded ?? this.isOnboarded,
    );
  }
}
