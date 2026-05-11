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
}
