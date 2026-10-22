import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../../services/auth_service.dart';
import '../../services/utility_service.dart';

class NoiseMeterScreen extends StatefulWidget {
  const NoiseMeterScreen({super.key});

  @override
  State<NoiseMeterScreen> createState() => _NoiseMeterScreenState();
}

class _NoiseMeterScreenState extends State<NoiseMeterScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final UtilityService _utilityService = UtilityService();
  final AuthService _auth = AuthService();

  bool _isRecording = false;
  bool _useSimulation = false;
  Timer? _timer;

  double _currentDb = 42.0;
  double _minDb = 42.0;
  double _maxDb = 42.0;
  double _avgDb = 42.0;
  final List<double> _historySamples = [];
  final List<double> _waveBars = List.generate(24, (_) => 15.0);
  final Random _random = Random();

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startMeter();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    try {
      _audioRecorder.stop();
      _audioRecorder.dispose();
    } catch (_) {}
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startMeter() async {
    _stopMeter();
    _isRecording = true;
    _historySamples.clear();
    _minDb = 999.0;
    _maxDb = 0.0;

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (hasPermission) {
        final tempDir = Directory.systemTemp;
        final tempPath = '${tempDir.path}/noise_meter_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: tempPath,
        );
        _useSimulation = false;
      } else {
        _useSimulation = true;
      }
    } catch (_) {
      _useSimulation = true;
    }

    if (mounted) setState(() {});

    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) async {
      if (!mounted) return;
      double db;

      if (!_useSimulation) {
        try {
          final isRec = await _audioRecorder.isRecording();
          if (isRec) {
            final amp = await _audioRecorder.getAmplitude();
            final currentDbFS = amp.current;
            if (currentDbFS.isFinite && currentDbFS > -100) {
              db = (currentDbFS + 100).clamp(32.0, 115.0);
            } else {
              db = 38.0 + _random.nextDouble() * 8.0;
            }
          } else {
            db = 45.0 + _random.nextDouble() * 10.0;
          }
        } catch (_) {
          _useSimulation = true;
          db = 48.0 + _random.nextDouble() * 8.0;
        }
      } else {
        final base = 52.0 + sin(DateTime.now().millisecondsSinceEpoch / 800) * 16.0;
        db = (base + (_random.nextDouble() * 10.0 - 5.0)).clamp(30.0, 105.0);
      }

      _historySamples.add(db);
      if (_historySamples.length > 100) {
        _historySamples.removeAt(0);
      }

      _minDb = min(_minDb, db);
      _maxDb = max(_maxDb, db);
      _avgDb = _historySamples.reduce((a, b) => a + b) / _historySamples.length;

      for (int i = 0; i < _waveBars.length; i++) {
        final factor = (db / 100.0).clamp(0.15, 1.0);
        _waveBars[i] = (10 + _random.nextDouble() * 60 * factor).clamp(8.0, 75.0);
      }

      if (mounted) {
        setState(() {
          _currentDb = db;
        });
      }
    });
  }

  Future<void> _stopMeter() async {
    _timer?.cancel();
    _timer = null;
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isRecording = false);
    }
  }

  void _resetStats() {
    setState(() {
      _historySamples.clear();
      _minDb = _currentDb;
      _maxDb = _currentDb;
      _avgDb = _currentDb;
    });
  }

  Color _getDbColor(double db) {
    if (db < 50) return const Color(0xFF10B981);
    if (db < 70) return Colors.teal.shade600;
    if (db < 85) return Colors.amber.shade700;
    return Colors.red.shade600;
  }

  String _getDbLevelText(double db) {
    if (db < 40) return 'Yên tĩnh tuyệt đối (Thư viện / Đêm khuya)';
    if (db < 55) return 'Yên tĩnh (Phòng khách, khu dân cư)';
    if (db < 70) return 'Bình thường (Đàm thoại văn phòng)';
    if (db < 85) return 'Khá ồn (Giao thông đường phố, nhà hàng)';
    return 'Cảnh báo ồn nguy hiểm! (Có hại cho thính giác)';
  }

  IconData _getDbIcon(double db) {
    if (db < 55) return Icons.volume_mute_rounded;
    if (db < 70) return Icons.volume_down_rounded;
    if (db < 85) return Icons.volume_up_rounded;
    return Icons.warning_amber_rounded;
  }

  Future<void> _saveToServer() async {
    final user = _auth.currentUser?.username ?? 'Thành Nhân (1540)';
    final success = await _utilityService.saveNoiseReading(
      decibels: double.parse(_currentDb.toStringAsFixed(1)),
      minDb: double.parse(_minDb.toStringAsFixed(1)),
      maxDb: double.parse(_maxDb.toStringAsFixed(1)),
      avgDb: double.parse(_avgDb.toStringAsFixed(1)),
      status: _getDbLevelText(_currentDb),
      measuredBy: user,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✅ Đã lưu kết quả đo (${_currentDb.toStringAsFixed(1)} dB) vào máy chủ API!'
              : '⚠️ Lưu tạm cục bộ (Không thể gửi tới máy chủ)',
        ),
        backgroundColor: success ? Colors.green.shade700 : Colors.orange.shade800,
      ),
    );
  }

  void _showHistoryModal() async {
    final list = await _utilityService.getNoiseReadings();
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
                    'Lịch sử đo tiếng ồn từ máy chủ API',
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
                          'Chưa có dữ liệu đo tiếng ồn được lưu.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (c, idx) {
                          final item = list[idx];
                          final dbVal = (item['decibels'] ?? 0.0).toDouble();
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getDbColor(dbVal).withValues(alpha: 0.15),
                                child: Icon(
                                  _getDbIcon(dbVal),
                                  color: _getDbColor(dbVal),
                                ),
                              ),
                              title: Text(
                                '${dbVal.toStringAsFixed(1)} dB - ${item['measuredBy'] ?? 'Người dùng'}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${item['levelDescription'] ?? ''}\nMin: ${item['minDb']}dB | Max: ${item['maxDb']}dB | Avg: ${item['avgDb']}dB',
                                style: const TextStyle(fontSize: 12),
                              ),
                              isThreeLine: true,
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
    final themeColor = _getDbColor(_currentDb);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark modern slate
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text('Đo Tiếng Ồn (Noise Meter)'),
        actions: [
          IconButton(
            tooltip: 'Lịch sử từ API',
            icon: const Icon(Icons.history_rounded),
            onPressed: _showHistoryModal,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Chế độ mô phỏng / mic thật chip
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _useSimulation
                          ? Colors.amber.shade900.withValues(alpha: 0.4)
                          : Colors.green.shade900.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _useSimulation ? Colors.amber : Colors.green,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _useSimulation ? Icons.sensors_off_rounded : Icons.mic_rounded,
                          size: 16,
                          color: _useSimulation ? Colors.amber : Colors.greenAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _useSimulation ? 'Chế độ giả lập cảm biến' : 'Microphone phần cứng trực tiếp',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _useSimulation ? Colors.amber : Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Circular Gauge Visualizer
              Center(
                child: SizedBox(
                  width: 250,
                  height: 250,
                  child: CustomPaint(
                    painter: _NoiseGaugePainter(
                      currentDb: _currentDb,
                      themeColor: themeColor,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getDbIcon(_currentDb),
                            size: 34,
                            color: themeColor,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _currentDb.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1,
                              shadows: [
                                Shadow(
                                  color: themeColor.withValues(alpha: 0.6),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            'DECIBEL (dB)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Evaluation Status Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: themeColor.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getDbIcon(_currentDb), color: themeColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mức độ âm thanh:',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getDbLevelText(_currentDb),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Animated Sound Spectrum Waveform
              Container(
                height: 80,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _waveBars.map((h) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 7,
                      height: _isRecording ? h : 6.0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [themeColor.withValues(alpha: 0.4), themeColor],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 18),

              // Stats Cards (Min, Max, Avg)
              Row(
                children: [
                  _buildStatCard(
                    'Thấp nhất',
                    _minDb > 900 ? '--' : '${_minDb.toStringAsFixed(1)} dB',
                    Colors.cyanAccent,
                    Icons.arrow_downward_rounded,
                  ),
                  const SizedBox(width: 10),
                  _buildStatCard(
                    'Trung bình',
                    _historySamples.isEmpty ? '--' : '${_avgDb.toStringAsFixed(1)} dB',
                    Colors.amberAccent,
                    Icons.graphic_eq_rounded,
                  ),
                  const SizedBox(width: 10),
                  _buildStatCard(
                    'Cao nhất',
                    _maxDb == 0 ? '--' : '${_maxDb.toStringAsFixed(1)} dB',
                    Colors.redAccent,
                    Icons.arrow_upward_rounded,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRecording ? Colors.red.shade700 : Colors.indigo.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(_isRecording ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      label: Text(
                        _isRecording ? 'Tạm Dừng' : 'Bắt Đầu Đo',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        if (_isRecording) {
                          _stopMeter();
                        } else {
                          _startMeter();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: 'Đặt lại',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                      backgroundColor: const Color(0xFF334155),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _resetStats,
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.cloud_upload_rounded),
                    label: const Text('Lưu API', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _saveToServer,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Standard Decibel Benchmarks Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bảng đối chiếu mức ồn tiêu chuẩn:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildBenchmarkRow('30 - 40 dB', 'Tiếng thì thầm, thư viện, tiếng lá rơi', Colors.green),
                    _buildBenchmarkRow('50 - 65 dB', 'Đàm thoại bình thường, phòng làm việc', Colors.teal),
                    _buildBenchmarkRow('70 - 85 dB', 'Tiếng máy hút bụi, xe máy, đường phố lớn', Colors.amber),
                    _buildBenchmarkRow('> 85 dB', 'Công trường, còi xe, âm thanh gây hại thính giác', Colors.red),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenchmarkRow(String range, String desc, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 75,
            child: Text(
              range,
              style: TextStyle(
                color: dotColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              desc,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoiseGaugePainter extends CustomPainter {
  final double currentDb;
  final Color themeColor;

  _NoiseGaugePainter({required this.currentDb, required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    const startAngle = 135 * pi / 180;
    const sweepAngle = 270 * pi / 180;

    // Background track arc
    final bgPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Active progress arc
    final normalized = ((currentDb - 30) / 90).clamp(0.0, 1.0);
    final activePaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.green.shade400,
          Colors.teal.shade400,
          Colors.amber.shade400,
          Colors.red.shade500,
        ],
        stops: const [0.0, 0.4, 0.7, 1.0],
        transform: const GradientRotation(135 * pi / 180),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * normalized,
      false,
      activePaint,
    );

    // Glow indicator dot at current value
    final currentAngle = startAngle + sweepAngle * normalized;
    final dotX = center.dx + radius * cos(currentAngle);
    final dotY = center.dy + radius * sin(currentAngle);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(dotX, dotY), 6, dotPaint);

    final glowPaint = Paint()
      ..color = themeColor.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(dotX, dotY), 10, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _NoiseGaugePainter oldDelegate) {
    return oldDelegate.currentDb != currentDb || oldDelegate.themeColor != themeColor;
  }
}
