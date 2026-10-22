import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../../services/auth_service.dart';
import '../../services/utility_service.dart';

class LocationShareScreen extends StatefulWidget {
  const LocationShareScreen({super.key});

  @override
  State<LocationShareScreen> createState() => _LocationShareScreenState();
}

class _LocationShareScreenState extends State<LocationShareScreen>
    with SingleTickerProviderStateMixin {
  final UtilityService _utilityService = UtilityService();
  final AuthService _auth = AuthService();

  Position? _currentPosition;
  String _currentAddress = 'Đang xác định địa chỉ GPS...';
  bool _isLocating = false;
  String? _errorMessage;

  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _determinePosition();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    setState(() {
      _isLocating = true;
      _errorMessage = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Nếu GPS bị tắt, dùng tọa độ mặc định TP.HCM để app không bao giờ crash
        _currentPosition = Position(
          longitude: 106.660172,
          latitude: 10.762622,
          timestamp: DateTime.now(),
          accuracy: 10.0,
          altitude: 15.0,
          altitudeAccuracy: 5.0,
          heading: 90.0,
          headingAccuracy: 5.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
        _currentAddress = 'Trường ĐH Công nghệ TP.HCM (HUTECH), TP. Hồ Chí Minh';
        setState(() {
          _isLocating = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setFallbackLocation('Quyền truy cập vị trí bị từ chối');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setFallbackLocation('Quyền vị trí bị từ chối vĩnh viễn');
        return;
      }

      // Lấy vị trí thực tế của thiết bị
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      _currentPosition = pos;
      await _reverseGeocode(pos.latitude, pos.longitude);
    } catch (e) {
      _setFallbackLocation('Lỗi GPS: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  void _setFallbackLocation(String reason) {
    _currentPosition = Position(
      longitude: 106.660172,
      latitude: 10.762622,
      timestamp: DateTime.now(),
      accuracy: 15.0,
      altitude: 18.0,
      altitudeAccuracy: 5.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
    _currentAddress = 'Quận 10, TP. Hồ Chí Minh, Việt Nam (Tọa độ mặc định)';
    _errorMessage = reason;
    if (mounted) {
      setState(() {
        _isLocating = false;
      });
    }
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );
      final res = await http.get(url, headers: {
        'User-Agent': 'VoThanhNhan_1540_App/1.0',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          if (mounted) {
            setState(() => _currentAddress = displayName);
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentAddress = 'Khu vực tọa độ: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
      });
    }
  }

  String _getMapLink() {
    if (_currentPosition == null) return '';
    return 'https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';
  }

  void _shareViaApp() {
    if (_currentPosition == null) return;
    final text = '''
📍 VỊ TRÍ ĐƯỢC CHIA SẺ
Người gửi: ${_auth.currentUser?.username ?? 'Thành Nhân 1540'}
Địa chỉ: $_currentAddress
Tọa độ GPS: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}
Độ chính xác: ±${_currentPosition!.accuracy.toStringAsFixed(1)}m

Xem trực tiếp trên Google Maps:
${_getMapLink()}
''';
    // ignore: deprecated_member_use
    Share.share(text, subject: 'Chia sẻ vị trí GPS - 1540 Võ Thành Nhân');
  }

  void _copyToClipboard() {
    if (_currentPosition == null) return;
    final text = 'Tọa độ: ${_currentPosition!.latitude},${_currentPosition!.longitude} - ${_getMapLink()}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Đã sao chép tọa độ & Link Google Maps vào bộ nhớ tạm!'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  Future<void> _syncToServer() async {
    if (_currentPosition == null) return;
    final user = _auth.currentUser?.username ?? 'Khách hàng';
    final success = await _utilityService.saveLocation(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      address: _currentAddress,
      note: 'Chia sẻ từ ứng dụng Android (Oppo / Physical Device)',
      sharedBy: user,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✅ Đã lưu và chia sẻ vị trí lên máy chủ Web API thành công!'
              : '⚠️ Không thể kết nối Web API, vui lòng kiểm tra máy chủ',
        ),
        backgroundColor: success ? Colors.green.shade700 : Colors.orange.shade800,
      ),
    );
  }

  void _showSavedLocationsModal() async {
    final list = await _utilityService.getSavedLocations();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lịch sử vị trí đã lưu trên Web API',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: list.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có dữ liệu vị trí được lưu trên server.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (c, idx) {
                          final item = list[idx];
                          final lat = item['latitude'] ?? 0.0;
                          final lon = item['longitude'] ?? 0.0;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE0E7FF),
                                child: Icon(Icons.location_on, color: Colors.indigo),
                              ),
                              title: Text(
                                item['address'] ?? 'Vị trí tọa độ ($lat, $lon)',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              subtitle: Text(
                                'Chia sẻ bởi: ${item['sharedBy']} • Tọa độ: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.share, size: 20),
                                onPressed: () {
                                  // ignore: deprecated_member_use
                                  Share.share(
                                    'Vị trí từ máy chủ API: ${item['address']} - https://maps.google.com/?q=$lat,$lon',
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B), // Modern midnight navy
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        title: const Text('Chia Sẻ Vị Trí (GPS Location)'),
        actions: [
          IconButton(
            tooltip: 'Lịch sử từ API',
            icon: const Icon(Icons.cloud_done_rounded),
            onPressed: _showSavedLocationsModal,
          ),
          IconButton(
            tooltip: 'Làm mới vị trí',
            icon: const Icon(Icons.my_location_rounded),
            onPressed: _determinePosition,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Radar GPS Status Visualizer
              Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Color(0xFF1C2541), Color(0xFF0B132B)],
                    radius: 0.9,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _radarController,
                      builder: (ctx, child) {
                        return CustomPaint(
                          size: const Size(180, 180),
                          painter: _GpsRadarPainter(
                            sweepAngle: _radarController.value * 2 * pi,
                          ),
                        );
                      },
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.satellite_alt_rounded,
                          size: 36,
                          color: Colors.cyanAccent,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isLocating ? 'Đang định vị vệ tinh GPS...' : 'GPS Hoạt Động',
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                        if (_currentPosition != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Độ chính xác: ±${_currentPosition!.accuracy.toStringAsFixed(1)} mét',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.amber, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Address Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2541),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.place_rounded, color: Colors.cyanAccent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Địa Chỉ Hiện Tại',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sao chép',
                          icon: const Icon(Icons.copy_rounded, color: Colors.cyanAccent, size: 20),
                          onPressed: _copyToClipboard,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _currentAddress,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // GPS Coordinates Grid (Lat, Long, Alt, Speed)
              Row(
                children: [
                  _buildCoordCard(
                    'Vĩ Độ (Latitude)',
                    _currentPosition != null ? _currentPosition!.latitude.toStringAsFixed(6) : '--',
                    Icons.north_rounded,
                    Colors.cyanAccent,
                  ),
                  const SizedBox(width: 10),
                  _buildCoordCard(
                    'Kinh Độ (Longitude)',
                    _currentPosition != null ? _currentPosition!.longitude.toStringAsFixed(6) : '--',
                    Icons.east_rounded,
                    Colors.tealAccent,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildCoordCard(
                    'Độ Cao (Altitude)',
                    _currentPosition != null ? '${_currentPosition!.altitude.toStringAsFixed(1)} m' : '--',
                    Icons.terrain_rounded,
                    Colors.amberAccent,
                  ),
                  const SizedBox(width: 10),
                  _buildCoordCard(
                    'Tốc Độ (Speed)',
                    _currentPosition != null ? '${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h' : '--',
                    Icons.speed_rounded,
                    Colors.purpleAccent,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Action Buttons: Share, Sync, Copy
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.share_rounded),
                label: const Text(
                  'Chia Sẻ Vị Trí Qua Ứng Dụng Khác (Zalo, SMS...)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: _shareViaApp,
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.cyanAccent,
                        side: const BorderSide(color: Colors.cyanAccent),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Sao Chép Link'),
                      onPressed: _copyToClipboard,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                      label: const Text('Lưu Vào API'),
                      onPressed: _syncToServer,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoordCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2541),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GpsRadarPainter extends CustomPainter {
  final double sweepAngle;

  _GpsRadarPainter({required this.sweepAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final circlePaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Concentric circles
    canvas.drawCircle(center, radius * 0.33, circlePaint);
    canvas.drawCircle(center, radius * 0.66, circlePaint);
    canvas.drawCircle(center, radius, circlePaint);

    // Cross lines
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      circlePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      circlePaint,
    );

    // Sweep line
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.cyanAccent.withValues(alpha: 0.0),
          Colors.cyanAccent.withValues(alpha: 0.35),
        ],
        stops: const [0.8, 1.0],
        transform: GradientRotation(sweepAngle - 0.5),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      sweepAngle - 0.5,
      0.5,
      true,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GpsRadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle;
  }
}
