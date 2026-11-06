import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flater/src/network.dart';

class FakeAdapter implements HttpClientAdapter {
  int status = 200;
  Object payload = [
    {
      'name': 'Fox',
      'locations': ['Europe'],
      'taxonomy': {'scientific_name': 'Vulpes vulpes'},
      'characteristics': {'diet': 'Omnivore'},
    },
  ];
  RequestOptions? last;
  DioExceptionType? failure;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure!);
    }
    return ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late ApiSession session;
  late Dio dio;
  late FakeAdapter adapter;
  late AnimalRepository repository;
  setUp(() {
    session = ApiSession()..token = 'unit-test-not-a-real-key';
    dio = createDio(session, logging: false);
    adapter = FakeAdapter();
    dio.httpClientAdapter = adapter;
    repository = AnimalRepository(dio);
  });
  tearDown(() => dio.close(force: true));
  test('Dio parses animals and interceptor adds current token', () async {
    final animals = await repository.search(' fox ');
    expect(animals.single.name, 'Fox');
    expect(adapter.last!.uri.path, '/v1/animals');
    expect(adapter.last!.queryParameters['name'], 'fox');
    expect(adapter.last!.headers['X-Api-Key'], session.token);
    session.token = 'changed-test-key';
    await repository.search('fox');
    expect(adapter.last!.headers['X-Api-Key'], 'changed-test-key');
  });
  test('missing token blocks HTTP', () async {
    session.token = '';
    await expectLater(repository.search('fox'), throwsA(isA<ApiFailure>()));
    expect(adapter.last, isNull);
  });
  test('token cannot be sent to foreign hosts', () async {
    await expectLater(
      dio.get('https://example.com/'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.last, isNull);
  });
  test('empty query blocks HTTP', () async {
    await expectLater(repository.search('  '), throwsA(isA<ApiFailure>()));
    expect(adapter.last, isNull);
  });
  for (final status in [401, 403, 429, 500]) {
    test('HTTP $status is a user-facing failure', () async {
      adapter.status = status;
      await expectLater(repository.search('fox'), throwsA(isA<ApiFailure>()));
    });
  }
  test('empty result is not an error', () async {
    adapter.payload = [];
    expect(await repository.search('missing'), isEmpty);
  });
  test('malformed payload is handled', () async {
    adapter.payload = {'unexpected': true};
    await expectLater(repository.search('fox'), throwsA(isA<ApiFailure>()));
  });
  test('timeout is translated', () async {
    adapter.failure = DioExceptionType.receiveTimeout;
    await expectLater(
      repository.search('fox'),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.message,
          'message',
          contains('вовремя'),
        ),
      ),
    );
  });
  test('cancelled request remains cancelled', () async {
    final cancel = CancelToken()..cancel();
    await expectLater(
      repository.search('fox', cancelToken: cancel),
      throwsA(
        isA<DioException>().having(CancelToken.isCancel, 'cancelled', isTrue),
      ),
    );
  });
  test('pretty logger never prints the key', () async {
    final messages = <Object>[];
    final logged = createDio(session, logging: true, logPrint: messages.add);
    logged.httpClientAdapter = adapter;
    await AnimalRepository(logged).search('fox');
    expect(messages, isNotEmpty);
    expect(messages.join(), isNot(contains(session.token)));
    logged.close();
  });
}
