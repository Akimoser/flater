import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'animal.dart';

/// Ключ существует только в памяти процесса, не в Git или настройках.
class ApiSession {
  String token = '';
}

class TokenInterceptor extends Interceptor {
  TokenInterceptor(this.session);
  final ApiSession session;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.uri.scheme != 'https' ||
        options.uri.host != 'api.api-ninjas.com') {
      handler.reject(
        DioException(
          requestOptions: options,
          error: const ApiFailure('Недопустимый адрес API.'),
        ),
      );
      return;
    }
    final token = session.token.trim();
    if (token.isEmpty) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: const ApiFailure('Добавьте API-ключ в разделе «Доступ».'),
        ),
      );
      return;
    }
    options.headers['X-Api-Key'] = token;
    handler.next(options);
  }
}

Dio createDio(
  ApiSession session, {
  bool logging = kDebugMode,
  void Function(Object)? logPrint,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.api-ninjas.com/v1/',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      followRedirects: false,
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(TokenInterceptor(session));
  dio.interceptors.add(
    PrettyDioLogger(
      enabled: logging,
      requestHeader: false,
      requestBody: false,
      responseHeader: false,
      responseBody: false,
      error: false,
      logPrint: (message) {
        var text = message.toString();
        if (session.token.isNotEmpty) {
          text = text.replaceAll(session.token, '[REDACTED]');
        }
        if (logPrint != null) {
          logPrint(text);
        } else {
          debugPrint(text);
        }
      },
    ),
  );
  return dio;
}

class ApiFailure implements Exception {
  const ApiFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class AnimalRepository {
  AnimalRepository(this.dio);
  final Dio dio;
  Future<List<Animal>> search(String query, {CancelToken? cancelToken}) async {
    if (query.trim().isEmpty) {
      throw const ApiFailure('Введите название животного на английском.');
    }
    try {
      final response = await dio.get<Object?>(
        'animals',
        queryParameters: {'name': query.trim()},
        cancelToken: cancelToken,
      );
      if (response.data is! List) throw const FormatException();
      return (response.data as List)
          .map(
            (item) => Animal.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      if (error.error is ApiFailure) throw error.error!;
      final message = switch (error.response?.statusCode ?? 0) {
        401 || 403 => 'Ключ недействителен или у аккаунта нет доступа. Проверьте API Ninjas.',
        429 => 'Лимит запросов исчерпан. Повторите позже.',
        400 => 'API отклонил запрос. Проверьте название животного.',
        >= 500 => 'Сервис временно недоступен. Повторите позже.',
        _ => switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.sendTimeout =>
            'Сервер не ответил вовремя. Повторите запрос.',
          DioExceptionType.connectionError =>
            'Нет соединения. Проверьте интернет.',
          _ => 'Не удалось получить данные. Повторите запрос.',
        },
      };
      throw ApiFailure(message);
    } on FormatException {
      throw const ApiFailure('API вернул данные в неожиданном формате.');
    } on TypeError {
      throw const ApiFailure('API вернул данные в неожиданном формате.');
    }
  }
}
