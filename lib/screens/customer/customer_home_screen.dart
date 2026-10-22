import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../utilities/camera_translator_screen.dart';
import '../utilities/location_share_screen.dart';
import '../utilities/noise_meter_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final AuthService _auth = AuthService();
  bool _isLoading = false;

  Future<void> _handleRefresh() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() => _isLoading = false);
    }
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
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản người dùng?'),
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
        title: const Text('Cổng Người Dùng (User Portal)'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _handleRefresh,
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
              onRefresh: _handleRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner Thông Tin Người Dùng
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal.shade700, Colors.cyan.shade800],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.withValues(alpha: 0.35),
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
                            foregroundColor: Colors.teal.shade800,
                            child: Text(
                              (user?.initials?.isNotEmpty == true
                                      ? user!.initials!
                                      : user?.username.substring(0, 1) ?? 'U')
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
                                        user?.username ?? 'Người Dùng',
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
                                        color: Colors.amber.shade300,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'USER',
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '● Tài khoản đang hoạt động bình thường',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Thẻ Tóm Tắt Trạng Thái Người Dùng
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            title: 'Tiện Ích AI',
                            value: '3 Tính Năng',
                            icon: Icons.auto_awesome_rounded,
                            color: Colors.purple.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoCard(
                            title: 'Trạng Thái',
                            value: 'Sẵn Sàng',
                            icon: Icons.verified_user_rounded,
                            color: Colors.teal.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoCard(
                            title: 'Kết Nối API',
                            value: 'Online',
                            icon: Icons.cloud_done_rounded,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // TIÊU ĐỀ: DANH SÁCH TIỆN ÍCH TRỰC TIẾP
                    const Text(
                      'Các Chức Năng Tiện Ích',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Tiện ích 1: Đo Tiếng Ồn
                    _buildUtilityCard(
                      title: '1. Đo Tiếng Ồn (Noise Meter dB)',
                      subtitle: 'Đo cường độ âm thanh Decibel môi trường xung quanh, hiển thị đồng hồ đo và biểu đồ sóng âm',
                      icon: Icons.graphic_eq_rounded,
                      color: Colors.teal.shade700,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NoiseMeterScreen()),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Tiện ích 2: Chia Sẻ Vị Trí
                    _buildUtilityCard(
                      title: '2. Chia Sẻ Vị Trí (Location GPS)',
                      subtitle: 'Lấy tọa độ vệ tinh GPS chính xác của bạn, tự động dịch địa chỉ và gửi nhanh qua Zalo, SMS, Google Maps',
                      icon: Icons.explore_rounded,
                      color: Colors.cyan.shade800,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LocationShareScreen()),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Tiện ích 3: Dịch Tiếng Anh Bằng Camera (2 Khung Quét & Dịch)
                    _buildUtilityCard(
                      title: '3. Dịch Tiếng Anh Bằng Camera (OCR)',
                      subtitle: 'Giao diện 2 khung: 1 khung quét tài liệu tiếng Anh qua camera & 1 khung hiện bản dịch tiếng Việt',
                      icon: Icons.camera_alt_rounded,
                      color: Colors.indigo.shade700,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CameraTranslatorScreen()),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Khung Trợ Giúp & Hướng Dẫn Sử Dụng
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
                              Icon(Icons.help_outline_rounded, color: Colors.teal.shade700, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Hướng Dẫn Nhanh Dành Cho Người Dùng',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Nhấn vào từng thẻ chức năng ở trên để mở trực tiếp tiện ích tương ứng.\n'
                            '• Bạn có thể dùng tính năng Dịch Tiếng Anh mà không cần nhập liệu thủ công.\n'
                            '• Dữ liệu đo tiếng ồn và vị trí sẽ được tự động đồng bộ lên API máy chủ an toàn.',
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

  Widget _buildInfoCard({
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

  Widget _buildUtilityCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? tag,
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
                        if (tag != null)
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
                          'Mở chức năng',
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
