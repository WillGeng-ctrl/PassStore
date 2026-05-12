import 'dart:convert';

import 'package:http/http.dart' as http;

abstract class VaultRemoteStore {
  Future<RemoteVaultFile?> downloadVaultFile({
    required String url,
    required String account,
    required String appPassword,
  });

  Future<void> uploadVault({
    required String url,
    required String account,
    required String appPassword,
    required String body,
    String? expectedEtag,
    bool onlyIfMissing = false,
  });
}

class WebDavSyncService implements VaultRemoteStore {
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
        http.Request('PROPFIND', _collectionUri(url))
          ..headers.addAll(_authHeaders(account, appPassword))
          ..headers['Depth'] = '0',
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const WebDavConnectionResult.ok();
      }
      if (response.statusCode == 401) {
        return const WebDavConnectionResult.failed(
          '连接失败：HTTP 401。坚果云 WebDAV 登录名需要填写注册邮箱，密码需要填写第三方应用密码。请确认没有复制到首尾空格。',
        );
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
    final file = await downloadVaultFile(
      url: url,
      account: account,
      appPassword: appPassword,
    );
    if (file == null) throw const WebDavException('远程密码库不存在');
    return file.body;
  }

  @override
  Future<RemoteVaultFile?> downloadVaultFile({
    required String url,
    required String account,
    required String appPassword,
  }) async {
    final client = _client ?? http.Client();
    try {
      final response = await client.get(
        _vaultUri(url),
        headers: _authHeaders(account, appPassword),
      );
      if (response.statusCode == 404 || response.statusCode == 409) {
        return null;
      }
      if (response.statusCode != 200) {
        throw WebDavException('下载失败：HTTP ${response.statusCode}');
      }
      return RemoteVaultFile(
        body: response.body,
        etag: response.headers['etag'],
        lastModified: response.headers['last-modified'],
      );
    } finally {
      if (_client == null) client.close();
    }
  }

  @override
  Future<void> uploadVault({
    required String url,
    required String account,
    required String appPassword,
    required String body,
    String? expectedEtag,
    bool onlyIfMissing = false,
  }) async {
    final client = _client ?? http.Client();
    try {
      await _ensureVaultDirectory(
        client: client,
        url: url,
        account: account,
        appPassword: appPassword,
      );
      final headers = {
        ..._authHeaders(account, appPassword),
        'Content-Type': 'application/json; charset=utf-8',
        if (expectedEtag != null && expectedEtag.isNotEmpty)
          'If-Match': expectedEtag,
        if (onlyIfMissing) 'If-None-Match': '*',
      };
      final response = await client.put(
        _vaultUri(url),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 412) {
        throw const WebDavException('远端密码库已变化，请重新同步');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WebDavException('上传失败：HTTP ${response.statusCode}');
      }
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<void> _ensureVaultDirectory({
    required http.Client client,
    required String url,
    required String account,
    required String appPassword,
  }) async {
    final response = await client.send(
      http.Request('MKCOL', _vaultDirectoryUri(url))
        ..headers.addAll(_authHeaders(account, appPassword)),
    );
    if (response.statusCode == 201 ||
        response.statusCode == 200 ||
        response.statusCode == 405 ||
        response.statusCode == 409) {
      return;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WebDavException('创建远程目录失败：HTTP ${response.statusCode}');
    }
  }

  Map<String, String> _authHeaders(String account, String appPassword) {
    final token = base64Encode(
      utf8.encode('${account.trim()}:${appPassword.trim()}'),
    );
    return {'Authorization': 'Basic $token'};
  }

  Uri _collectionUri(String rawUrl) {
    final uri = _uri(rawUrl);
    final path = uri.path.isEmpty || uri.path == '/'
        ? '/dav/'
        : uri.path.endsWith('/')
        ? uri.path
        : '${uri.path}/';
    return uri.replace(path: path);
  }

  Uri _vaultDirectoryUri(String rawUrl) {
    final collection = _collectionUri(rawUrl);
    return collection.replace(path: '${collection.path}PassStore/');
  }

  Uri _vaultUri(String rawUrl) {
    final directory = _vaultDirectoryUri(rawUrl);
    return directory.replace(path: '${directory.path}passstore.vault');
  }

  Uri _uri(String rawUrl) {
    final value = rawUrl.trim();
    final normalized = value.contains('://') ? value : 'https://$value';
    return Uri.parse(normalized);
  }
}

class RemoteVaultFile {
  const RemoteVaultFile({required this.body, this.etag, this.lastModified});

  final String body;
  final String? etag;
  final String? lastModified;
}

class WebDavConnectionResult {
  const WebDavConnectionResult._({required this.ok, required this.message});

  const WebDavConnectionResult.ok() : this._(ok: true, message: '连接成功');

  const WebDavConnectionResult.failed(String message)
    : this._(ok: false, message: message);

  final bool ok;
  final String message;
}

class WebDavException implements Exception {
  const WebDavException(this.message);

  final String message;

  @override
  String toString() => message;
}
