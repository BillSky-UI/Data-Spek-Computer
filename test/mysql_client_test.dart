import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:spek_komputer/database/mysql_client.dart';

void main() {
  group('CloudApi — kontrak REST backend/api.php', () {
    test('ping mengirim op & header X-Api-Key', () async {
      Uri? seenUri;
      final api = CloudApi(
        baseUrl: 'https://cloud.example.com/backend',
        apiKey: 'rahasia123',
        client: MockClient((req) async {
          seenUri = req.url;
          expect(req.method, 'POST');
          expect(req.headers['X-Api-Key'], 'rahasia123');
          expect(req.headers['Content-Type'], 'application/json');
          return _json({'ok': true, 'app': 'spek-komputer-api'});
        }),
      );
      await api.ping();
      expect(seenUri!.path, '/backend/api.php');
      expect(seenUri!.queryParameters['op'], 'ping');
    });

    test('rev membaca nilai rev', () async {
      final api = CloudApi(
        baseUrl: 'http://localhost:8080/backend',
        client: MockClient((req) async {
          expect(req.url.queryParameters['op'], 'rev');
          return _json({'ok': true, 'rev': 42, 'counts': {'devices': 3}});
        }),
      );
      final data = await api.rev();
      expect(data['rev'], 42);
    });

    test('select membangun body where/columns/order/limit', () async {
      Map<String, dynamic>? body;
      final api = CloudApi(
        baseUrl: 'http://localhost:8080/backend/',
        client: MockClient((req) async {
          body = jsonDecode(req.body) as Map<String, dynamic>;
          return _json({'ok': true, 'rows': [
            {'id': 1, 'device_name': 'PC'},
          ]});
        }),
      );
      final rows = await api.select(
        'devices',
        columns: ['id', 'device_name'],
        where: [CloudApi.eq('bagian', 'Keuangan'), CloudApi.inList('id', [1, 2])],
        orderBy: 'id',
        orderDir: 'desc',
        limit: 10,
      );
      expect(body!['op'], 'select');
      expect(body!['table'], 'devices');
      expect(body!['columns'], ['id', 'device_name']);
      expect(body!['where'], [
        {'col': 'bagian', 'op': '=', 'value': 'Keuangan'},
        {'col': 'id', 'op': 'IN', 'values': [1, 2]},
      ]);
      expect(body!['order'], {'by': 'id', 'dir': 'desc'});
      expect(body!['limit'], 10);
      expect(rows, [
        {'id': 1, 'device_name': 'PC'},
      ]);
    });

    test('insert returning menghasilkan rows', () async {
      final api = CloudApi(
        baseUrl: 'http://localhost:8080/backend',
        client: MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['op'], 'insert');
          expect(body['returning'], true);
          return _json({
            'ok': true,
            'count': 1,
            'rows': [{'id': 7, 'device_name': 'LAPTOP'}],
          });
        }),
      );
      final rows = await api.insert(
        'devices',
        [
          {'device_name': 'LAPTOP'},
        ],
        returning: true,
      );
      expect(rows.first['id'], 7);
    });

    test('update & delete mengembalikan affected', () async {
      final api = CloudApi(
        baseUrl: 'http://localhost:8080/backend',
        client: MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['set'] ?? body['where'] ?? body['op'], isNotEmpty);
          final op = body['op'];
          return _json({'ok': true, 'affected': op == 'update' ? 2 : 1});
        }),
      );
      final u = await api.update(
        'devices',
        {'device_name': 'X'},
        [CloudApi.eq('id', 1)],
      );
      final d = await api.delete('bagian', [CloudApi.eq('id', 9)]);
      expect(u, 2);
      expect(d, 1);
    });

    test('upsert mengirim on_conflict', () async {
      Map<String, dynamic>? body;
      final api = CloudApi(
        baseUrl: 'http://localhost:8080/backend',
        client: MockClient((req) async {
          body = jsonDecode(req.body) as Map<String, dynamic>;
          return _json({'ok': true, 'inserted': 0, 'updated': 1});
        }),
      );
      await api.upsert(
        'bagian',
        [
          {'name': 'Keuangan'},
        ],
        onConflict: 'name',
      );
      expect(body!['on_conflict'], 'name');
    });

    test('galat aplikasi diteruskan sebagai ApiException', () async {
      final api = CloudApi(
        baseUrl: 'http://localhost:8080/backend',
        apiKey: '',
        client: MockClient((req) async {
          expect(req.headers.containsKey('X-Api-Key'), isFalse);
          return _json({'ok': false, 'error': 'Bentrok data.'}, 409);
        }),
      );
      await expectLater(
        api.select('bagian'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('Bentrok'))
            .having((e) => e.status, 'status', 409)),
      );
    });

    test('HTTP lain + JSON rusak jadi ApiException', () async {
      final api = CloudApi(
        baseUrl: 'http://localhost:8080/backend',
        client: MockClient((req) async {
          if (req.url.queryParameters['op'] == 'select') {
            return _json({'ok': false, 'error': 'Server error'}, 500);
          }
          return http.Response('<html>nope</html>', 200);
        }),
      );

      await expectLater(
        api.select('devices', where: const []),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('Server error'))
            .having((e) => e.status, 'status', 500)),
      );
      await expectLater(
        api.rev(),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('tidak valid'))),
      );
    });
  });
}

http.Response _json(Map<String, dynamic> data, [int status = 200]) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(data)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );