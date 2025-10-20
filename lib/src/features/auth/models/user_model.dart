class UserModel {
  final String email;
  final String? name;
  final UserType type;

  UserModel({required this.email, this.name, required this.type});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      email: json['email'] as String,
      name: json['name'] as String?,
      type: json['type'] == 'professor' ? UserType.professor : UserType.student,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'type': type == UserType.professor ? 'professor' : 'student',
    };
  }
}

enum UserType { professor, student }
