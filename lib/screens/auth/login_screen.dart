import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../services/auth_service.dart';
import '../admin/admin_dashboard_screen.dart';
import 'otp_verification_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await AuthService().login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      final cleanU = (result.username ?? _usernameController.text).trim().toLowerCase();

      // 1. TÀI KHOẢN ADMIN: KHÔNG CẦN NHẬP MÃ OTP -> CHUYỂN THẲNG ADMIN DASHBOARD
      if (!result.requiresOtp || cleanU == 'admin') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? '✅ Đăng nhập Quản trị viên (Admin) thành công (Không cần OTP)!'),
            backgroundColor: Colors.green.shade700,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
          (route) => false,
        );
        return;
      }

      // 2. CÁC TÀI KHOẢN KHÁC (STAFF, USER/CUSTOMER): BẮT BUỘC NHẬP OTP GỬI VỀ GMAIL
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Mật khẩu chính xác. Mã OTP đã được gửi về Gmail của bạn!'),
          backgroundColor: Colors.indigo.shade700,
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            username: result.username ?? _usernameController.text.trim(),
            emailMasked: result.emailMasked,
            otpDev: result.otpDev,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Đăng nhập thất bại.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: ApiConfig.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.dns, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Cấu hình Server API'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Địa chỉ máy chủ Web API:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'http://192.168.1.6:5104',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.wifi, size: 16, color: Colors.green),
                    label: const Text('Wi-Fi (192.168.1.6:5104)'),
                    onPressed: () => controller.text = 'http://192.168.1.6:5104',
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.usb, size: 16, color: Colors.blue),
                    label: const Text('Cáp USB (127.0.0.1:5104)'),
                    onPressed: () => controller.text = 'http://127.0.0.1:5104',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Hướng dẫn kết nối:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Wi-Fi (Khuyên dùng): Điện thoại và máy tính kết nối cùng mạng Wi-Fi.\n'
                      '• Cáp USB: Đã tích hợp tự động dự phòng sang Wi-Fi để luôn đăng nhập thành công. Để dùng trực tiếp cổng USB, hãy chạy file "chay_ket_noi_usb.bat" trên máy tính.',
                      style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.35),
                    ),
                  ],
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
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await ApiConfig.setBaseUrl(controller.text.trim());
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã cập nhật Server API: ${ApiConfig.baseUrl}')),
                );
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('1540 - Võ Thành Nhân'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Cấu hình Server API',
            icon: const Icon(Icons.settings),
            onPressed: _showServerConfigDialog,
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Header Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.indigo.shade600, Colors.blue.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_person_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Đăng Nhập Hệ Thống',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Xác thực 2 bước (Mật khẩu & OTP)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 32),

                  // Username field
                  TextFormField(
                    controller: _usernameController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Tên đăng nhập',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập tên đăng nhập';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Vui lòng nhập mật khẩu';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Demo accounts card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.indigo.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.touch_app_outlined, size: 16, color: Colors.indigo.shade800),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Tài khoản mẫu (Chạm để điền nhanh):',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.shield_outlined, size: 16, color: Colors.red),
                              label: const Text('Admin', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                setState(() {
                                  _usernameController.text = 'admin';
                                  _passwordController.text = 'Admin@123';
                                });
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.badge_outlined, size: 16, color: Colors.teal),
                              label: const Text('Nhân viên (Staff)', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                setState(() {
                                  _usernameController.text = 'staff';
                                  _passwordController.text = 'Staff@123';
                                });
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.person_outline, size: 16, color: Colors.purple),
                              label: const Text('Khách hàng (User)', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                setState(() {
                                  _usernameController.text = 'customer';
                                  _passwordController.text = 'User@123';
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Thông báo chính sách đăng nhập & OTP
                  Container(
                    margin: const EdgeInsets.only(top: 14, bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _usernameController.text.trim().toLowerCase() == 'admin'
                          ? Colors.green.shade50
                          : Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _usernameController.text.trim().toLowerCase() == 'admin'
                            ? Colors.green.shade300
                            : Colors.indigo.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _usernameController.text.trim().toLowerCase() == 'admin'
                              ? Icons.admin_panel_settings_rounded
                              : Icons.mark_email_read_rounded,
                          size: 18,
                          color: _usernameController.text.trim().toLowerCase() == 'admin'
                              ? Colors.green.shade800
                              : Colors.indigo.shade800,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _usernameController.text.trim().toLowerCase() == 'admin'
                                ? 'Tài khoản Admin: Vào thẳng hệ thống không cần nhập OTP'
                                : 'Tài khoản Staff / User: Bắt buộc nhận mã OTP qua Gmail đã đăng ký',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _usernameController.text.trim().toLowerCase() == 'admin'
                                  ? Colors.green.shade900
                                  : Colors.indigo.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Submit button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: _usernameController.text.trim().toLowerCase() == 'admin'
                          ? Colors.green.shade700
                          : Colors.indigo.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _usernameController.text.trim().toLowerCase() == 'admin'
                                    ? Icons.login_rounded
                                    : Icons.forward_to_inbox_rounded,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _usernameController.text.trim().toLowerCase() == 'admin'
                                    ? 'Đăng Nhập Admin (Không Cần OTP)'
                                    : 'Đăng Nhập & Nhận OTP Qua Gmail',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 20),

                  // Register link
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Chưa có tài khoản?',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Đăng ký ngay',
                          style: TextStyle(
                            color: Colors.indigo.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  // Current API Host indicator
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_done_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'API: ${ApiConfig.baseUrl}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
