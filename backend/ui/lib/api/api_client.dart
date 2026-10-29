/// HTTP client for the Task-tracker FastAPI backend.
///
/// Single place that knows: base URL, auth token storage (SharedPreferences),
/// JSON decoding and error-message extraction.  All screens go through this
/// client — no screen talks to `http` directly.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  /// Backend base URL.  Android emulator reaches the host machine via
  /// 10.0.2.2; a physical Android device must be pointed at the PC's LAN IP
  /// with --dart-define=API_BASE_URL=http://192.168.x.x:8000/api/v1.
  /// Desktop / web use 127.0.0.1 (not "localhost": on Windows browsers may
  /// resolve it to IPv6 ::1 first while uvicorn listens on IPv4 only, which
  /// makes requests hang and fail with "ClientException: Failed to fetch").
  /// Resolved at runtime (not `const`): `kIsWeb` and `defaultTargetPlatform`
  /// are compile-time *values*, not constant expressions in Dart, so a
  /// `const` ternary on them fails compilation ("Not a constant expression").
  static String get _defaultBaseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000/api/v1';
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator reaches the host PC through this alias.
      return 'http://10.0.2.2:8000/api/v1';
    }
    // Windows / macOS / Linux desktop and iOS run next to the backend.
    return 'http://127.0.0.1:8000/api/v1';
  }

  static final String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
  ).isNotEmpty
      ? const String.fromEnvironment('API_BASE_URL')
      : _defaultBaseUrl;

  String? _accessToken;
  String? _refreshToken;

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  Future<void> _saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Uri _u(String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{};
    if (query != null) {
      for (final e in query.entries) {
        if (e.value != null) q[e.key] = '${e.value}';
      }
    }
    return Uri.parse('$baseUrl$path')
        .replace(queryParameters: q.isEmpty ? null : q);
  }

  /// Parses an error body into a readable single-line message.
  static String _extractError(http.Response res) {
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final detail = body is Map ? body['detail'] : null;
      if (detail is String) return detail;
      if (detail is List) {
        return detail
            .map((e) {
              final loc = (e['loc'] as List?)?.skip(1).join('.') ?? '';
              return '$loc: ${e['msg']}';
            })
            .join('; ');
      }
      return 'Ошибка ${res.statusCode}';
    } catch (_) {
      return 'Ошибка сервера (${res.statusCode})';
    }
  }

  Future<dynamic> _handle(http.Response res) async {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw ApiException(res.statusCode, _extractError(res));
  }

  /// Sends a request; on 401 silently refreshes the access token once
  /// (using the stored refresh token) and replays the original request.
  Future<dynamic> _request(String method, Uri url,
      [String? body]) async {
    Future<http.Response> send() async {
      final req = http.Request(method, url)
        ..headers.addAll(_headers);
      if (body != null) req.body = body;
      return http.Response.fromStream(await req.send());
    }

    var res = await send();
    if (res.statusCode == 401 && _refreshToken != null) {
      if (await _tryRefresh()) res = await send();
    }
    return _handle(res);
  }

  Future<bool> _tryRefresh() async {
    try {
      final res = await http.post(_u('/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': _refreshToken}));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        await _saveTokens(data['access_token'],
            data['refresh_token'] ?? _refreshToken!);
        return true;
      }
    } catch (_) {
      // ignore – caller will surface the original 401
    }
    return false;
  }

  // ------------------------------------------------------------- auth
  Future<void> register({
    required String username,
    required String email,
    required String fullName,
    required String password,
  }) async {
    final res = await http.post(
      _u('/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'full_name': fullName,
        'password': password,
        'role': 'worker',
        'is_active': true,
      }),
    );
    await _handle(res);
  }

  Future<void> login(String username, String password) async {
    final res = await http.post(
      _u('/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = await _handle(res) as Map<String, dynamic>;
    await _saveTokens(data['access_token'], data['refresh_token']);
  }

  Future<Map<String, dynamic>> me() async =>
      (await _request('GET', _u('/auth/me'))) as Map<String, dynamic>;

  // ------------------------------------------------------------- generic CRUD
  Future<dynamic> get(String path, [Map<String, dynamic>? query]) async =>
      _request('GET', _u(path, query));

  Future<dynamic> post(String path, Map<String, dynamic> body) async =>
      _request('POST', _u(path), jsonEncode(body));

  Future<dynamic> put(String path, Map<String, dynamic> body) async =>
      _request('PUT', _u(path), jsonEncode(body));

  Future<dynamic> patch(String path, Map<String, dynamic> body) async =>
      _request('PATCH', _u(path), jsonEncode(body));

  Future<dynamic> delete(String path) async => _request('DELETE', _u(path));
}
