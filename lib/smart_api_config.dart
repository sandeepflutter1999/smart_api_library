import 'smart_api_response.dart';

/// Global, app-wide configuration for `smart_api`.
///
/// Call [SmartApiConfig.init] once, in `main()`, before making any calls
/// through `SmartApiClient.instance`. Every field below is also readable
/// directly if you need to inspect the active configuration at runtime.
class SmartApiConfig {
  /// Base URL prepended to every endpoint that doesn't already start
  /// with `http`.
  static late String baseUrl;

  /// Builds the headers sent with every request (e.g. an auth token).
  /// Called fresh before each call, so it always reflects the latest
  /// token/session state.
  static Map<String, dynamic> Function()? headerBuilder;

  /// Fully custom response parser. When set, this takes priority over
  /// [keyMap] for turning a raw JSON body into a [SmartApiEnvelope].
  static SmartApiEnvelope Function(dynamic json)? responseParser;

  /// Which JSON keys to look for (success/message/data/etc.) when using
  /// the default response parser instead of a custom [responseParser].
  static SmartApiKeyMap keyMap = const SmartApiKeyMap();

  /// Whether `File`s and local file paths inside a request body are
  /// auto-converted to multipart form data. Defaults to `true`; override
  /// per-request via `SmartApiRequest.autoDetectFiles`.
  static bool autoDetectFiles = true;

  /// Timeout for establishing a connection.
  static Duration connectTimeout = const Duration(seconds: 30);

  /// Timeout for receiving a response after the connection is open.
  static Duration receiveTimeout = const Duration(seconds: 30);

  /// Whether to trust self-signed TLS certificates. Only enable this for
  /// local development against a self-signed backend.
  static bool trustSelfSignedCert = false;

  /// Whether request/response details are printed via `debugPrint`.
  static bool enableLogging = true;

  /// Configures `smart_api` for the whole app. Call this once, as early
  /// as possible in `main()`, before any `SmartApiClient` call is made.
  static void init({
    required String baseUrl,
    Map<String, dynamic> Function()? headerBuilder,
    SmartApiEnvelope Function(dynamic json)? responseParser,
    SmartApiKeyMap keyMap = const SmartApiKeyMap(),
    bool autoDetectFiles = true,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    bool trustSelfSignedCert = false,
    bool enableLogging = true,
  }) {
    SmartApiConfig.baseUrl = baseUrl;
    SmartApiConfig.headerBuilder = headerBuilder;
    SmartApiConfig.responseParser = responseParser;
    SmartApiConfig.keyMap = keyMap;
    SmartApiConfigKeyMapHolder.keyMap = keyMap;
    SmartApiConfig.autoDetectFiles = autoDetectFiles;
    if (connectTimeout != null) SmartApiConfig.connectTimeout = connectTimeout;
    if (receiveTimeout != null) SmartApiConfig.receiveTimeout = receiveTimeout;
    SmartApiConfig.trustSelfSignedCert = trustSelfSignedCert;
    SmartApiConfig.enableLogging = enableLogging;
  }
}
