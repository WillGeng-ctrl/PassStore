import 'dart:convert';

import 'package:http/http.dart' as http;

class WebDavSyncService {
  const WebDavSyncService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<WebDavConnectionResult> testConnection({
    required String url,
    required String account,
    required String appPassword,
  }) async {
    final client = _client ?? http.Client();
    try {
      final response = await client.send(
        http.Request('PROPFIND', Uri.parse(url))
          ..headers.addAll(_authHeaders(account, appPassword))
          ..headers['Depth'] = '0',
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const WebDavConnectionResult.ok();
      }
      return WebDavConnectionResult.failed('连接失败：HTTP ${response.statusCode}');
    } catch (error) {
      return WebDavConnectionResult.failed('连接失败：$error');
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<String> downloadVault({
    required String url,
    required String account,
    required String appPassword,
  }) async {
    final response = await http.get(Uri.parse(url), headers: _authHeaders(account, appPassword));
    if (response.statusCode != 200) {
      throw WebDavException('下载失败：HTTP ${response.statusCode}');
    }
    return response.body;
  }

  Future<void> uploadVault({
    required String url,
    required String account,
    required String appPassword,
    required String body,
  }) async {
    final response = await http.put(
      Uri.parse(url),
      headers: {
        ..._authHeaders(account, appPassword),
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WebDavException('上传失败：HTTP ${response.statusCode}');
    }
  }

  Map<String, String> _authHeaders(String account, String appPassword) {
    final token = base64Encode(utf8.encode('$account:$appPassword'));
    return {'Authorization': 'Basic $token'};
  }
}

class WebDavConnectionResult {
  const WebDavConnectionResult._({required this.ok, required this.message});

  const WebDavConnectionResult.ok() : this._(ok: true, message: '连接成功');

  const WebDavConnectionResult.failed(String message) : this._(ok: false, message: message);

  final bool ok;
  final String message;
}

class WebDavException implements Exception {
  const WebDavException(this.message);

  final String message;

  @override
  String toString() => message;
}
