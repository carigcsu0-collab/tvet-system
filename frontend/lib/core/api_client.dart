import 'package:dio/dio.dart';
import 'constants.dart';

class ApiClient {
  static String? _token;
  /// Called when any authenticated request receives a 401. Set by the app
  /// shell (via setOnUnauthorized) to trigger forceLogout on the AuthProvider.
  static void Function()? _onUnauthorized;

  static void setOnUnauthorized(void Function()? callback) {
    _onUnauthorized = callback;
  }

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            final auth = options.headers['Authorization'];
            if (auth == null || auth is! String || auth.isEmpty) {
              options.headers['Authorization'] = 'Bearer $_token';
            }
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          // Trigger forceLogout on a genuine 401 from any authenticated
          // request (token expired or revoked). Skip /auth/login so the
          // login screen itself doesn't trigger a logout loop.
          if (e.response?.statusCode == 401 &&
              !e.requestOptions.path.contains('/auth/login')) {
            _onUnauthorized?.call();
          }
          // Retry on connection timeout or send timeout (up to 2 retries)
          if (_shouldRetry(e) && (e.requestOptions.extra['retryCount'] ?? 0) < 2) {
            e.requestOptions.extra['retryCount'] =
                (e.requestOptions.extra['retryCount'] ?? 0) + 1;
            try {
              final response = await _dio.fetch(e.requestOptions);
              return handler.resolve(response);
            } catch (err) {
              return handler.next(err as DioException);
            }
          }
          handler.next(e);
        },
      ),
    );

  static bool _shouldRetry(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  static void setToken(String? token) {
    _token = token;
    if (token == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  static Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  static Future<Response> post(String path, {dynamic data}) async {
    return _dio.post(path, data: data);
  }

  /// POSTs [data] and returns the raw response bytes (e.g. a generated PDF).
  static Future<List<int>> postBytes(String path, {dynamic data}) async {
    final response = await _dio.post(
      path,
      data: data,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data as List<int>;
  }

  static Future<Response> put(String path, {dynamic data}) async {
    return _dio.put(path, data: data);
  }

  static Future<Response> delete(String path, {dynamic data}) async {
    return _dio.delete(path, data: data);
  }

  /// Downloads a binary file (e.g. generated .docx) to [savePath].
  static Future<void> downloadFile(String path, String savePath) async {
    await _dio.download(path, savePath);
  }
}
