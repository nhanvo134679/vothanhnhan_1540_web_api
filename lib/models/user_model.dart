class UserModel {
  final String username;
  final String email;
  final String? initials;
  final List<String> roles;
  final String? token;

  UserModel({
    required this.username,
    required this.email,
    this.initials,
    this.roles = const [],
    this.token,
  });

  bool get isAdmin => roles.any((r) => r.toLowerCase() == 'admin');
  bool get isStaff => roles.any((r) => r.toLowerCase() == 'staff');
  bool get isCustomer => !isAdmin && !isStaff;

  String get primaryRole {
    if (isAdmin) return 'Admin';
    if (isStaff) return 'Staff';
    if (roles.isNotEmpty) return roles.first;
    return 'User';
  }

  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    List<String> roleList = [];
    if (json['roles'] != null) {
      if (json['roles'] is List) {
        roleList = (json['roles'] as List).map((e) => e.toString()).toList();
      } else if (json['roles'] is String) {
        roleList = [json['roles'].toString()];
      }
    }

    return UserModel(
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      initials: json['initials']?.toString(),
      roles: roleList,
      token: token ?? json['token']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'initials': initials,
      'roles': roles,
      'token': token,
    };
  }
}
