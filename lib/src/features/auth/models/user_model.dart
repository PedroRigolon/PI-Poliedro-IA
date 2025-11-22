class UserModel {
  final String email;
  final String? name;
  final UserType type;

  UserModel({required this.email, this.name, required this.type});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      email: json['email'] as String,
      name: json['name'] as String?,
      type: _parseUserType(json['type'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'type': type.name,
    };
  }

  static UserType _parseUserType(String type) {
    switch (type) {
      case 'professor':
        return UserType.professor;
      case 'student':
        return UserType.student;
      case 'admin':
        return UserType.admin;
      default:
        return UserType.student;
    }
  }
}

enum UserType { professor, student, admin }
