import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/utility_service.dart';

class CameraTranslatorScreen extends StatefulWidget {
  const CameraTranslatorScreen({super.key});

  @override
  State<CameraTranslatorScreen> createState() => _CameraTranslatorScreenState();
}

class _CameraTranslatorScreenState extends State<CameraTranslatorScreen>
    with SingleTickerProviderStateMixin {
  final UtilityService _utilityService = UtilityService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraReady = false;
  bool _isTorchOn = false;

  // Trạng thái quét & dịch thực tế (bắt đầu rỗng, không cho chữ mẫu tự động)
  bool _isScanning = false;
  bool _isTranslating = false;
  bool _isAutoScan = false;
  Timer? _autoScanTimer;

  String _scannedText = '';
  String _translatedText = '';
  String _providerName = '';
  String? _statusMessage;

  late AnimationController _laserController;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _initCamera();
  }

  @override
  void dispose() {
    _autoScanTimer?.cancel();
    _laserController.dispose();
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _selectedCameraIndex = 0;
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

  /// Lọc và ghép các dòng văn bản từ kết quả OCR của ML Kit
  String _extractCleanText(RecognizedText recognized) {
    final validLines = <String>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          validLines.add(text);
        }
      }
    }
    return validLines.join('\n');
  }

  /// Thực hiện dịch văn bản tiếng Anh sang tiếng Việt đa tầng
  Future<void> _translateRecognizedText(String englishText) async {
    final clean = englishText.trim();
    if (clean.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _isTranslating = true;
      _statusMessage = 'Đang dịch sang tiếng Việt...';
    });

    try {
      final res = await _utilityService.translateText(clean);

      if (!mounted) return;
      setState(() {
        _scannedText = clean;
        _translatedText = (res['translatedText'] ?? clean).toString().trim();
        _providerName = (res['provider'] ?? 'Dịch AI').toString();
        _isTranslating = false;
        _statusMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scannedText = clean;
        _translatedText = clean;
        _isTranslating = false;
        _statusMessage = 'Lỗi dịch: $e';
      });
    }
  }

  /// Chụp ảnh từ camera thật và nhận diện chữ bằng Google ML Kit
  Future<void> _captureAndScan() async {
    if (_isScanning || _isTranslating) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Camera chưa sẵn sàng, vui lòng đợi giây lát!')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = 'Đang quét nhận diện chữ từ camera...';
    });

    try {
      final xfile = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(xfile.path);
      final recognized = await _textRecognizer.processImage(inputImage);

      // Xóa file ảnh tạm sau khi nhận diện
      try {
        await File(xfile.path).delete();
      } catch (_) {}

      final text = _extractCleanText(recognized);

      if (text.isEmpty) {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _statusMessage = 'Không tìm thấy chữ tiếng Anh trong khung hình!';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔍 Không tìm thấy chữ tiếng Anh trong khung quét. Vui lòng căn chỉnh gần hơn hoặc bật đèn flash.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isScanning = false;
          _scannedText = text;
        });
      }

      // Tự động dịch văn bản vừa quét được
      await _translateRecognizedText(text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Lỗi quét tài liệu: $e';
        });
      }
    }
  }

  /// Quét tài liệu từ ảnh trong thư viện máy
  Future<void> _pickImageAndScan() async {
    if (_isScanning || _isTranslating) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (picked == null) return;

      setState(() {
        _isScanning = true;
        _statusMessage = 'Đang nhận diện chữ từ ảnh đã chọn...';
      });

      final inputImage = InputImage.fromFilePath(picked.path);
      final recognized = await _textRecognizer.processImage(inputImage);
      final text = _extractCleanText(recognized);

      if (text.isEmpty) {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _statusMessage = 'Ảnh không chứa văn bản tiếng Anh rõ ràng!';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🔍 Ảnh đã chọn không nhận diện được chữ tiếng Anh.')),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isScanning = false;
          _scannedText = text;
        });
      }

      await _translateRecognizedText(text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Lỗi chọn ảnh: $e';
        });
      }
    }
  }

  /// Bật/Tắt chế độ tự động quét định kỳ (Realtime auto-scan)
  void _toggleAutoScan() {
    setState(() {
      _isAutoScan = !_isAutoScan;
    });

    _autoScanTimer?.cancel();
    if (_isAutoScan) {
      _autoScanTimer = Timer.periodic(const Duration(milliseconds: 2200), (timer) {
        if (!_isScanning && !_isTranslating && mounted) {
          _captureAndScan();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚡ Đã bật Tự Động Quét: Ứng dụng sẽ tự động chụp và dịch liên tục.'),
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
      _scannedText = '';
      _translatedText = '';
      _providerName = '';
      _statusMessage = null;
    });
  }

  /// Hộp thoại cho phép người dùng tự nhập hoặc chỉnh sửa văn bản tiếng Anh để dịch ngay
  void _showManualInputDialog() {
    final textController = TextEditingController(text: _scannedText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text(
              'Nhập hoặc Sửa Văn Bản',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập từ hoặc câu tiếng Anh cần dịch sang tiếng Việt:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ví dụ: Danger, Caution wet floor, Welcome to our university...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.cyanAccent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan.shade700,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.translate_rounded, size: 18),
            label: const Text('Dịch Ngay'),
            onPressed: () {
              final text = textController.text.trim();
              Navigator.pop(ctx);
              if (text.isNotEmpty) {
                _translateRecognizedText(text);
              }
            },
          ),
        ],
      ),
    );
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
              'Dịch Tiếng Anh Bằng Camera',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Google ML Kit OCR Lens',
              style: TextStyle(fontSize: 11, color: Colors.cyanAccent),
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
          if (_scannedText.isNotEmpty)
            IconButton(
              tooltip: 'Xóa kết quả quét',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _resetResults,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // KHUNG ỐNG KÍNH CAMERA QUÉT TÀI LIỆU
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isScanning || _isAutoScan
                        ? Colors.cyanAccent
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

                      // Laser quét chuyển động khi đang quét
                      AnimatedBuilder(
                        animation: _laserController,
                        builder: (ctx, child) {
                          return Positioned(
                            top: 20 + (_laserController.value * 190),
                            left: 20,
                            right: 20,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.cyanAccent.withValues(alpha: 0.0),
                                    Colors.cyanAccent,
                                    Colors.cyanAccent.withValues(alpha: 0.0),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyanAccent.withValues(alpha: 0.9),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // 4 góc khung ngắm tài liệu
                      _buildCorner(top: 14, left: 14, isTop: true, isLeft: true),
                      _buildCorner(top: 14, right: 14, isTop: true, isLeft: false),
                      _buildCorner(bottom: 14, left: 14, isTop: false, isLeft: true),
                      _buildCorner(bottom: 14, right: 14, isTop: false, isLeft: false),

                      // Badge góc trái trên: Chế độ quét
                      Positioned(
                        top: 12,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.8)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isAutoScan ? Icons.sync_rounded : Icons.camera_alt_rounded,
                                color: Colors.cyanAccent,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isAutoScan ? 'TỰ ĐỘNG QUÉT' : 'ỐNG KÍNH CAMERA',
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
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
                    tooltip: 'Chọn ảnh tài liệu từ thư viện',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.photo_library_rounded, size: 22),
                    onPressed: _pickImageAndScan,
                  ),
                  const SizedBox(width: 10),

                  // Nút Quét & Dịch chính giữa
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      icon: (_isScanning || _isTranslating)
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.document_scanner_rounded),
                      label: Text(
                        _isScanning
                            ? 'Đang Nhận Diện Chữ...'
                            : _isTranslating
                                ? 'Đang Dịch Bằng AI...'
                                : 'Quét & Dịch Tài Liệu',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      onPressed: (_isScanning || _isTranslating)
                          ? null
                          : _captureAndScan,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Nút Bật/Tắt Tự động quét
                  IconButton.filledTonal(
                    tooltip: _isAutoScan ? 'Tắt tự động quét' : 'Bật tự động quét liên tục',
                    style: IconButton.styleFrom(
                      backgroundColor: _isAutoScan
                          ? Colors.tealAccent.shade700
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

            // PHẦN HIỂN THỊ KẾT QUẢ QUÉT & DỊCH (Translation Result Panel)
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _translatedText.isNotEmpty
                        ? Colors.tealAccent.withValues(alpha: 0.6)
                        : Colors.white12,
                    width: 1.5,
                  ),
                ),
                child: _scannedText.isEmpty && _translatedText.isEmpty
                    ? _buildEmptyState()
                    : _buildResultView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Trạng thái chờ quét ban đầu (sạch sẽ, không tự gán chữ mẫu)
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.document_scanner_outlined, size: 48, color: Colors.blueGrey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Sẵn Sàng Quét Tài Liệu Tiếng Anh',
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
                'Hướng camera vào biển hiệu hoặc văn bản tiếng Anh, sau đó bấm nút "Quét & Dịch Tài Liệu" hoặc chọn ảnh từ thư viện máy.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12, height: 1.4),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.cyanAccent,
                side: const BorderSide(color: Colors.cyanAccent),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: const Text('Nhập Hoặc Sửa Chữ Để Dịch'),
              onPressed: _showManualInputDialog,
            ),
          ],
        ),
      ),
    );
  }

  /// Hiển thị kết quả quét văn bản tiếng Anh và bản dịch tiếng Việt
  Widget _buildResultView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. VĂN BẢN TIẾNG ANH NHẬN DIỆN TỪ CAMERA
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
                  'TIẾNG ANH (TỪ ỐNG KÍNH):',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Chỉnh sửa / Nhập văn bản',
                  icon: const Icon(Icons.edit_note_rounded, color: Colors.cyanAccent),
                  onPressed: _showManualInputDialog,
                ),
                const SizedBox(width: 10),
                IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Sao chép văn bản tiếng Anh',
                  icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _scannedText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📋 Đã sao chép văn bản tiếng Anh!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxHeight: 70),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: SingleChildScrollView(
            child: Text(
              _scannedText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(color: Colors.white12, height: 1),
        ),

        // 2. BẢN DỊCH TIẾNG VIỆT
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.tealAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'BẢN DỊCH TIẾNG VIỆT:',
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                if (_providerName.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.6), width: 0.8),
                    ),
                    child: Text(
                      _providerName,
                      style: const TextStyle(color: Colors.tealAccent, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            IconButton(
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Sao chép bản dịch tiếng Việt',
              icon: const Icon(Icons.copy_rounded, color: Colors.tealAccent),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _translatedText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📋 Đã sao chép bản dịch tiếng Việt!'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0F1D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
            ),
            child: SingleChildScrollView(
              child: _isTranslating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.tealAccent,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Đang dịch câu văn sang tiếng Việt...',
                          style: TextStyle(color: Colors.tealAccent, fontSize: 13),
                        ),
                      ],
                    )
                  : Text(
                      _translatedText,
                      style: const TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 14,
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
                ? const BorderSide(color: Colors.cyanAccent, width: 3)
                : BorderSide.none,
            bottom: !isTop
                ? const BorderSide(color: Colors.cyanAccent, width: 3)
                : BorderSide.none,
            left: isLeft
                ? const BorderSide(color: Colors.cyanAccent, width: 3)
                : BorderSide.none,
            right: !isLeft
                ? const BorderSide(color: Colors.cyanAccent, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
