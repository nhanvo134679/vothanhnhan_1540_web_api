import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiResponse {
  final bool isSuccess;
  final int statusCode;
  final dynamic data;
  final String? errorMessage;

  ApiResponse({
    required this.isSuccess,
    required this.statusCode,
    this.data,
    this.errorMessage,
  });
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _authToken;

  String? get token => _authToken;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
  }

  Future<void> setToken(String? token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null && token.isNotEmpty) {
      await prefs.setString('auth_token', token);
    } else {
      await prefs.remove('auth_token');
    }
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Uri _buildUri(String endpoint, [Map<String, dynamic>? queryParams]) {
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final urlString = '$base$cleanEndpoint';
    final uri = Uri.parse(urlString);
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())));
    }
    return uri;
  }

  String _getAlternativeBaseUrl() {
    final current = ApiConfig.baseUrl.toLowerCase();
    if (current.contains('127.0.0.1') || current.contains('localhost') || current.contains('10.0.2.2')) {
      return ApiConfig.fallbackWifiUrl;
    } else {
      return ApiConfig.fallbackUsbUrl;
    }
  }

  Uri _buildAlternativeUri(String endpoint, [Map<String, dynamic>? queryParams]) {
    final altBase = _getAlternativeBaseUrl().replaceAll(RegExp(r'/+$'), '');
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final urlString = '$altBase$cleanEndpoint';
    final uri = Uri.parse(urlString);
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())));
    }
    return uri;
  }

  Future<ApiResponse> get(String endpoint, {Map<String, dynamic>? queryParams}) async {
    try {
      final uri = _buildUri(endpoint, queryParams);
      final response = await http
          .get(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 4));
      return _handleResponse(response);
    } catch (e) {
      try {
        final altUri = _buildAlternativeUri(endpoint, queryParams);
        final response = await http
            .get(altUri, headers: _buildHeaders())
            .timeout(const Duration(seconds: 4));
        ApiConfig.setBaseUrl(_getAlternativeBaseUrl());
        return _handleResponse(response);
      } catch (_) {}
      return _handleException(e);
    }
  }

  Future<ApiResponse> post(String endpoint, {dynamic body}) async {
    try {
      final uri = _buildUri(endpoint);
      final response = await http
          .post(
            uri,
            headers: _buildHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 4));
      return _handleResponse(response);
    } catch (e) {
      try {
        final altUri = _buildAlternativeUri(endpoint);
        final response = await http
            .post(
              altUri,
              headers: _buildHeaders(),
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(const Duration(seconds: 4));
        ApiConfig.setBaseUrl(_getAlternativeBaseUrl());
        return _handleResponse(response);
      } catch (_) {}
      return _handleException(e);
    }
  }

  Future<ApiResponse> put(String endpoint, {dynamic body}) async {
    try {
      final uri = _buildUri(endpoint);
      final response = await http
          .put(
            uri,
            headers: _buildHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 4));
      return _handleResponse(response);
    } catch (e) {
      try {
        final altUri = _buildAlternativeUri(endpoint);
        final response = await http
            .put(
              altUri,
              headers: _buildHeaders(),
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(const Duration(seconds: 4));
        ApiConfig.setBaseUrl(_getAlternativeBaseUrl());
        return _handleResponse(response);
      } catch (_) {}
      return _handleException(e);
    }
  }

  Future<ApiResponse> delete(String endpoint) async {
    try {
      final uri = _buildUri(endpoint);
      final response = await http
          .delete(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 4));
      return _handleResponse(response);
    } catch (e) {
      try {
        final altUri = _buildAlternativeUri(endpoint);
        final response = await http
            .delete(altUri, headers: _buildHeaders())
            .timeout(const Duration(seconds: 4));
        ApiConfig.setBaseUrl(_getAlternativeBaseUrl());
        return _handleResponse(response);
      } catch (_) {}
      return _handleException(e);
    }
  }

  ApiResponse _handleResponse(http.Response response) {
    dynamic decodedData;
    if (response.body.isNotEmpty) {
      try {
        decodedData = jsonDecode(response.body);
      } catch (_) {
        decodedData = response.body;
      }
    }

    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

    String? errorMsg;
    if (!isSuccess) {
      if (decodedData is Map<String, dynamic>) {
        errorMsg = decodedData['message'] ??
            decodedData['Message'] ??
            decodedData['title'] ??
            decodedData['error']?.toString();
      } else if (decodedData is String && decodedData.isNotEmpty) {
        errorMsg = decodedData;
      }

      if (errorMsg == null || errorMsg.isEmpty) {
        switch (response.statusCode) {
          case 400:
            errorMsg = 'Yêu cầu không hợp lệ (400).';
            break;
          case 401:
            errorMsg = 'Chưa xác thực hoặc phiên đăng nhập đã hết hạn (401).';
            break;
          case 403:
            errorMsg = 'Bạn không có quyền thực hiện thao tác này (403 - Forbidden).';
            break;
          case 404:
            errorMsg = 'Không tìm thấy dữ liệu yêu cầu (404).';
            break;
          case 429:
            errorMsg = 'Quá nhiều yêu cầu. Vui lòng thử lại sau giây lát.';
            break;
          case 500:
            errorMsg = 'Lỗi máy chủ nội bộ (500). Vui lòng thử lại sau.';
            break;
          default:
            errorMsg = 'Lỗi kết nối máy chủ (${response.statusCode}).';
        }
      }
    }

    return ApiResponse(
      isSuccess: isSuccess,
      statusCode: response.statusCode,
      data: decodedData,
      errorMessage: errorMsg,
    );
  }

  ApiResponse _handleException(dynamic e) {
    String message = 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra địa chỉ API và kết nối mạng.';
    if (e is SocketException) {
      message = 'Lỗi kết nối mạng: Không tìm thấy máy chủ tại ${ApiConfig.baseUrl}.';
    } else if (e.toString().contains('TimeoutException')) {
      message = 'Hết thời gian chờ kết nối máy chủ. Vui lòng thử lại.';
    }
    return ApiResponse(
      isSuccess: false,
      statusCode: 0,
      errorMessage: message,
    );
  }
}
