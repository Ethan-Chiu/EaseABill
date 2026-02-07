class Budget {
  final String? id;
  final String category;
  final double limit;
  final double spent;
  final String period; // 'monthly', 'weekly', 'yearly'
  final DateTime startDate;
  final DateTime endDate;
  final String? userId;

  Budget({
    this.id,
    required this.category,
    required this.limit,
    this.spent = 0.0,
    required this.period,
    required this.startDate,
    required this.endDate,
    this.userId,
  });

  double get remaining => limit - spent;
  double get percentage => limit > 0 ? (spent / limit * 100).clamp(0, 100) : 0;
  bool get isExceeded => spent > limit;

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id']?.toString(),
      category: json['category'] as String,
      limit: (json['limit'] as num).toDouble(),
      spent: (json['spent'] as num?)?.toDouble() ?? 0.0,
      period: json['period'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      userId: json['userId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'limit': limit,
      'spent': spent,
      'period': period,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      if (userId != null) 'userId': userId,
    };
  }

  Budget copyWith({
    String? id,
    String? category,
    double? limit,
    double? spent,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      limit: limit ?? this.limit,
      spent: spent ?? this.spent,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      userId: userId ?? this.userId,
    );
  }
}
