class BudgetModel {
  final String id;
  final String uid;
  final String category;
  final double monthlyLimit;

  BudgetModel({
    required this.id,
    required this.uid,
    required this.category,
    required this.monthlyLimit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'category': category,
      'monthlyLimit': monthlyLimit,
    };
  }

  factory BudgetModel.fromMap(Map<dynamic, dynamic> map) {
    return BudgetModel(
      id: map['id'] ?? '',
      uid: map['uid'] ?? 'local_user',
      category: map['category'] ?? '',
      monthlyLimit: (map['monthlyLimit'] as num).toDouble(),
    );
  }
}
