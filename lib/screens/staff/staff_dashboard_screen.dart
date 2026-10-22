import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../utilities/camera_translator_screen.dart';
import '../utilities/location_share_screen.dart';
import '../utilities/noise_meter_screen.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  final AuthService _auth = AuthService();
  Map<String, dynamic>? _staffData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStaffDashboard();
  }

  Future<void> _loadStaffDashboard() async {
    setState(() => _isLoading = true);
    final data = await _auth.fetchStaffDashboard();
    if (!mounted) return;
    setState(() {
      _staffData = data;
      _isLoading = false;
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Đăng Xuất'),
          ],
        ),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản nhân viên?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Đăng Xuất'),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Dashboard Nhân Viên (Staff Portal)'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            tooltip: 'Làm mới dữ liệu',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStaffDashboard,
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStaffDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner Thông Tin Nhân Viên
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blueGrey.shade800, Colors.teal.shade800],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueGrey.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blueGrey.shade800,
                            child: Text(
                              (user?.initials?.isNotEmpty == true
                                      ? user!.initials!
                                      : user?.username.substring(0, 1) ?? 'S')
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 24,
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
                                    Flexible(
                                      child: Text(
                                        user?.username ?? 'Nhân Viên',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.tealAccent.shade400,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'STAFF',
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
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _staffData?['message'] ?? 'Quyền nhân viên tác nghiệp hệ thống',
                                  style: TextStyle(
                                    color: Colors.tealAccent.shade100,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Thẻ Trạng Thái Ca Trực & Tác Nghiệp
                    Row(
                      children: [
                        Expanded(
                          child: _buildDutyCard(
                            title: 'Ca Trực',
                            value: 'Hoạt Động',
                            icon: Icons.check_circle_rounded,
                            color: Colors.teal.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDutyCard(
                            title: 'Công Cụ',
                            value: '3 Tiện Ích',
                            icon: Icons.handyman_rounded,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDutyCard(
                            title: 'Quyền Hạn',
                            value: 'Nhân Viên',
                            icon: Icons.badge_rounded,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // TIÊU ĐỀ: CÔNG CỤ TÁC NGHIỆP TRỰC TIẾP
                    const Text(
                      'Tiện Ích Nhân Viên',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Công cụ 1: Đo Tiếng Ồn Hiện Trường
                    _buildStaffToolCard(
                      title: '1. Đo Tiếng Ồn Hiện Trường (Noise Meter)',
                      subtitle: 'Kiểm tra mức độ ồn Decibel khu vực làm việc hoặc kiểm định môi trường, lưu dữ liệu API',
                      icon: Icons.graphic_eq_rounded,
                      color: Colors.teal.shade700,
                      tag: 'Tác Nghiệp 1',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NoiseMeterScreen()),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Công cụ 2: Định Vị & Chia Sẻ Tọa Độ GPS
                    _buildStaffToolCard(
                      title: '2. Định Vị & Chia Sẻ Tọa Độ GPS (Location)',
                      subtitle: 'Xác định tọa độ vị trí làm việc tại hiện trường, gửi vị trí công tác cho quản trị và khách hàng',
                      icon: Icons.explore_rounded,
                      color: Colors.cyan.shade800,
                      tag: 'Tác Nghiệp 2',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LocationShareScreen()),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Công cụ 3: Dịch Tài Liệu & Biển Báo Bằng Camera
                    _buildStaffToolCard(
                      title: '3. Dịch Tài Liệu / Biển Báo Bằng Camera (OCR)',
                      subtitle: 'Khung quét tài liệu tiếng Anh và khung dịch tiếng Việt tự động giúp nhân viên xử lý hồ sơ nhanh',
                      icon: Icons.camera_alt_rounded,
                      color: Colors.indigo.shade700,
                      tag: 'Tác Nghiệp 3',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CameraTranslatorScreen()),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Ghi Chú & Hướng Dẫn Tác Nghiệp
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.assignment_outlined, color: Colors.blueGrey.shade800, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Quy Trình Tác Nghiệp & Trợ Giúp',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Sử dụng tiện ích Đo tiếng ồn khi cần khảo sát môi trường và bấm "Lưu Dữ Liệu Lên API".\n'
                            '• Khi di chuyển công tác, dùng tính năng Chia sẻ vị trí để gửi tọa độ GPS chính xác.',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 12, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDutyCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStaffToolCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String tag,
    bool isHighlight = false,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: isHighlight ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isHighlight ? color.withValues(alpha: 0.6) : Colors.transparent,
          width: isHighlight ? 1.8 : 0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: color,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Mở công cụ',
                          style: TextStyle(
                            color: color,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, color: color, size: 14),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
