class User {
  final String id;
  final String name;
  final String phoneNumber;
  final String email;
  final double balance;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int? _age;
  final String? _gender;

  User({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.email,
    required this.balance,
    required this.createdAt,
    this.updatedAt,
    int? age,
    String? gender,
  }) : _age = age, _gender = gender;

  // Getters for backward compatibility
  String get phone => phoneNumber;
  int? get age => _age;
  String? get gender => _gender;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? json['phone'] ?? '',
      email: json['email'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'balance': balance,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'age': _age,
      'gender': _gender,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? email,
    double? balance,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? age,
    String? gender,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      age: age ?? _age,
      gender: gender ?? _gender,
    );
  }
}
