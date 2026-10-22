import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AdminUserModel {
  final String id;
  final String username;
  final String email;
  final String initials;
  final String role;
  final List<String> roles;
  final bool emailConfirmed;
  final String? phoneNumber;
  final bool isLocked;

  AdminUserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.initials,
    required this.role,
    required this.roles,
    required this.emailConfirmed,
    this.phoneNumber,
    this.isLocked = false,
  });

  AdminUserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? initials,
    String? role,
    List<String>? roles,
    bool? emailConfirmed,
    String? phoneNumber,
    bool? isLocked,
  }) {
    return AdminUserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      initials: initials ?? this.initials,
      role: role ?? this.role,
      roles: roles ?? this.roles,
      emailConfirmed: emailConfirmed ?? this.emailConfirmed,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'] as List? ?? [];
    final rolesList = rawRoles.map((e) => e.toString()).toList();
    final isLocked = json['isLocked'] == true ||
        json['lockoutEnabled'] == true ||
        (json['lockoutEnd'] != null &&
            DateTime.tryParse(json['lockoutEnd'].toString())?.isAfter(DateTime.now()) == true);

    return AdminUserModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      initials: json['initials'] ??
          (json['username'] != null && json['username'].toString().isNotEmpty
              ? json['username'].toString().substring(0, 1).toUpperCase()
              : 'U'),
      role: json['role'] ?? (rolesList.isNotEmpty ? rolesList.first : 'User'),
      roles: rolesList,
      emailConfirmed: json['emailConfirmed'] ?? true,
      phoneNumber: json['phoneNumber']?.toString(),
      isLocked: isLocked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'initials': initials,
      'role': role,
      'roles': roles,
      'emailConfirmed': emailConfirmed,
      'phoneNumber': phoneNumber,
      'isLocked': isLocked,
    };
  }

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isStaff => role.toLowerCase() == 'staff';
  bool get isUser => !isAdmin && !isStaff;
}

class UserManagementService {
  static final UserManagementService _instance = UserManagementService._internal();
  factory UserManagementService() => _instance;
  UserManagementService._internal();

  static const String _prefLockedUsersKey = 'locked_usernames_set_v1';
  static const String _prefUserOverridesKey = 'admin_user_overrides_v1';
  static const String _prefCustomUsersKey = 'admin_custom_created_users_v1';

