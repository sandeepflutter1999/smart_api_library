import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import 'smart_api_config.dart';
import 'smart_api_hooks.dart';
import 'smart_api_request.dart';
import 'smart_api_response.dart';

/// A single, app-wide Dio wrapper that turns every API call into one line.
///
/// Configure it once via `SmartApiConfig.init` and wire up
/// `SmartApiHooks`, then call [get], [post], [put] or [delete] — file
/// detection, multipart conversion, loader/message hooks, session-expiry
/// and no-internet retry are all handled centrally.
class SmartApiClient {
  SmartApiClient._internal() : _dio = _buildDio();

  /// The shared, lazily-created singleton instance.
  static final SmartApiClient instance = SmartApiClient._internal();

  final Dio _dio;

  static Dio _buildDio() {
    final dio = Dio(BaseOptions(
      connectTimeout: SmartApiConfig.connectTimeout,
      receiveTimeout: SmartApiConfig.receiveTimeout,
    ));

    if (SmartApiConfig.trustSelfSignedCert) {
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient(context: SecurityContext(withTrustedRoots: false));
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };
    }

    dio.interceptors.add(_LoggingInterceptor());
    return dio;
  }

  /// Executes a fully-described [request] and returns a typed
  /// [SmartApiResponse]. This is what [get], [post], [put] and [delete]
  /// build a [SmartApiRequest] and delegate to — call it directly if you
  /// need full control (custom [ApiMethod], forced multipart/raw, etc.).
  Future<SmartApiResponse<T>> call<T>(
    SmartApiRequest request, {
    T Function(dynamic json)? fromJson,
  }) async {
    if (request.showLoader) SmartApiHooks.showLoader?.call();

    final online = await _hasNetwork();
    if (!online) {
      if (request.showLoader) SmartApiHooks.hideLoader?.call();
      return _awaitRetryOrFail<T>(request, fromJson);
    }

    final url = request.endpoint.startsWith('http')
        ? request.endpoint
        : '${SmartApiConfig.baseUrl}${request.endpoint}';

    final headers = <String, dynamic>{
      ...?SmartApiConfig.headerBuilder?.call(),
      ...?request.extraHeaders,
    };

    try {
      final payload = await _resolveBody(
        request.body,
        forceMultipart: request.forceMultipart,
        forceRaw: request.forceRaw,
        autoDetectFiles: request.autoDetectFiles ?? SmartApiConfig.autoDetectFiles,
        files: request.files,
      );
      final options = Options(headers: headers);

      final query = <String, dynamic>{
        if (request.method == ApiMethod.get && request.body is Map)
          ...(request.body as Map).cast<String, dynamic>(),
        ...?request.queryParams,
      };
      final queryParameters = query.isEmpty ? null : query;

      Response response;
      switch (request.method) {
        case ApiMethod.get:
          response = await _dio.get(url, queryParameters: queryParameters, options: options);
          break;
        case ApiMethod.post:
          response = await _dio.post(url, data: payload, queryParameters: queryParameters, options: options);
          break;
        case ApiMethod.put:
          response = await _dio.put(url, data: payload, queryParameters: queryParameters, options: options);
          break;
        case ApiMethod.patch:
          response = await _dio.patch(url, data: payload, queryParameters: queryParameters, options: options);
          break;
        case ApiMethod.delete:
          response = await _dio.delete(url, data: payload, queryParameters: queryParameters, options: options);
          break;
      }

      if (request.showLoader) SmartApiHooks.hideLoader?.call();

      final envelope = (SmartApiConfig.responseParser ?? SmartApiEnvelope.defaultParse)
          .call(response.data);

      return SmartApiResponse<T>(
        success: envelope.success,
        message: envelope.message,
        statusCode: response.statusCode,
        data: fromJson != null && envelope.data != null
            ? fromJson(envelope.data)
            : envelope.data as T?,
        raw: response.data,
      );
    } on DioException catch (e) {
      if (request.showLoader) SmartApiHooks.hideLoader?.call();
      return _handleDioError<T>(e);
    } catch (e) {
      if (request.showLoader) SmartApiHooks.hideLoader?.call();
      const msg = "Something went wrong. Try again.";
      SmartApiHooks.showMessage?.call(msg, type: SmartApiMsgType.error);
      return SmartApiResponse<T>(success: false, message: msg);
    }
  }

  /// Sends a GET request to [endpoint], with [params] appended as query
  /// parameters. Pass [fromJson] to get back a typed [SmartApiResponse].
  Future<SmartApiResponse<T>> get<T>(String endpoint,
          {Map<String, dynamic>? params,
          T Function(dynamic)? fromJson,
          bool showLoader = true}) =>
      call<T>(SmartApiRequest(endpoint: endpoint, method: ApiMethod.get, body: params, showLoader: showLoader),
          fromJson: fromJson);

  /// Sends a POST request to [endpoint]. If [body] contains a `File` or
  /// local file path (and [autoDetectFiles] isn't disabled), or [files]
  /// is provided, the request is sent as multipart form data — otherwise
  /// it's sent as raw JSON.
  Future<SmartApiResponse<T>> post<T>(String endpoint,
          {dynamic body,
          List<SmartApiFile>? files,
          Map<String, dynamic>? queryParams,
          bool? autoDetectFiles,
          T Function(dynamic)? fromJson,
          bool showLoader = true}) =>
      call<T>(
          SmartApiRequest(
            endpoint: endpoint,
            method: ApiMethod.post,
            body: body,
            files: files,
            queryParams: queryParams,
            autoDetectFiles: autoDetectFiles,
            showLoader: showLoader,
          ),
          fromJson: fromJson);

  /// Sends a PUT request to [endpoint]. Same auto raw/multipart
  /// detection as [post] applies to [body] and [files].
  Future<SmartApiResponse<T>> put<T>(String endpoint,
          {dynamic body,
          List<SmartApiFile>? files,
          Map<String, dynamic>? queryParams,
          bool? autoDetectFiles,
          T Function(dynamic)? fromJson,
          bool showLoader = true}) =>
      call<T>(
          SmartApiRequest(
            endpoint: endpoint,
            method: ApiMethod.put,
            body: body,
            files: files,
            queryParams: queryParams,
            autoDetectFiles: autoDetectFiles,
            showLoader: showLoader,
          ),
          fromJson: fromJson);

  /// Sends a DELETE request to [endpoint], optionally with a JSON [body]
  /// and/or [queryParams].
  Future<SmartApiResponse<T>> delete<T>(String endpoint,
          {dynamic body, Map<String, dynamic>? queryParams, T Function(dynamic)? fromJson, bool showLoader = true}) =>
      call<T>(
          SmartApiRequest(
              endpoint: endpoint,
              method: ApiMethod.delete,
              body: body,
              queryParams: queryParams,
              showLoader: showLoader),
          fromJson: fromJson);

  Future<dynamic> _resolveBody(
    dynamic body, {
    required bool forceMultipart,
    required bool forceRaw,
    required bool autoDetectFiles,
    List<SmartApiFile>? files,
  }) async {
    final hasExplicitFiles = files != null && files.isNotEmpty;

    if (body == null && !hasExplicitFiles) return null;
    if (forceRaw && !hasExplicitFiles) return body;
    if (body != null && body is! Map && !hasExplicitFiles) return body;

    bool hasFile = forceMultipart || hasExplicitFiles;
    final map = <String, dynamic>{};

    if (body is Map) {
      for (final entry in body.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (autoDetectFiles) {
          map[key] = await _resolveValue(value, onFileFound: () => hasFile = true);
        } else {
          map[key] = value;
        }
      }
    }

    if (hasExplicitFiles) {
      final grouped = <String, List<MultipartFile>>{};
      for (final f in files) {
        final mf = await MultipartFile.fromFile(f.path, filename: f.fileName ?? f.path.split('/').last);
        grouped.putIfAbsent(f.key, () => []).add(mf);
      }
      grouped.forEach((key, list) {
        map[key] = list.length == 1 ? list.first : list;
      });
    }

    return hasFile ? FormData.fromMap(map) : map;
  }

  Future<dynamic> _resolveValue(dynamic value, {required VoidCallback onFileFound}) async {
    if (value is File) {
      onFileFound();
      return MultipartFile.fromFile(value.path, filename: value.path.split('/').last);
    }
    if (value is String && _looksLikeLocalFile(value)) {
      onFileFound();
      return MultipartFile.fromFile(value, filename: value.split('/').last);
    }
    if (value is List) {
      final resolved = [];
      for (final item in value) {
        resolved.add(await _resolveValue(item, onFileFound: onFileFound));
      }
      return resolved;
    }
    return value;
  }

  bool _looksLikeLocalFile(String value) {
    if (value.isEmpty || value.startsWith('http')) return false;
    try {
      return File(value).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasNetwork() async {
    if (SmartApiHooks.hasNetworkOverride != null) {
      return SmartApiHooks.hasNetworkOverride!.call();
    }
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<SmartApiResponse<T>> _awaitRetryOrFail<T>(
      SmartApiRequest request, T Function(dynamic)? fromJson) {
    if (SmartApiHooks.onNoInternet == null) {
      return Future.value(const SmartApiResponse(success: false, message: "No internet connection"));
    }
    final completer = Completer<SmartApiResponse<T>>();
    SmartApiHooks.onNoInternet!.call(() async {
      completer.complete(await call<T>(request, fromJson: fromJson));
    });
    return completer.future;
  }

  SmartApiResponse<T> _handleDioError<T>(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    final serverMsg = data is Map ? data['message']?.toString() : null;

    if (statusCode == 401 || statusCode == 403) {
      SmartApiHooks.onSessionExpired?.call();
      return SmartApiResponse<T>(
        success: false,
        statusCode: statusCode,
        message: serverMsg ?? "Session expired",
      );
    }

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.response == null) {
      const msg = "Something went wrong. Try again.";
      SmartApiHooks.showMessage?.call(msg, type: SmartApiMsgType.error);
      return const SmartApiResponse(success: false, message: msg);
    }

    return SmartApiResponse<T>(
      success: false,
      statusCode: statusCode,
      message: serverMsg ?? "Something went wrong",
      raw: data,
    );
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (SmartApiConfig.enableLogging) {
      debugPrint("➡️ ${options.method} ${options.uri}");
      if (options.data != null) debugPrint("Body: ${options.data}");
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (SmartApiConfig.enableLogging) {
      debugPrint("✅ ${response.statusCode} ${response.requestOptions.uri}");
      debugPrint("Response: ${response.data}");
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (SmartApiConfig.enableLogging) {
      debugPrint("❌ ${err.requestOptions.uri} -> ${err.message}");
    }
    super.onError(err, handler);
  }
}
