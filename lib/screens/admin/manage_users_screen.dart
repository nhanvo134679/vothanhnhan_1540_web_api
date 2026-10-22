// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_management_service.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final UserManagementService _userService = UserManagementService();
  final AuthService _auth = AuthService();

  List<AdminUserModel> _allUsers = [];
  List<AdminUserModel> _filteredUsers = [];
  bool _isLoading = true;
  String _selectedRoleFilter = 'ALL';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _userService.getUsers();
    if (!mounted) return;
    setState(() {
      _allUsers = users;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    List<AdminUserModel> list = _allUsers;
    if (_selectedRoleFilter == 'LOCKED') {
      list = list.where((u) => u.isLocked).toList();
    } else if (_selectedRoleFilter != 'ALL') {
      list = list.where((u) => u.role.toUpperCase() == _selectedRoleFilter).toList();
    }

    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((u) =>
              u.username.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q) ||
              (u.phoneNumber != null && u.phoneNumber!.toLowerCase().contains(q)) ||
              u.role.toLowerCase().contains(q))
          .toList();
    }
    setState(() => _filteredUsers = list);
  }

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return Colors.red.shade700;
      case 'STAFF':
        return Colors.teal.shade700;
      default:
        return Colors.indigo.shade600;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return Icons.admin_panel_settings_rounded;
      case 'STAFF':
        return Icons.badge_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _getRoleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return 'Quản trị viên (Admin)';
      case 'STAFF':
        return 'Nhân viên (Staff)';
      default:
        return 'Khách hàng (User)';
    }
  }

  /// 1. Dialog Thêm Tài Khoản Mới
  void _showAddUserDialog() {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController(text: 'User@123');
    final initialsController = TextEditingController();
    String selectedRole = 'User';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.person_add_rounded, color: Colors.indigo),
                  SizedBox(width: 10),
                  Text('Thêm Tài Khoản Mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên đăng nhập *',
                        prefixIcon: Icon(Icons.account_circle_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu khởi tạo *',
                        prefixIcon: Icon(Icons.lock_outline),
                        helperText: 'Tối thiểu 6 ký tự, có chữ hoa, thường & số',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: initialsController,
                      maxLength: 5,
                      decoration: const InputDecoration(
                        labelText: 'Ký hiệu đại diện (Initials, tối đa 5 ký tự)',
                        hintText: 'VD: VN, AD, NV',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Phân quyền tài khoản *',
                        prefixIcon: Icon(Icons.security_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Admin', child: Text('Quản trị viên (Admin)')),
                        DropdownMenuItem(value: 'Staff', child: Text('Nhân viên (Staff)')),
                        DropdownMenuItem(value: 'User', child: Text('Khách hàng (User)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedRole = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade700),
                  onPressed: () async {
                    final u = usernameController.text.trim();
                    final p = passwordController.text.trim();
                    final e = emailController.text.trim();
                    if (u.isEmpty || p.isEmpty || e.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng điền đủ Tên đăng nhập, Email và Mật khẩu!')),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    final res = await _userService.createUser(
                      username: u,
                      email: e,
                      password: p,
                      role: selectedRole,
                      initials: initialsController.text.trim(),
                    );

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? ''),
                        backgroundColor: res['status'] == true ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    );
                    _loadUsers();
                  },
                  child: const Text('Tạo tài khoản', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 2. Dialog Chỉnh Sửa Thông Tin Tài Khoản User
  void _showEditUserDialog(AdminUserModel user) {
    final emailController = TextEditingController(text: user.email);
    final phoneController = TextEditingController(text: user.phoneNumber ?? '');
    final initialsController = TextEditingController(text: user.initials);
    final passwordController = TextEditingController();
    String selectedRole = user.role;
    bool isLocked = user.isLocked;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: Colors.indigo, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sửa Tài Khoản: ${user.username}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Username (Read-only)
                    TextFormField(
                      initialValue: user.username,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Tên đăng nhập (Khóa cố định)',
                        prefixIcon: Icon(Icons.account_circle_outlined),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Email
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Phone Number
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        hintText: 'VD: 0901234567',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Initials
                    TextField(
                      controller: initialsController,
                      maxLength: 5,
                      decoration: const InputDecoration(
                        labelText: 'Ký hiệu đại diện (Initials, tối đa 5 ký tự)',
                        hintText: 'VD: VN, AD, NV',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Role Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Phân quyền tài khoản *',
                        prefixIcon: Icon(Icons.security_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Admin', child: Text('Quản trị viên (Admin)')),
                        DropdownMenuItem(value: 'Staff', child: Text('Nhân viên (Staff)')),
                        DropdownMenuItem(value: 'User', child: Text('Khách hàng (User)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedRole = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // New Password (Optional)
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Đổi mật khẩu mới (Tùy chọn)',
                        hintText: 'Để trống nếu giữ nguyên mật khẩu cũ',
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Switch Khóa / Mở khóa tài khoản
                    Container(
                      decoration: BoxDecoration(
                        color: isLocked ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isLocked ? Colors.red.shade300 : Colors.green.shade300,
                        ),
                      ),
                      child: SwitchListTile(
                        value: isLocked,
                        activeColor: Colors.red.shade700,
                        title: Text(
                          isLocked ? '🔒 Tài khoản ĐANG BỊ KHÓA' : '🔓 Tài khoản ĐANG HOẠT ĐỘNG',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isLocked ? Colors.red.shade900 : Colors.green.shade900,
                          ),
                        ),
                        subtitle: Text(
                          isLocked
                              ? 'Người dùng bị chặn đăng nhập vào hệ thống'
                              : 'Người dùng có thể đăng nhập bình thường',
                          style: TextStyle(
                            fontSize: 11,
                            color: isLocked ? Colors.red.shade700 : Colors.green.shade700,
                          ),
                        ),
                        onChanged: user.username.toLowerCase() == 'admin'
                            ? null
                            : (val) => setDialogState(() => isLocked = val),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade700),
                  onPressed: () async {
                    final newEmail = emailController.text.trim();
                    if (newEmail.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('⚠️ Email không được để trống!')),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);

                    final res = await _userService.updateUserDetails(
                      userId: user.id,
                      username: user.username,
                      email: newEmail,
                      phoneNumber: phoneController.text.trim(),
                      initials: initialsController.text.trim(),
                      role: selectedRole,
                      newPassword: passwordController.text.trim(),
                      isLocked: isLocked,
                    );

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? ''),
                        backgroundColor: res['status'] == true
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    );
                    _loadUsers();
                  },
                  child: const Text('Lưu thay đổi', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 3. Xác nhận Khóa / Mở Khóa Tài Khoản
  void _confirmToggleLock(AdminUserModel user) {
    if (user.username.toLowerCase() == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Không thể khóa tài khoản Quản trị viên (Admin) mặc định!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final willLock = !user.isLocked;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                willLock ? Icons.lock_person_rounded : Icons.lock_open_rounded,
                color: willLock ? Colors.red.shade700 : Colors.green.shade700,
              ),
              const SizedBox(width: 8),
              Text(willLock ? 'Khóa Tài Khoản' : 'Mở Khóa Tài Khoản'),
            ],
          ),
          content: Text(
            willLock
                ? 'Bạn có chắc chắn muốn KHÓA tài khoản "${user.username}" (${user.email})?\n\nNgười dùng này sẽ bị chặn đăng nhập vào hệ thống ngay lập tức.'
                : 'Bạn có chắc chắn muốn MỞ KHÓA cho tài khoản "${user.username}"?\n\nNgười dùng này sẽ có thể đăng nhập bình thường.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: willLock ? Colors.red.shade700 : Colors.green.shade700,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);

                final res = await _userService.toggleLockUser(user.username, forceLock: willLock);

                messenger.showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? ''),
                    backgroundColor: res['status'] == true
                        ? (willLock ? Colors.deepOrange : Colors.green.shade700)
                        : Colors.red.shade700,
                  ),
                );
                _loadUsers();
              },
              child: Text(
                willLock ? 'Khóa tài khoản' : 'Mở khóa ngay',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 4. Đổi phân quyền nhanh
  void _showChangeRoleDialog(AdminUserModel user) {
    String currentRole = user.role;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Đổi Phân Quyền: ${user.username}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('Quản trị viên (Admin)'),
                    subtitle: const Text('Toàn quyền quản trị hệ thống và người dùng'),
                    value: 'Admin',
                    groupValue: currentRole,
                    onChanged: (v) => setDialogState(() => currentRole = v!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Nhân viên (Staff)'),
                    subtitle: const Text('Quản lý kho hàng và hỗ trợ khách hàng'),
                    value: 'Staff',
                    groupValue: currentRole,
                    onChanged: (v) => setDialogState(() => currentRole = v!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Khách hàng (User)'),
                    subtitle: const Text('Mua sắm, xem bài viết và sử dụng tiện ích'),
                    value: 'User',
                    groupValue: currentRole,
                    onChanged: (v) => setDialogState(() => currentRole = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    final res = await _userService.updateUserRole(user.id, currentRole);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? ''),
                        backgroundColor: res['status'] == true ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    );
                    _loadUsers();
                  },
                  child: const Text('Lưu thay đổi', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 5. Xóa tài khoản
  void _confirmDeleteUser(AdminUserModel user) {
    if (user.username.toLowerCase() == 'admin' || user.username == _auth.currentUser?.username) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Không thể xóa tài khoản Admin mặc định hoặc tài khoản đang đăng nhập!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Xác nhận xóa tài khoản'),
            ],
          ),
          content: Text('Bạn có chắc chắn muốn xóa vĩnh viễn tài khoản "${user.username}" (${user.email}) khỏi hệ thống?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _userService.deleteUser(user.id, username: user.username);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? ''),
                    backgroundColor: res['status'] == true ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                );
                _loadUsers();
              },
              child: const Text('Xóa tài khoản', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminCount = _allUsers.where((u) => u.isAdmin).length;
    final staffCount = _allUsers.where((u) => u.isStaff).length;
    final userCount = _allUsers.where((u) => u.isUser).length;
    final lockedCount = _allUsers.where((u) => u.isLocked).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Tài Khoản'),
        backgroundColor: Colors.indigo.shade800,
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadUsers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Thêm tài khoản', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddUserDialog,
      ),
      body: Column(
        children: [
          // Role Counter Chips Header (kèm bộ lọc Locked)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.indigo.shade50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'Tất cả (${_allUsers.length})', Icons.people_alt_rounded, Colors.indigo.shade700),
                  const SizedBox(width: 8),
                  _buildFilterChip('ADMIN', 'Admin ($adminCount)', Icons.admin_panel_settings_rounded, Colors.red.shade700),
                  const SizedBox(width: 8),
                  _buildFilterChip('STAFF', 'Staff ($staffCount)', Icons.badge_rounded, Colors.teal.shade700),
                  const SizedBox(width: 8),
                  _buildFilterChip('USER', 'User ($userCount)', Icons.person_rounded, Colors.blue.shade700),
                  const SizedBox(width: 8),
                  _buildFilterChip('LOCKED', 'Đã khóa ($lockedCount)', Icons.lock_rounded, Colors.orange.shade800),
                ],
              ),
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên đăng nhập, email, SĐT, vai trò...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilter();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (_) => _applyFilter(),
            ),
          ),

          // User List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.manage_accounts_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Không tìm thấy tài khoản phù hợp',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 80),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (ctx, idx) {
                            final user = _filteredUsers[idx];
                            final roleColor = _getRoleColor(user.role);
                            final roleIcon = _getRoleIcon(user.role);

                            return Card(
                              elevation: user.isLocked ? 0.8 : 1.5,
                              margin: const EdgeInsets.only(bottom: 10),
                              color: user.isLocked ? Colors.red.shade50.withValues(alpha: 0.35) : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: user.isLocked
                                      ? Colors.red.shade300
                                      : roleColor.withValues(alpha: 0.25),
                                  width: user.isLocked ? 1.5 : 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                onTap: () => _showEditUserDialog(user),
                                leading: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: user.isLocked
                                          ? Colors.red.shade100
                                          : roleColor.withValues(alpha: 0.15),
                                      foregroundColor: user.isLocked ? Colors.red.shade800 : roleColor,
                                      child: Text(
                                        user.initials,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    if (user.isLocked)
                                      Positioned(
                                        bottom: -2,
                                        right: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade700,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                          ),
                                          child: const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        user.username,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: user.isLocked ? Colors.red.shade900 : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    // Badge vai trò
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: roleColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: roleColor.withValues(alpha: 0.5)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(roleIcon, size: 13, color: roleColor),
                                          const SizedBox(width: 4),
                                          Text(
                                            user.role.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: roleColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Badge đã khóa nếu isLocked
                                    if (user.isLocked)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.red.shade400),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.lock_rounded, size: 11, color: Colors.red.shade800),
                                            const SizedBox(width: 2),
                                            Text(
                                              'ĐÃ KHÓA',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      user.email,
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                    ),
                                    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'SĐT: ${user.phoneNumber}',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                        ),
                                      ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Text(
                                          _getRoleLabel(user.role),
                                          style: TextStyle(fontSize: 11, color: roleColor, fontWeight: FontWeight.w500),
                                        ),
                                        const Text(' • ', style: TextStyle(color: Colors.grey)),
                                        Text(
                                          user.isLocked ? '⛔ Đang bị khóa' : '✅ Hoạt động',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: user.isLocked ? Colors.red.shade700 : Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  onSelected: (val) {
                                    if (val == 'edit') {
                                      _showEditUserDialog(user);
                                    } else if (val == 'role') {
                                      _showChangeRoleDialog(user);
                                    } else if (val == 'lock') {
                                      _confirmToggleLock(user);
                                    } else if (val == 'delete') {
                                      _confirmDeleteUser(user);
                                    }
                                  },
                                  itemBuilder: (c) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_note_rounded, size: 18, color: Colors.indigo),
                                          SizedBox(width: 10),
                                          Text('Sửa thông tin tài khoản'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'role',
                                      child: Row(
                                        children: [
                                          Icon(Icons.published_with_changes_rounded, size: 18, color: Colors.teal),
                                          SizedBox(width: 10),
                                          Text('Đổi phân quyền'),
                                        ],
                                      ),
                                    ),
                                    if (user.username.toLowerCase() != 'admin')
                                      PopupMenuItem(
                                        value: 'lock',
                                        child: Row(
                                          children: [
                                            Icon(
                                              user.isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                                              size: 18,
                                              color: user.isLocked ? Colors.green : Colors.deepOrange,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              user.isLocked ? 'Mở khóa tài khoản' : 'Khóa tài khoản',
                                              style: TextStyle(
                                                color: user.isLocked ? Colors.green.shade800 : Colors.deepOrange.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (user.username.toLowerCase() != 'admin')
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                            SizedBox(width: 10),
                                            Text('Xóa tài khoản', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon, Color color) {
    final isSelected = _selectedRoleFilter == key;
    return ChoiceChip(
      selected: isSelected,
      selectedColor: color,
      backgroundColor: Colors.white,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSelected ? Colors.white : color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
      onSelected: (_) {
        setState(() {
          _selectedRoleFilter = key;
          _applyFilter();
        });
      },
    );
  }
}
