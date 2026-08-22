

enum TransactionType { expense, income }

class TransactionModel {
  final String id;
  final String uid;
  final TransactionType type;
  final double amount;
  final String category;
  final String paymentMethod;
  final String description;
  final String? notes;
  final List<String> tags;
  final String? receiptPath;
  final DateTime date;
  final bool isRecurring;
  final String? linkedTransactionId;
  final bool isDuplicate;
  final DateTime createdAt;
  /// Normalized fingerprint of the raw SMS body used for exact-SMS deduplication.
  /// Null for manually entered transactions.
  final String? smsHash;

  TransactionModel({
    required this.id,
    required this.uid,
    required this.type,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    required this.description,
    this.notes,
    this.tags = const [],
    this.receiptPath,
    required this.date,
    this.isRecurring = false,
    this.linkedTransactionId,
    this.isDuplicate = false,
    this.smsHash,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'type': type.name,
      'amount': amount,
      'category': category,
      'paymentMethod': paymentMethod,
      'description': description,
      'notes': notes,
      'tags': tags,
      'receiptPath': receiptPath,
      'date': date.toIso8601String(),
      'isRecurring': isRecurring,
      'linkedTransactionId': linkedTransactionId,
      'isDuplicate': isDuplicate,
      'smsHash': smsHash,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<dynamic, dynamic> map) {
    return TransactionModel(
      id: map['id'] ?? '',
      uid: map['uid'] ?? 'local_user',
      type: map['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] ?? 'General',
      paymentMethod: map['paymentMethod'] ?? 'Cash',
      description: map['description'] ?? '',
      notes: map['notes'] as String?,
      tags: map['tags'] != null ? List<String>.from(map['tags']) : const [],
      receiptPath: map['receiptPath'],
      date: DateTime.parse(map['date']),
      isRecurring: map['isRecurring'] ?? false,
      linkedTransactionId: map['linkedTransactionId'],
      isDuplicate: map['isDuplicate'] ?? false,
      smsHash: map['smsHash'] as String?,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
    );
  }

  TransactionModel copyWith({
    String? id,
    String? uid,
    TransactionType? type,
    double? amount,
    String? category,
    String? paymentMethod,
    String? description,
    String? notes,
    List<String>? tags,
    String? receiptPath,
    DateTime? date,
    bool? isRecurring,
    String? linkedTransactionId,
    bool? isDuplicate,
    String? smsHash,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      receiptPath: receiptPath ?? this.receiptPath,
      date: date ?? this.date,
      isRecurring: isRecurring ?? this.isRecurring,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      smsHash: smsHash ?? this.smsHash,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
