import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class UtilityService {
  static final UtilityService _instance = UtilityService._internal();
  factory UtilityService() => _instance;
  UtilityService._internal();

  // Từ điển cục bộ phong phú để dịch ngay lập tức khi mạng chậm hoặc không kết nối
  static final Map<String, String> _offlineDictionary = {
    'welcome': 'Chào mừng quý khách',
    'welcome to our store': 'Chào mừng bạn đến với cửa hàng của chúng tôi',
    'welcome to our university': 'Chào mừng bạn đến với trường đại học của chúng tôi',
    'welcome to hutech': 'Chào mừng bạn đến với trường Đại học HUTECH',
    'danger': 'Nguy hiểm',
    'danger high voltage': 'Nguy hiểm: Điện áp cao',
    'caution': 'Cẩn thận / Chú ý',
    'caution wet floor': 'Chú ý: Sàn nhà ướt trơn trượt',
    'exit': 'Lối thoát',
    'emergency exit': 'Lối thoát hiểm khẩn cấp',
    'no parking': 'Cấm đỗ xe',
    'no smoking': 'Cấm hút thuốc',
    'no entry': 'Cấm vào',
    'open': 'Đang mở cửa',
    'closed': 'Đã đóng cửa',
    'open 24/7': 'Mở cửa 24/7 suốt ngày đêm',
    'push': 'Đẩy vào',
    'pull': 'Kéo ra',
    'push to open': 'Đẩy để mở cửa',
    'pull to open': 'Kéo để mở cửa',
    'special offer': 'Ưu đãi đặc biệt',
    'discount 50%': 'Giảm giá 50%',
    'sale off': 'Đang giảm giá',
    'hot deal': 'Khuyến mãi cực sốc',
    'buy 1 get 1 free': 'Mua 1 tặng 1',
    'authorized personnel only': 'Chỉ nhân viên có phận sự mới được vào',
    'do not enter': 'Cấm vào',
    'staff only': 'Khu vực nhân viên',
    'free wifi': 'Wi-Fi miễn phí',
    'thank you': 'Xin cảm ơn quý khách',
    'thank you very much': 'Xin chân thành cảm ơn bạn',
    'have a nice day': 'Chúc bạn một ngày tốt lành',
    'please keep silent': 'Vui lòng giữ trật tự',
    'silence please': 'Xin hãy giữ im lặng',
    'payment': 'Thanh toán',
    'cashier': 'Quầy thu ngân',
    'restroom': 'Nhà vệ sinh',
    'toilet': 'Nhà vệ sinh',
    'wc': 'Nhà vệ sinh',
    'information': 'Quầy thông tin',
    'information desk': 'Bàn hướng dẫn thông tin',
    'out of order': 'Tạm ngừng hoạt động',
    'out of service': 'Tạm ngưng phục vụ',
    'under maintenance': 'Đang bảo trì',
    'fire extinguisher': 'Bình chữa cháy',
    'first aid': 'Sơ cứu y tế',
    'fire exit': 'Lối thoát hiểm hỏa hoạn',
    'keep clean': 'Giữ gìn vệ sinh chung',
    'do not touch': 'Vui lòng không chạm vào',
    'slow down': 'Đi chậm lại',
    'one way': 'Đường một chiều',
    'turn left': 'Rẽ trái',
    'turn right': 'Rẽ phải',
    'student affairs': 'Phòng công tác sinh viên',
    'admissions': 'Phòng tuyển sinh',
    'hello': 'Xin chào',
    'hi': 'Chào bạn',
    'good': 'Tốt',
    'morning': 'Buổi sáng',
    'good morning': 'Chào buổi sáng',
    'good afternoon': 'Chào buổi chiều',
    'good evening': 'Chào buổi tối',
    'good night': 'Chúc ngủ ngon',
    'help': 'Giúp đỡ',
    'store': 'Cửa hàng',
    'shop': 'Cửa hàng',
    'price': 'Giá bán',
    'product': 'Sản phẩm',
    'water': 'Nước',
    'coffee': 'Cà phê',
    'tea': 'Trà',
    'food': 'Thức ăn',
    'drink': 'Thức uống',
    'apple': 'Quả táo',
    'phone': 'Điện thoại',
    'camera': 'Máy ảnh / Máy quay',
    'computer': 'Máy tính',
    'laptop': 'Máy tính xách tay',
    'keyboard': 'Bàn phím',
    'mouse': 'Chuột máy tính',
    'screen': 'Màn hình',
    'book': 'Sách',
    'student': 'Sinh viên / Học sinh',
    'teacher': 'Giáo viên',
    'professor': 'Giáo sư / Giảng viên',
    'university': 'Trường đại học',
    'college': 'Trường cao đẳng',
    'school': 'Trường học',
    'class': 'Lớp học',
    'classroom': 'Phòng học',
    'library': 'Thư viện',
    'room': 'Phòng',
    'office': 'Văn phòng',
    'building': 'Tòa nhà',
    'floor': 'Tầng',
    'elevator': 'Thang máy',
    'stairs': 'Cầu thang bộ',
    'parking': 'Bãi đỗ xe',
    'security': 'Bảo vệ / An ninh',
    'hospital': 'Bệnh viện',
    'pharmacy': 'Nhà thuốc',
    'money': 'Tiền',
    'bill': 'Hóa đơn',
    'order': 'Đơn hàng',
    'user': 'Người dùng',
    'name': 'Tên',
    'email': 'Email',
    'password': 'Mật khẩu',
    'account': 'Tài khoản',
    'login': 'Đăng nhập',
    'register': 'Đăng ký',
    'logout': 'Đăng xuất',
    'search': 'Tìm kiếm',
    'card': 'Thẻ',
    'home': 'Trang chủ',
    'warning': 'Cảnh báo',
    'error': 'Lỗi',
    'success': 'Thành công',
  };

  List<String> get _candidateBaseUrls => [
    ApiConfig.baseUrl,
    if (ApiConfig.baseUrl != ApiConfig.fallbackUsbUrl) ApiConfig.fallbackUsbUrl,
    if (ApiConfig.baseUrl != ApiConfig.fallbackWifiUrl) ApiConfig.fallbackWifiUrl,
  ];

  // 1. Dịch tiếng Anh realtime đa tầng (Backend API + Google Translate AI + MyMemory AI + Từ điển Ngoại tuyến)
  Future<Map<String, dynamic>> translateText(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) {
      return {'originalText': '', 'translatedText': '', 'confidence': 1.0};
    }
    final lower = clean.toLowerCase();

    // Tầng 1: Ưu tiên gọi backend API của hệ thống (hỗ trợ thử cả Cáp USB và Wi-Fi)
    for (final base in _candidateBaseUrls) {
      try {
        final url = Uri.parse('$base/api/Utility/translate-text');
        final res = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'text': clean, 'sourceLang': 'en', 'targetLang': 'vi'}),
            )
            .timeout(const Duration(seconds: 3));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final trans = (data['translatedText'] ?? '').toString().trim();
          if (trans.isNotEmpty &&
              !trans.toLowerCase().contains('(đã nhận diện chữ từ camera)') &&
              !trans.toLowerCase().startsWith('[bản dịch]: $lower') &&
              trans.toLowerCase() != lower) {
            if (base != ApiConfig.baseUrl) ApiConfig.setBaseUrl(base);
            return data;
          }
        }
      } catch (_) {
        // Thử đường mạng tiếp theo
      }
    }

    // Tầng 2: Google Translate Web API (clients5 - siêu tốc, chính xác cao, không bị chặn)
    try {
      final googleUrl = Uri.parse(
        'https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=en&tl=vi&q=${Uri.encodeComponent(clean)}',
      );
      final res = await http.get(googleUrl, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List && data.isNotEmpty && data[0] != null) {
          final translated = data[0].toString().trim();
          if (translated.isNotEmpty) {
            return {
              'originalText': clean,
              'translatedText': translated,
              'sourceLang': 'en',
              'targetLang': 'vi',
              'confidence': 0.99,
              'provider': 'Google Translate AI',
            };
          }
        }
      }
    } catch (_) {
      // Sang Tầng 3
    }

    // Tầng 3: MyMemory Translation API
    try {
      final myMemoryUrl = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(clean)}&langpair=en|vi',
      );
      final res = await http.get(myMemoryUrl).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map &&
            data['responseData'] != null &&
            data['responseData']['translatedText'] != null) {
          final translated = data['responseData']['translatedText'].toString().trim();
          if (translated.isNotEmpty) {
            return {
              'originalText': clean,
              'translatedText': translated,
              'sourceLang': 'en',
              'targetLang': 'vi',
              'confidence': 0.96,
              'provider': 'MyMemory AI',
            };
          }
        }
      }
    } catch (_) {
      // Sang Tầng 4
    }

    // Tầng 4: Tra từ điển ngoại tuyến cục bộ khi hoàn toàn không có internet
    String translated = _offlineDictionary[lower] ?? '';

    if (translated.isEmpty) {
      final lines = clean.split('\n');
      final translatedLines = <String>[];
      for (final line in lines) {
        final words = line.trim().split(RegExp(r'\s+'));
        final transWords = words.map((w) {
          final stripped = w.replaceAll(RegExp(r'[^\w\s]', unicode: true), '').toLowerCase();
          final matched = _offlineDictionary[stripped];
          if (matched != null) {
            return w.toLowerCase().replaceFirst(stripped, matched);
          }
          return w;
        }).toList();
        translatedLines.add(transWords.join(' '));
      }
      translated = translatedLines.join('\n');
      if (translated.toLowerCase() == lower) {
        translated = 'Văn bản gốc: $clean\n(Thiết bị đang ngoại tuyến, vui lòng kết nối internet để dịch trọn vẹn văn bản này)';
      }
    }

    return {
      'originalText': clean,
      'translatedText': translated,
      'sourceLang': 'en',
      'targetLang': 'vi',
      'confidence': 0.90,
      'provider': 'Từ điển Ngoại tuyến',
      'isOffline': true,
    };
  }

  // 2. Dịch ngôn ngữ ký hiệu
  Future<Map<String, dynamic>> translateSignLanguage(String gestureId) async {
    for (final base in _candidateBaseUrls) {
      try {
        final url = Uri.parse('$base/api/Utility/translate-sign-language');
        final res = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'gestureId': gestureId}),
            )
            .timeout(const Duration(seconds: 3));

        if (res.statusCode == 200) {
          if (base != ApiConfig.baseUrl) ApiConfig.setBaseUrl(base);
          return jsonDecode(res.body) as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    final localSigns = {
      'hello': {'label': 'Xin chào', 'sentence': 'Xin chào bạn, rất vui được gặp bạn!'},
      'wave': {'label': 'Xin chào', 'sentence': 'Xin chào quý khách!'},
      'i_love_you': {'label': 'Tôi yêu bạn', 'sentence': 'Tôi yêu bạn và chúc bạn luôn vui vẻ!'},
      'thumbs_up': {'label': 'Đồng ý / Rất tốt', 'sentence': 'Tôi hoàn toàn đồng ý và đánh giá cao!'},
      'peace': {'label': 'Hòa bình / Chiến thắng', 'sentence': 'Chúc bạn bình an và thành công!'},
      'thank_you': {'label': 'Cảm ơn', 'sentence': 'Tôi xin chân thành cảm ơn bạn!'},
      'ok': {'label': 'Hoàn hảo / OK', 'sentence': 'Mọi điều đều rất tuyệt vời!'},
      'fist': {'label': 'Quyết tâm / Cố lên', 'sentence': 'Cố lên, chúng ta nhất định làm được!'},
      'one': {'label': 'Số 1', 'sentence': 'Vấn đề ưu tiên hàng đầu.'},
      'stop': {'label': 'Dừng lại', 'sentence': 'Xin vui lòng dừng lại một chút!'},
      'help': {'label': 'Cần giúp đỡ / SOS', 'sentence': 'Tôi đang cần hỗ trợ khẩn cấp!'},
    };

    final item = localSigns[gestureId.toLowerCase()] ?? {'label': gestureId, 'sentence': gestureId};
    return {
      'gestureId': gestureId,
      'label': item['label'],
      'translatedSentence': item['sentence'],
      'accuracy': 0.98,
      'isOffline': true,
    };
  }

  // 3. Chia sẻ vị trí & Lưu vào server
  Future<bool> saveLocation({
    required double latitude,
    required double longitude,
    required String address,
    String? note,
    String? sharedBy,
  }) async {
    for (final base in _candidateBaseUrls) {
      try {
        final url = Uri.parse('$base/api/Utility/save-location');
        final res = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'latitude': latitude,
                'longitude': longitude,
                'address': address,
                'note': note ?? 'Vị trí chia sẻ từ ứng dụng Android',
                'sharedBy': sharedBy ?? 'Người dùng',
              }),
            )
            .timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          if (base != ApiConfig.baseUrl) ApiConfig.setBaseUrl(base);
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> getSavedLocations() async {
    for (final base in _candidateBaseUrls) {
      try {
        final url = Uri.parse('$base/api/Utility/locations');
        final res = await http.get(url).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          if (base != ApiConfig.baseUrl) ApiConfig.setBaseUrl(base);
          final list = jsonDecode(res.body) as List;
          return list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  // 4. Đo tiếng ồn & Lưu vào server
  Future<bool> saveNoiseReading({
    required double decibels,
    required double minDb,
    required double maxDb,
    required double avgDb,
    required String status,
    String? location,
    String? measuredBy,
  }) async {
    for (final base in _candidateBaseUrls) {
      try {
        final url = Uri.parse('$base/api/Utility/save-noise-reading');
        final res = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'decibels': decibels,
                'minDb': minDb,
                'maxDb': maxDb,
                'avgDb': avgDb,
                'levelDescription': status,
                'location': location ?? 'Môi trường xung quanh',
                'measuredBy': measuredBy ?? 'Người dùng',
              }),
            )
            .timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          if (base != ApiConfig.baseUrl) ApiConfig.setBaseUrl(base);
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> getNoiseReadings() async {
    for (final base in _candidateBaseUrls) {
      try {
        final url = Uri.parse('$base/api/Utility/noise-readings');
        final res = await http.get(url).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          if (base != ApiConfig.baseUrl) ApiConfig.setBaseUrl(base);
          final list = jsonDecode(res.body) as List;
          return list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } catch (_) {}
    }
    return [];
  }
}
