import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../admin/admin_dashboard_screen.dart';
import '../customer/customer_home_screen.dart';
import '../staff/staff_dashboard_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String username;
  final String? emailMasked;
  final String? otpDev;

  const OtpVerificationScreen({
    super.key,
    required this.username,
    this.emailMasked,
    this.otpDev,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _currentDevOtp;

  int _resendCountdown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentDevOtp = widget.otpDev;
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendCountdown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đúng 6 chữ số mã OTP'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService().verifyLoginOtp(
      username: widget.username,
      otpCode: otp,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final user = result['user'] as UserModel?;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Xác thực OTP thành công!'),
          backgroundColor: Colors.green,
        ),
      );

      // Điều hướng theo Role
      Widget destination;
      if (user != null && user.isAdmin) {
        destination = const AdminDashboardScreen();
      } else if (user != null && user.isStaff) {
        destination = const StaffDashboardScreen();
      } else {
        destination = const CustomerHomeScreen();
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => destination),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Mã OTP không hợp lệ hoặc đã hết hạn.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() => _isResending = true);

    final result = await AuthService().resendOtp(widget.username);

    if (!mounted) return;
    setState(() => _isResending = false);

    if (result['success'] == true) {
      if (result['otpDev'] != null) {
        setState(() => _currentDevOtp = result['otpDev'].toString());
      }
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Đã gửi lại mã OTP mới qua email!'),
          backgroundColor: Colors.blue,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Không thể gửi lại mã OTP.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final emailDisplay = widget.emailMasked ?? 'email của bạn';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác thực OTP'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon Header
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    size: 40,
                    color: Colors.indigo.shade700,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Xác Thực Mã OTP Qua Gmail',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade900,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Hệ thống đã gửi mã OTP 6 chữ số đến hộp thư Gmail đã đăng ký:',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mark_email_read_rounded, size: 18, color: Colors.indigo.shade700),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          emailDisplay,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade900,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final mailtoUri = Uri.parse('mailto:$emailDisplay');
                      final webGmailUri = Uri.parse('https://mail.google.com');
                      try {
                        if (await canLaunchUrl(mailtoUri)) {
                          await launchUrl(mailtoUri);
                        } else {
                          await launchUrl(webGmailUri, mode: LaunchMode.externalApplication);
                        }
                      } catch (_) {
                        await launchUrl(webGmailUri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Mở Hộp Thư Gmail Để Lấy Mã'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo.shade700,
                      side: BorderSide(color: Colors.indigo.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Dev OTP helper banner (Rất hữu ích khi chấm bài test)
                if (_currentDevOtp != null && _currentDevOtp!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.terminal, size: 18, color: Colors.amber.shade900),
                            const SizedBox(width: 6),
                            Text(
                              'Mã OTP (Môi trường Dev): $_currentDevOtp',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _otpController.text = _currentDevOtp!;
                            });
                          },
                          icon: const Icon(Icons.paste, size: 16),
                          label: const Text('Điền nhanh mã OTP Dev'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amber.shade900,
                            side: BorderSide(color: Colors.amber.shade400),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // OTP Input Field
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 10,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••••',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 24),

                // Verify Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerifyOtp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.indigo.shade600,
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
                      : const Text(
                          'Xác Nhận & Đăng Nhập',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 20),

                // Resend OTP button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Không nhận được mã?',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    TextButton(
                      onPressed: (_resendCountdown > 0 || _isResending)
                          ? null
                          : _handleResendOtp,
                      child: Text(
                        _resendCountdown > 0
                            ? 'Gửi lại sau (${_resendCountdown}s)'
                            : (_isResending ? 'Đang gửi...' : 'Gửi lại mã'),
                        style: TextStyle(
                          color: _resendCountdown > 0 ? Colors.grey : Colors.indigo.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
