import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:passstore/data/webdav_sync_service.dart';

void main() {
  test(
    'normalizes WebDAV URL and credentials before testing connection',
    () async {
      late http.Request captured;
      final service = WebDavSyncService(
        client: MockClient((request) async {
          captured = request;
          return http.Response('', 207);
        }),
      );

      final result = await service.testConnection(
        url: ' dav.jianguoyun.com/dav ',
        account: ' user@example.com ',
        appPassword: ' app-password ',
      );

      expect(result.ok, isTrue);
      expect(captured.method, 'PROPFIND');
      expect(captured.url.toString(), 'https://dav.jianguoyun.com/dav/');
      expect(
        captured.headers['Authorization'],
        'Basic ${base64Encode(utf8.encode('user@example.com:app-password'))}',
      );
    },
  );

  test(
    'explains Jianguoyun credential requirements when server returns 401',
    () async {
      final service = WebDavSyncService(
        client: MockClient((_) async => http.Response('', 401)),
      );

      final result = await service.testConnection(
        url: 'https://dav.jianguoyun.com/dav/',
        account: 'user@example.com',
        appPassword: 'wrong',
      );

      expect(result.ok, isFalse);
      expect(result.message, contains('401'));
      expect(result.message, contains('第三方应用密码'));
      expect(result.message, contains('注册邮箱'));
    },
  );

  test(
    'downloads the fixed PassStore vault file from the configured WebDAV directory',
    () async {
      late http.Request captured;
      final service = WebDavSyncService(
        client: MockClient((request) async {
          captured = request;
          return http.Response('{"version":1}', 200, headers: {'etag': 'abc'});
        }),
      );

      final file = await service.downloadVaultFile(
        url: 'https://dav.jianguoyun.com/dav/',
        account: 'user@example.com',
        appPassword: 'app-password',
      );

      expect(file?.body, '{"version":1}');
      expect(file?.etag, 'abc');
      expect(captured.method, 'GET');
      expect(
        captured.url.toString(),
        'https://dav.jianguoyun.com/dav/PassStore/passstore.vault',
      );
    },
  );

  test('returns null when the remote vault file does not exist', () async {
    final service = WebDavSyncService(
      client: MockClient((_) async => http.Response('', 404)),
    );

    final file = await service.downloadVaultFile(
      url: 'https://dav.jianguoyun.com/dav/',
      account: 'user@example.com',
      appPassword: 'app-password',
    );

    expect(file, isNull);
  });

  test('returns null when WebDAV reports a missing parent directory', () async {
    final service = WebDavSyncService(
      client: MockClient((_) async => http.Response('', 409)),
    );

    final file = await service.downloadVaultFile(
      url: 'https://dav.jianguoyun.com/dav/',
      account: 'user@example.com',
      appPassword: 'app-password',
    );

    expect(file, isNull);
  });

  test(
    'creates the PassStore directory before uploading the vault file',
    () async {
      final methods = <String>[];
      final urls = <String>[];
      final service = WebDavSyncService(
        client: MockClient((request) async {
          methods.add(request.method);
          urls.add(request.url.toString());
          if (request.method == 'MKCOL') return http.Response('', 201);
          return http.Response('', 201);
        }),
      );

      await service.uploadVault(
        url: 'https://dav.jianguoyun.com/dav/',
        account: 'user@example.com',
        appPassword: 'app-password',
        body: '{"version":1}',
      );

      expect(methods, ['MKCOL', 'PUT']);
      expect(urls[0], 'https://dav.jianguoyun.com/dav/PassStore/');
      expect(
        urls[1],
        'https://dav.jianguoyun.com/dav/PassStore/passstore.vault',
      );
    },
  );

  test(
    'continues upload when the WebDAV directory already exists as a conflict',
    () async {
      final methods = <String>[];
      final service = WebDavSyncService(
        client: MockClient((request) async {
          methods.add(request.method);
          if (request.method == 'MKCOL') return http.Response('', 409);
          return http.Response('', 201);
        }),
      );

      await service.uploadVault(
        url: 'https://dav.jianguoyun.com/dav/',
        account: 'user@example.com',
        appPassword: 'app-password',
        body: '{"version":1}',
      );

      expect(methods, ['MKCOL', 'PUT']);
    },
  );
}
