import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_management_service.dart';
import '../auth/login_screen.dart';
import '../utilities/camera_translator_screen.dart';
import '../utilities/location_share_screen.dart';
import '../utilities/noise_meter_screen.dart';
import 'manage_users_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AuthService _auth = AuthService();
  final UserManagementService _userService = UserManagementService();

  Map<String, dynamic>? _adminData;
  List<AdminUserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    final data = await _auth.fetchAdminDashboard();
    final users = await _userService.getUsers();

    if (!mounted) return;
    setState(() {
      _adminData = data;
      _users = users;
      _isLoading = false;
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi hệ thống?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _auth.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final totalUsers = _users.length;
    final adminCount = _users.where((u) => u.isAdmin).length;
    final staffOrCustomerCount = _users.where((u) => !u.isAdmin).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang Quản Trị (Admin Portal)'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Admin Profile Banner
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.indigo.shade800, Colors.blue.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigo.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.indigo.shade800,
                            child: Text(
                              (user?.initials?.isNotEmpty == true
                                      ? user!.initials!
                                      : user?.username.substring(0, 1) ?? 'A')
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      user?.username ?? 'Admin',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade400,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'ADMIN',
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.email ?? '',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _adminData?['message'] ?? 'Toàn quyền quản trị hệ thống',
                                  style: TextStyle(color: Colors.amber.shade200, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Thống Kê Tài Khoản Hệ Thống
                    const Text(
                      'Thống Kê Tài Khoản',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Tổng tài khoản',
                            count: '$totalUsers',
                            icon: Icons.people_alt_rounded,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Quản trị viên',
                            count: '$adminCount',
                            icon: Icons.admin_panel_settings_rounded,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Nhân viên & Khách',
                            count: '$staffOrCustomerCount',
                            icon: Icons.badge_rounded,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // PHẦN QUẢN LÝ TÀI KHOẢN (USER MANAGEMENT)
                    const Text(
                      'Quản Lý Hệ Thống',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    _buildNavCard(
                      title: 'Quản Lý Tài Khoản (User Management)',
                      subtitle: 'Xem danh sách, sửa thông tin người dùng, khóa / mở khóa tài khoản, phân quyền và xóa tài khoản',
                      icon: Icons.manage_accounts_rounded,
                      color: Colors.indigo.shade700,
                      tag: 'Quản Trị',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ManageUsersScreen()),
                        );
                        _loadDashboard();
                      },
                    ),

                    const SizedBox(height: 28),

                    // PHẦN TIỆN ÍCH
                    const Text(
                      'Các Chức Năng Tiện Ích',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Nút chức năng 1: Đo tiếng ồn
                    _buildNavCard(
                      title: '1. Đo Tiếng Ồn (Noise Meter dB)',
                      subtitle: 'Đo cường độ âm thanh Decibel thời gian thực, đồng hồ đo vòng cung, biểu đồ sóng âm và lưu API',
                      icon: Icons.graphic_eq_rounded,
                      color: Colors.teal.shade700,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const NoiseMeterScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Nút chức năng 2: Chia sẻ vị trí
                    _buildNavCard(
                      title: '2. Chia Sẻ Vị Trí (Location GPS)',
                      subtitle: 'Tọa độ GPS, định vị radar vệ tinh, tự động dịch địa chỉ và chia sẻ qua Zalo, SMS, Google Maps',
                      icon: Icons.explore_rounded,
                      color: Colors.cyan.shade800,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LocationShareScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Nút chức năng 3: Dịch tiếng Anh realtime bằng camera
                    _buildNavCard(
                      title: '3. Dịch Tiếng Anh Bằng Camera (OCR)',
                      subtitle: 'Quét camera ống kính thời gian thực, nhận diện biển hiệu tiếng Anh và dịch ngay sang tiếng Việt',
                      icon: Icons.camera_alt_rounded,
                      color: Colors.amber.shade800,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CameraTranslatorScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            count,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildNavCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? tag,
    bool isHighlighted = false,
  }) {
    return Card(
      elevation: isHighlighted ? 3 : 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isHighlighted ? color : color.withValues(alpha: 0.25),
          width: isHighlighted ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (tag != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: color.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
