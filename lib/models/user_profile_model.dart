class UserProfileModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String currency;
  final bool isDarkMode;

  UserProfileModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.currency = '₹',
    this.isDarkMode = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'currency': currency,
      'isDarkMode': isDarkMode,
    };
  }

  factory UserProfileModel.fromMap(Map<dynamic, dynamic> map) {
    return UserProfileModel(
      uid: map['uid'] ?? 'local_user',
      name: map['name'] ?? 'User',
      email: map['email'] ?? 'user@pocketify.app',
      photoUrl: map['photoUrl'],
      currency: map['currency'] ?? '₹',
      isDarkMode: map['isDarkMode'] ?? false,
    );
  }
}