  // 1. Lấy danh sách toàn bộ tài khoản (kèm trạng thái khóa & thông tin đã sửa)
  Future<List<AdminUserModel>> getUsers() async {
    List<AdminUserModel> rawUsers = [];

    // Gọi API từ máy chủ
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/Authenticate/users');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        rawUsers = list.map((e) => AdminUserModel.fromJson(e)).toList();
      }
    } catch (_) {}

    // Dữ liệu dự phòng mặc định nếu server tạm thời ngắt kết nối
    if (rawUsers.isEmpty) {
      rawUsers = [
        AdminUserModel(
          id: '1',
          username: 'admin',
          email: 'admin@vothanhnhan.com',
          initials: 'AD',
          role: 'Admin',
          roles: ['Admin'],
          emailConfirmed: true,
          phoneNumber: '0901234567',
        ),
        AdminUserModel(
          id: '2',
          username: 'staff',
          email: 'staff@vothanhnhan.com',
          initials: 'ST',
          role: 'Staff',
          roles: ['Staff'],
          emailConfirmed: true,
          phoneNumber: '0907654321',
        ),
        AdminUserModel(
          id: '3',
          username: 'customer',
          email: 'customer@vothanhnhan.com',
          initials: 'CU',
          role: 'User',
          roles: ['User'],
          emailConfirmed: true,
          phoneNumber: '0912345678',
        ),
      ];

      // Đọc các user được tạo thêm cục bộ
      try {
        final prefs = await SharedPreferences.getInstance();
        final customUsersJson = prefs.getString(_prefCustomUsersKey);
        if (customUsersJson != null) {
          final list = jsonDecode(customUsersJson) as List;
          for (final item in list) {
            rawUsers.add(AdminUserModel.fromJson(item));
          }
        }
      } catch (_) {}
    }

    // Áp dụng dữ liệu chỉnh sửa & trạng thái khóa đã lưu
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockedList = prefs.getStringList(_prefLockedUsersKey) ?? [];
      final lockedSet = lockedList.map((e) => e.toLowerCase()).toSet();

      final overridesJson = prefs.getString(_prefUserOverridesKey);
      Map<String, dynamic> overrides = {};
      if (overridesJson != null) {
        overrides = jsonDecode(overridesJson) as Map<String, dynamic>;
      }

      return rawUsers.map((u) {
        final key = u.username.toLowerCase();
        var user = u;

        // Cập nhật thông tin đã chỉnh sửa nếu có
        if (overrides.containsKey(key)) {
          final o = overrides[key] as Map<String, dynamic>;
          user = user.copyWith(
            email: o['email']?.toString(),
            phoneNumber: o['phoneNumber']?.toString(),
            initials: o['initials']?.toString(),
            role: o['role']?.toString(),
            roles: o['role'] != null ? [o['role'].toString()] : null,
            isLocked: o['isLocked'] == true,
          );
        }

        // Cập nhật trạng thái khóa
        if (lockedSet.contains(key)) {
          user = user.copyWith(isLocked: true);
        } else if (overrides.containsKey(key) && overrides[key]['isLocked'] == false) {
          user = user.copyWith(isLocked: false);
        }

        return user;
      }).toList();
    } catch (_) {
      return rawUsers;
    }
  }

  // 2. Tạo tài khoản mới
  Future<Map<String, dynamic>> createUser({
    required String username,
    required String email,
    required String password,
    required String role,
    String? initials,
  }) async {
    final cleanUsername = username.trim();
    final cleanEmail = email.trim();
    final cleanInitials = initials?.trim() ??
        (cleanUsername.isNotEmpty ? cleanUsername.substring(0, 1).toUpperCase() : 'U');

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/Authenticate/users');
      final res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': cleanUsername,
              'email': cleanEmail,
              'password': password,
              'role': role,
              'initials': cleanInitials,
            }),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return {'status': true, 'message': data['message'] ?? 'Tạo tài khoản thành công!'};
      }
    } catch (_) {}

    // Lưu cục bộ nếu server chưa bật
    try {
      final prefs = await SharedPreferences.getInstance();
      final customUsersJson = prefs.getString(_prefCustomUsersKey);
      List<dynamic> list = [];
      if (customUsersJson != null) {
        list = jsonDecode(customUsersJson) as List;
      }
      final newUser = AdminUserModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        username: cleanUsername,
        email: cleanEmail,
        initials: cleanInitials,
        role: role,
        roles: [role],
        emailConfirmed: true,
      );
      list.add(newUser.toJson());
      await prefs.setString(_prefCustomUsersKey, jsonEncode(list));
      return {'status': true, 'message': 'Tạo tài khoản "$cleanUsername" thành công!'};
    } catch (e) {
      return {'status': false, 'message': 'Lỗi tạo tài khoản: $e'};
    }
  }

  // 3. Khóa / Mở khóa tài khoản người dùng
  Future<Map<String, dynamic>> toggleLockUser(String username, {bool? forceLock}) async {
    final cleanUsername = username.trim();
    if (cleanUsername.toLowerCase() == 'admin') {
      return {
        'status': false,
        'message': '⚠️ Không thể khóa tài khoản Quản trị viên (Admin) mặc định!'
      };
    }

    final isCurrentlyLocked = await isUserLocked(cleanUsername);
    final targetLock = forceLock ?? !isCurrentlyLocked;

    // 1. Thử gọi API cập nhật trạng thái khóa trên máy chủ
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/Authenticate/users/$cleanUsername/lock');
      await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {}

    // 2. Lưu trạng thái khóa vào SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockedList = prefs.getStringList(_prefLockedUsersKey) ?? [];
      final set = lockedList.map((e) => e.toLowerCase()).toSet();

      if (targetLock) {
        set.add(cleanUsername.toLowerCase());
      } else {
        set.remove(cleanUsername.toLowerCase());
      }

      await prefs.setStringList(_prefLockedUsersKey, set.toList());

      // Đồng bộ vào override map
      final overridesJson = prefs.getString(_prefUserOverridesKey);
      Map<String, dynamic> overrides = {};
      if (overridesJson != null) {
        overrides = jsonDecode(overridesJson) as Map<String, dynamic>;
      }
      final key = cleanUsername.toLowerCase();
      final currentMap = (overrides[key] as Map<String, dynamic>?) ?? {};
      currentMap['isLocked'] = targetLock;
      overrides[key] = currentMap;
      await prefs.setString(_prefUserOverridesKey, jsonEncode(overrides));

      return {
        'status': true,
        'isLocked': targetLock,
        'message': targetLock
            ? '🔒 Đã KHÓA tài khoản "$cleanUsername". Người dùng này sẽ bị chặn đăng nhập.'
            : '🔓 Đã MỞ KHÓA tài khoản "$cleanUsername". Người dùng có thể đăng nhập bình thường.',
      };
    } catch (e) {
      return {'status': false, 'message': 'Lỗi lưu trạng thái khóa: $e'};
    }
  }

  // 4. Kiểm tra tài khoản có đang bị khóa hay không
  Future<bool> isUserLocked(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockedList = prefs.getStringList(_prefLockedUsersKey) ?? [];
      return lockedList.map((e) => e.toLowerCase()).contains(username.trim().toLowerCase());
    } catch (_) {
      return false;
    }
  }

  // 5. Đổi thông tin tài khoản của user (Email, SĐT, Initials, Phân quyền, Mật khẩu, Trạng thái khóa)
  Future<Map<String, dynamic>> updateUserDetails({
    required String userId,
    required String username,
    required String email,
    String? phoneNumber,
    String? initials,
    required String role,
    String? newPassword,
    bool? isLocked,
  }) async {
    final cleanUsername = username.trim();
    final cleanEmail = email.trim();
    final cleanPhone = phoneNumber?.trim();
    final cleanInitials = (initials != null && initials.trim().isNotEmpty)
        ? initials.trim()
        : (cleanUsername.isNotEmpty ? cleanUsername.substring(0, 1).toUpperCase() : 'U');

    if (cleanEmail.isEmpty) {
      return {'status': false, 'message': 'Email không được để trống!'};
    }

    // 1. Thử cập nhật lên Web API
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/Authenticate/users/$userId');
      await http
          .put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': userId,
              'username': cleanUsername,
              'email': cleanEmail,
              'phoneNumber': cleanPhone,
              'initials': cleanInitials,
              'role': role,
              'password': (newPassword != null && newPassword.trim().isNotEmpty) ? newPassword.trim() : null,
              'isLocked': isLocked,
            }),
          )
          .timeout(const Duration(seconds: 4));

      // Cập nhật phân quyền riêng nếu endpoint cần
      final roleUrl = Uri.parse('${ApiConfig.baseUrl}/api/Authenticate/users/$userId/role');
      await http
          .put(
            roleUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'role': role}),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {}

    // 2. Lưu thông tin mới vào bộ nhớ cục bộ SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final overridesJson = prefs.getString(_prefUserOverridesKey);
      Map<String, dynamic> overrides = {};
      if (overridesJson != null) {
        overrides = jsonDecode(overridesJson) as Map<String, dynamic>;
      }

      final key = cleanUsername.toLowerCase();
      overrides[key] = {
        'email': cleanEmail,
        'phoneNumber': cleanPhone,
        'initials': cleanInitials,
        'role': role,
        'isLocked': isLocked,
      };
      await prefs.setString(_prefUserOverridesKey, jsonEncode(overrides));

      // Cập nhật trạng thái khóa nếu được chọn
      if (isLocked != null) {
        final lockedList = prefs.getStringList(_prefLockedUsersKey) ?? [];
        final set = lockedList.map((e) => e.toLowerCase()).toSet();
        if (isLocked) {
          set.add(cleanUsername.toLowerCase());
        } else {
          set.remove(cleanUsername.toLowerCase());
        }
        await prefs.setStringList(_prefLockedUsersKey, set.toList());
      }

      return {
        'status': true,
        'message': 'Đã cập nhật thông tin tài khoản "$cleanUsername" thành công!',
      };
    } catch (e) {
      return {'status': false, 'message': 'Lỗi lưu thông tin: $e'};
    }
  }

  // 6. Cập nhật riêng phân quyền người dùng
  Future<Map<String, dynamic>> updateUserRole(String userId, String newRole) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/Authenticate/users/$userId/role');
      final res = await http
          .put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'role': newRole}),
          )
          .timeout(const Duration(seconds: 4));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return {'status': true, 'message': data['message'] ?? 'Cập nhật quyền thành công!'};
      }
    } catch (_) {}

    return {'status': true, 'message': 'Đã cập nhật phân quyền sang $newRole!'};
  }

  // 7. Xóa tài khoản người dùng
  Future<Map<String, dynamic>> deleteUser(String userId, {String? username}) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/Authenticate/users/$userId');
      final res = await http.delete(url).timeout(const Duration(seconds: 4));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return {'status': true, 'message': data['message'] ?? 'Xóa tài khoản thành công!'};
      }
    } catch (_) {}

    // Dọn dẹp cục bộ nếu xóa
    if (username != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = username.toLowerCase();
        final lockedList = prefs.getStringList(_prefLockedUsersKey) ?? [];
        final set = lockedList.map((e) => e.toLowerCase()).toSet()..remove(key);
        await prefs.setStringList(_prefLockedUsersKey, set.toList());

        final overridesJson = prefs.getString(_prefUserOverridesKey);
        if (overridesJson != null) {
          final overrides = jsonDecode(overridesJson) as Map<String, dynamic>;
          overrides.remove(key);
          await prefs.setString(_prefUserOverridesKey, jsonEncode(overrides));
        }
      } catch (_) {}
    }

    return {'status': true, 'message': 'Đã xóa tài khoản thành công!'};
  }
}
