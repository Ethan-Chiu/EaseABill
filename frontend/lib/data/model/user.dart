class User {
  final String? id;
  final String username;
  final String? location;
  final double? latitude;
  final double? longitude;
  final double? monthlyIncome;
  final double? budgetGoal;
  final bool isOnboarded;

  User({
    this.id,
    required this.username,
    this.location,
    this.latitude,
    this.longitude,
    this.monthlyIncome,
    this.budgetGoal,
    this.isOnboarded = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      location: json['location'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
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
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (monthlyIncome != null) 'monthlyIncome': monthlyIncome,
      if (budgetGoal != null) 'budgetGoal': budgetGoal,
      'isOnboarded': isOnboarded,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? location,
    double? latitude,
    double? longitude,
    double? monthlyIncome,
    double? budgetGoal,
    bool? isOnboarded,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      budgetGoal: budgetGoal ?? this.budgetGoal,
      isOnboarded: isOnboarded ?? this.isOnboarded,
    );
  }
}
