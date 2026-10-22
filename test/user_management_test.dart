import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vothanhnhan_1540_web_api/services/auth_service.dart';
import 'package:vothanhnhan_1540_web_api/services/user_management_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AdminUserModel serialization and copyWith with isLocked', () {
    final user = AdminUserModel(
      id: '10',
      username: 'testuser',
      email: 'test@example.com',
      initials: 'TU',
      role: 'User',
      roles: ['User'],
      emailConfirmed: true,
      phoneNumber: '0123456789',
      isLocked: false,
    );

    expect(user.isLocked, isFalse);

    final lockedUser = user.copyWith(isLocked: true);
    expect(lockedUser.isLocked, isTrue);

    final json = lockedUser.toJson();
    expect(json['isLocked'], isTrue);

    final fromJsonUser = AdminUserModel.fromJson(json);
    expect(fromJsonUser.isLocked, isTrue);
    expect(fromJsonUser.username, equals('testuser'));
  });

  test('UserManagementService toggleLockUser persists and updates lock state', () async {
    final service = UserManagementService();

    // Primary admin cannot be locked
    final adminLockRes = await service.toggleLockUser('admin');
    expect(adminLockRes['status'], isFalse);

    // Lock regular user
    final lockRes = await service.toggleLockUser('staff');
    expect(lockRes['status'], isTrue);
    expect(lockRes['isLocked'], isTrue);

    bool isLocked = await service.isUserLocked('staff');
    expect(isLocked, isTrue);

    // Unlock regular user
    final unlockRes = await service.toggleLockUser('staff');
    expect(unlockRes['status'], isTrue);
    expect(unlockRes['isLocked'], isFalse);

    isLocked = await service.isUserLocked('staff');
    expect(isLocked, isFalse);
  });

  test('UserManagementService updateUserDetails updates and persists info', () async {
    final service = UserManagementService();

    final updateRes = await service.updateUserDetails(
      userId: '2',
      username: 'staff',
      email: 'new_staff@vothanhnhan.com',
      phoneNumber: '0988776655',
      initials: 'NS',
      role: 'Staff',
      isLocked: true,
    );

    expect(updateRes['status'], isTrue);

    final users = await service.getUsers();
    final staff = users.firstWhere((u) => u.username == 'staff');
    expect(staff.email, equals('new_staff@vothanhnhan.com'));
    expect(staff.phoneNumber, equals('0988776655'));
    expect(staff.initials, equals('NS'));
    expect(staff.isLocked, isTrue);
  });

  test('AuthService login for Admin skips OTP while Staff requires OTP', () async {
    final auth = AuthService();

    // 1. Admin login -> requiresOtp must be FALSE
    final adminLogin = await auth.login(username: 'admin', password: 'Admin@123');
    expect(adminLogin.isSuccess, isTrue);
    expect(adminLogin.requiresOtp, isFalse);

    // 2. Staff login -> requiresOtp must be TRUE
    final staffLogin = await auth.login(username: 'staff', password: 'Staff@123');
    expect(staffLogin.isSuccess, isTrue);
    expect(staffLogin.requiresOtp, isTrue);
    expect(staffLogin.otpDev, isNotNull);
  });
}
