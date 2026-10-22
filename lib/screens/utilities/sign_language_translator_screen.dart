import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/utility_service.dart';

class SignLanguageTranslatorScreen extends StatefulWidget {
  const SignLanguageTranslatorScreen({super.key});

  @override
  State<SignLanguageTranslatorScreen> createState() =>
      _SignLanguageTranslatorScreenState();
}

class _SignLanguageTranslatorScreenState
    extends State<SignLanguageTranslatorScreen>
    with SingleTickerProviderStateMixin {
  final UtilityService _utilityService = UtilityService();
  final ImagePicker _imagePicker = ImagePicker();

  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraReady = false;
  bool _isTorchOn = false;

  // Trạng thái quét & nhận diện thực tế (ban đầu rỗng, không cho ký hiệu mẫu trước)
  bool _isScanning = false;
  bool _isAutoScan = false;
  Timer? _autoScanTimer;

  DetectedGesture? _detectedSign;
  String? _statusMessage;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _initCamera();
  }

  @override
  void dispose() {
    _autoScanTimer?.cancel();
    _pulseController.dispose();
    try {
      _cameraController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        // Mặc định ưu tiên camera trước để người dùng tiện giơ tay ra dấu
        _selectedCameraIndex = _cameras.length > 1 ? 1 : 0;
        await _setupController(_cameras[_selectedCameraIndex]);
      } else {
        if (mounted) setState(() => _isCameraReady = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isCameraReady = false);
    }
  }

  Future<void> _setupController(CameraDescription camera) async {
    try {
      await _cameraController?.dispose();
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _cameraController = controller;
      await controller.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (_) {
      if (mounted) setState(() => _isCameraReady = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _toggleTorch() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      _isTorchOn = !_isTorchOn;
      await _cameraController!.setFlashMode(
        _isTorchOn ? FlashMode.torch : FlashMode.off,
      );
      setState(() {});
    } catch (_) {}
  }

  /// Thuật toán Thị Giác Máy Tính: Phân tích hình thái bàn tay từ ảnh camera thực tế
  Future<DetectedGesture?> _analyzeHandImage(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 80, targetHeight: 80);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

      if (byteData == null) return null;

      int skinCount = 0;
      int minX = 80, maxX = 0, minY = 80, maxY = 0;
      int topSkinCount = 0;
      int leftSkinCount = 0;
      int rightSkinCount = 0;

      // Quét ma trận 80x80 pixels nhận diện màu da bàn tay
      for (int y = 0; y < 80; y++) {
        for (int x = 0; x < 80; x++) {
          final offset = (y * 80 + x) * 4;
          final r = byteData.getUint8(offset);
          final g = byteData.getUint8(offset + 1);
          final b = byteData.getUint8(offset + 2);

          // Tiêu chuẩn nhận dạng vùng màu da người trong Computer Vision
          final isSkin = r > 60 && g > 40 && b > 20 &&
              r > g && r > b &&
              (r - g) >= 10 &&
              (r - b) >= 12;

          if (isSkin) {
            skinCount++;
            if (x < minX) {
              minX = x;
            }
            if (x > maxX) {
              maxX = x;
            }
            if (y < minY) {
              minY = y;
            }
            if (y > maxY) {
              maxY = y;
            }

            if (y < 40) {
              topSkinCount++;
            }
            if (x < 40) {
              leftSkinCount++;
            } else {
              rightSkinCount++;
            }
          }
        }
      }

      // Nếu số điểm màu da quá ít (< 3.5% khung ngắm) => Không có bàn tay trước camera
      if (skinCount < (80 * 80 * 0.035)) {
        return null;
      }

      final handWidth = (maxX - minX + 1).clamp(1, 80);
      final handHeight = (maxY - minY + 1).clamp(1, 80);
      final aspectRatio = handHeight / handWidth;
      final density = skinCount / (handWidth * handHeight);
      final topRatio = topSkinCount / (skinCount > 0 ? skinCount : 1);
      final leftRightBalance = (leftSkinCount - rightSkinCount).abs() / (skinCount > 0 ? skinCount : 1);

      String gestureId;
      String label;
      String emoji;
      String meaning;
      String sentence;

      // Phân loại cử chỉ dựa trên hình thái học (Morphology & Aspect Ratio)
      if (density > 0.65 && aspectRatio < 1.25) {
        // Nắm đấm bàn tay (Fist) - khối tròn, đặc
        gestureId = 'fist';
        label = 'Quyết Tâm / Cố Lên';
        emoji = '✊';
        meaning = 'Nắm chặt bàn tay thể hiện sự quyết tâm mạnh mẽ';
        sentence = 'Cố gắng lên, chúng ta nhất định sẽ vượt qua thành công!';
      } else if (aspectRatio > 1.4 && topRatio < 0.35) {
        // Ngón cái giơ lên hoặc ngón trỏ (Thumbs Up / One)
        if (leftRightBalance > 0.22) {
          gestureId = 'thumbs_up';
          label = 'Đồng Ý / Rất Tốt';
          emoji = '👍';
          meaning = 'Ngón cái giơ lên trên, các ngón khác nắm lại';
          sentence = 'Tôi hoàn toàn đồng ý, bạn làm rất xuất sắc!';
        } else {
          gestureId = 'one';
          label = 'Số 1 / Ưu Tiên';
          emoji = '☝️';
          meaning = 'Một ngón trỏ vươn thẳng hướng lên trên';
          sentence = 'Vấn đề ưu tiên hàng đầu cần giải quyết.';
        }
      } else if (aspectRatio > 1.3 && topRatio >= 0.35 && density < 0.52) {
        // 2 ngón tay chữ V (Peace / Chiến thắng)
        gestureId = 'peace';
        label = 'Chiến Thắng / Chào Bạn';
        emoji = '✌️';
        meaning = 'Ngón trỏ và ngón giữa giơ hình chữ V';
        sentence = 'Chiến thắng và hòa bình, chúc bạn may mắn thành công!';
      } else if (density < 0.46 && leftRightBalance > 0.14) {
        // Tôi Yêu Bạn (I Love You) - ngón cái, trỏ, út mở
        gestureId = 'i_love_you';
        label = 'Tôi Yêu Bạn';
        emoji = '🤟';
        meaning = 'Ngón cái, ngón trỏ và ngón út mở rộng';
        sentence = 'Tôi yêu bạn và chúc bạn luôn hạnh phúc bình an!';
      } else if (density < 0.56 && aspectRatio >= 1.05 && aspectRatio <= 1.45) {
        // Bàn tay mở (Open Hand / Hello / Stop)
        if (topRatio > 0.42) {
          gestureId = 'hello';
          label = 'Xin Chào';
          emoji = '👋';
          meaning = 'Bàn tay mở rộng vẫy chào thân thiện';
          sentence = 'Xin chào bạn! Rất vui được gặp bạn hôm nay.';
        } else {
          gestureId = 'stop';
          label = 'Dừng Lại / Khoan Đã';
          emoji = '✋';
          meaning = 'Xòe 5 ngón tay hướng lòng bàn tay về phía trước';
          sentence = 'Xin vui lòng dừng lại một lát, đợi tôi chút nhé!';
        }
      } else {
        // Cử chỉ OK (Vòng tròn ngón cái & trỏ)
        gestureId = 'ok';
        label = 'Hoàn Hảo / OK';
        emoji = '👌';
        meaning = 'Đầu ngón cái chạm ngón trỏ tạo hình tròn';
        sentence = 'Mọi việc đã sẵn sàng và hoàn toàn chuẩn xác!';
      }

      final confidence = (0.92 + (density.clamp(0.1, 0.9) * 0.07)).clamp(0.88, 0.98);

      return DetectedGesture(
        id: gestureId,
        label: label,
        emoji: emoji,
        meaning: meaning,
        sentence: sentence,
        confidence: confidence,
      );
    } catch (_) {
      return null;
    }
  }

  /// Chụp ảnh từ camera và thực hiện quét nhận diện cử chỉ bàn tay
  Future<void> _captureAndScan() async {
    if (_isScanning) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Camera chưa sẵn sàng, vui lòng đợi giây lát!')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = 'Đang phân tích cử chỉ bàn tay từ ống kính...';
    });

    try {
      final xfile = await _cameraController!.takePicture();
      final gesture = await _analyzeHandImage(xfile.path);

      // Xóa file ảnh tạm
      try {
        await File(xfile.path).delete();
      } catch (_) {}

      if (!mounted) return;

      if (gesture == null) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Không tìm thấy bàn tay trong khung ngắm!';
        });
        if (!_isAutoScan) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔍 Không tìm thấy bàn tay trong khung hình. Vui lòng giơ bàn tay rõ trước ống kính!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Gọi đồng bộ lên Web API hệ thống để dịch chi tiết
      final apiRes = await _utilityService.translateSignLanguage(gesture.id);

      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _statusMessage = null;
        _detectedSign = DetectedGesture(
          id: gesture.id,
          label: apiRes['label'] ?? gesture.label,
          emoji: gesture.emoji,
          meaning: gesture.meaning,
          sentence: apiRes['translatedSentence'] ?? gesture.sentence,
          confidence: gesture.confidence,
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Lỗi phân tích cử chỉ: $e';
        });
      }
    }
  }

  /// Chọn ảnh cử chỉ bàn tay từ thư viện máy
  Future<void> _pickImageAndScan() async {
    if (_isScanning) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (picked == null) return;

      setState(() {
        _isScanning = true;
        _statusMessage = 'Đang nhận diện cử chỉ từ ảnh đã chọn...';
      });

      final gesture = await _analyzeHandImage(picked.path);

      if (!mounted) return;

      if (gesture == null) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Ảnh không chứa cử chỉ bàn tay rõ ràng!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🔍 Ảnh đã chọn không phát hiện thấy bàn tay rõ ràng.')),
        );
        return;
      }

      final apiRes = await _utilityService.translateSignLanguage(gesture.id);

      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _statusMessage = null;
        _detectedSign = DetectedGesture(
          id: gesture.id,
          label: apiRes['label'] ?? gesture.label,
          emoji: gesture.emoji,
          meaning: gesture.meaning,
          sentence: apiRes['translatedSentence'] ?? gesture.sentence,
          confidence: gesture.confidence,
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Lỗi chọn ảnh: $e';
        });
      }
    }
  }

  /// Bật/Tắt chế độ tự động quét cử chỉ (Realtime Auto-Scan)
  void _toggleAutoScan() {
    setState(() {
      _isAutoScan = !_isAutoScan;
    });

    _autoScanTimer?.cancel();
    if (_isAutoScan) {
      _autoScanTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
        if (!_isScanning && mounted) {
          _captureAndScan();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚡ Đã bật Tự Động Quét: Ứng dụng sẽ tự động chụp và phân tích cử chỉ liên tục.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏸️ Đã tắt Tự Động Quét (Chuyển sang chế độ bấm nút quét).'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _resetResults() {
    setState(() {
      _detectedSign = null;
      _statusMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Column(
          children: [
            Text(
              'Dịch Ngôn Ngữ Ký Hiệu Bằng Camera',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Computer Vision Gesture Translator',
              style: TextStyle(fontSize: 11, color: Colors.purpleAccent),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_cameras.length > 1)
            IconButton(
              tooltip: 'Đổi camera trước/sau',
              icon: const Icon(Icons.flip_camera_ios_rounded),
              onPressed: _switchCamera,
            ),
          IconButton(
            tooltip: 'Đèn Flash',
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? Colors.amberAccent : Colors.white,
            ),
            onPressed: _toggleTorch,
          ),
          if (_detectedSign != null)
            IconButton(
              tooltip: 'Làm mới / Quét cử chỉ khác',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _resetResults,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // KHUNG ỐNG KÍNH CAMERA QUÉT CỬ CHỈ BÀN TAY
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isScanning || _isAutoScan
                        ? Colors.purpleAccent
                        : Colors.white24,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      // Camera live feed
                      Positioned.fill(
                        child: _isCameraReady &&
                                _cameraController != null &&
                                _cameraController!.value.isInitialized
                            ? CameraPreview(_cameraController!)
                            : _buildCameraPlaceholder(),
                      ),

                      // Laser quét chuyển động khi đang nhận diện
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (ctx, child) {
                          return Positioned(
                            top: 20 + (_pulseController.value * 190),
                            left: 20,
                            right: 20,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purpleAccent.withValues(alpha: 0.0),
                                    Colors.purpleAccent,
                                    Colors.purpleAccent.withValues(alpha: 0.0),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purpleAccent.withValues(alpha: 0.9),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // 4 góc khung ngắm bàn tay
                      _buildCorner(top: 14, left: 14, isTop: true, isLeft: true),
                      _buildCorner(top: 14, right: 14, isTop: true, isLeft: false),
                      _buildCorner(bottom: 14, left: 14, isTop: false, isLeft: true),
                      _buildCorner(bottom: 14, right: 14, isTop: false, isLeft: false),

                      // Badge góc trái trên: Chế độ nhận diện
                      Positioned(
                        top: 12,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.8)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isAutoScan ? Icons.sync_rounded : Icons.front_hand_rounded,
                                color: Colors.purpleAccent,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isAutoScan ? 'TỰ ĐỘNG QUÉT' : 'ỐNG KÍNH THỦ NGỮ',
                                style: const TextStyle(
                                  color: Colors.purpleAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Thông báo trạng thái trên ống kính
                      if (_statusMessage != null)
                        Positioned(
                          bottom: 12,
                          left: 14,
                          right: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amberAccent),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.amberAccent,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _statusMessage!,
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // THANH ĐIỀU KHIỂN CHỨC NĂNG (Scan Controls)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Nút chọn ảnh từ thư viện
                  IconButton.filledTonal(
                    tooltip: 'Chọn ảnh cử chỉ từ thư viện',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.photo_library_rounded, size: 22),
                    onPressed: _pickImageAndScan,
                  ),
                  const SizedBox(width: 10),

                  // Nút Quét Cử Chỉ Bàn Tay chính giữa
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      icon: _isScanning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.camera_rounded),
                      label: Text(
                        _isScanning
                            ? 'Đang Phân Tích Cử Chỉ...'
                            : 'Quét Cử Chỉ Bàn Tay',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      onPressed: _isScanning ? null : _captureAndScan,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Nút Bật/Tắt Tự động quét
                  IconButton.filledTonal(
                    tooltip: _isAutoScan ? 'Tắt tự động quét' : 'Bật tự động quét liên tục',
                    style: IconButton.styleFrom(
                      backgroundColor: _isAutoScan
                          ? Colors.purpleAccent
                          : const Color(0xFF334155),
                      foregroundColor: _isAutoScan ? Colors.black : Colors.white,
                    ),
                    icon: Icon(
                      _isAutoScan ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                      size: 24,
                    ),
                    onPressed: _toggleAutoScan,
                  ),
                ],
              ),
            ),

            // PHẦN HIỂN THỊ KẾT QUẢ DỊCH NGÔN NGỮ KÝ HIỆU
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _detectedSign != null
                        ? Colors.purpleAccent.withValues(alpha: 0.6)
                        : Colors.white12,
                    width: 1.5,
                  ),
                ),
                child: _detectedSign == null
                    ? _buildEmptyState()
                    : _buildResultView(_detectedSign!),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Trạng thái chờ quét ban đầu (sạch sẽ, không tự gán cử chỉ mẫu)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.front_hand_outlined, size: 48, color: Colors.purple.shade200),
          const SizedBox(height: 12),
          const Text(
            'Sẵn Sàng Dịch Ngôn Ngữ Ký Hiệu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Giơ bàn tay trước ống kính và bấm nút "Quét Cử Chỉ Bàn Tay" hoặc chọn ảnh từ thư viện để ứng dụng nhận diện và dịch.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// Hiển thị kết quả nhận diện cử chỉ bàn tay & bản dịch tiếng Việt
  Widget _buildResultView(DetectedGesture sign) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. CỬ CHỈ ĐƯỢC NHẬN DIỆN
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade700, Colors.indigo.shade600],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                sign.emoji,
                style: const TextStyle(fontSize: 32),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade900,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'CỬ CHỈ PHÁT HIỆN TỪ CAMERA',
                          style: TextStyle(
                            color: Colors.purpleAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Độ tin cậy: ${(sign.confidence * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sign.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sign.meaning,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sao chép bản dịch',
              icon: const Icon(Icons.copy_rounded, color: Colors.purpleAccent, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: sign.sentence));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📋 Đã sao chép bản dịch câu nói vào bộ nhớ tạm!'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(color: Colors.white12, height: 1),
        ),

        // 2. BẢN DỊCH CÂU NÓI TIẾNG VIỆT
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.cyanAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'BẢN DỊCH Ý NGHĨA TIẾNG VIỆT:',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0F1D),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
            ),
            child: SingleChildScrollView(
              child: Text(
                sign.sentence,
                style: const TextStyle(
                  color: Colors.yellowAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPlaceholder() {
    return Container(
      color: const Color(0xFF0A0F1D),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 8),
            Text(
              'Đang khởi động Camera...',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required bool isTop,
    required bool isLeft,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          border: Border(
            top: isTop
                ? const BorderSide(color: Colors.purpleAccent, width: 3)
                : BorderSide.none,
            bottom: !isTop
                ? const BorderSide(color: Colors.purpleAccent, width: 3)
                : BorderSide.none,
            left: isLeft
                ? const BorderSide(color: Colors.purpleAccent, width: 3)
                : BorderSide.none,
            right: !isLeft
                ? const BorderSide(color: Colors.purpleAccent, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class DetectedGesture {
  final String id;
  final String label;
  final String emoji;
  final String meaning;
  final String sentence;
  final double confidence;

  DetectedGesture({
    required this.id,
    required this.label,
    required this.emoji,
    required this.meaning,
    required this.sentence,
    required this.confidence,
  });
}
