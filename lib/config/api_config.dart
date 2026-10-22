import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _prefBaseUrlKey = 'custom_api_base_url';

  /// Địa chỉ Wi-Fi/LAN của máy chủ (luôn dùng được cho điện thoại thật)
  static const String fallbackWifiUrl = 'http://192.168.1.6:5104';

  /// Địa chỉ Cáp USB / Localhost qua ADB reverse
  static const String fallbackUsbUrl = 'http://127.0.0.1:5104';

  /// Chuẩn hóa địa chỉ URL, tự động thêm http://, sửa lỗi gõ nhầm locallhost hoặc dấu cách
  static String normalizeUrl(String input) {
    String clean = input.trim();
    if (clean.isEmpty) return getDefaultBaseUrl();
    // Tự động sửa lỗi chính tả phổ biến "locallhost" -> "localhost"
    clean = clean.replaceAll('locallhost', 'localhost');
    // Tự động đổi dấu cách thành dấu : (ví dụ: "localhost 5104" -> "localhost:5104")
    clean = clean.replaceAll(RegExp(r'\s+'), ':');
    // Tự động thêm tiền tố http:// nếu người dùng quên nhập
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'http://$clean';
    }
    // Xóa dấu / ở cuối URL
    clean = clean.replaceAll(RegExp(r'/+$'), '');
    return clean;
  }

  static String getDefaultBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:5104';
    }
    // Mặc định cho thiết bị di động thật: Ưu tiên địa chỉ IP Wi-Fi máy tính để đăng nhập thành công ngay lập tức
    return fallbackWifiUrl;
  }

  static String _currentBaseUrl = getDefaultBaseUrl();

  static String get baseUrl => _currentBaseUrl;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefBaseUrlKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _currentBaseUrl = normalizeUrl(saved);
      } else {
        _currentBaseUrl = getDefaultBaseUrl();
      }
    } catch (_) {
      _currentBaseUrl = getDefaultBaseUrl();
    }
  }

  static Future<void> setBaseUrl(String url) async {
    _currentBaseUrl = normalizeUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefBaseUrlKey, _currentBaseUrl);
  }

  static Future<void> resetToDefault() async {
    _currentBaseUrl = getDefaultBaseUrl();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefBaseUrlKey);
  }
}
