/// Tells `smart_api` which JSON keys to look for when your backend's
/// response shape doesn't match the library's defaults.
///
/// Pass this to `SmartApiConfig.init(keyMap: ...)` when renaming keys is
/// enough (e.g. your backend uses `ok`/`msg`/`payload` instead of
/// `success`/`message`/`data`). For a fully custom or nested response
/// envelope, use `SmartApiConfig.init(responseParser: ...)` instead.
class SmartApiKeyMap {
  /// Candidate keys checked, in order, for the success flag.
  final List<String> successKeys;

  /// Values that count as "successful" for whichever [successKeys] entry
  /// is found (e.g. `true`, `1`, `200`).
  final List<dynamic> successValues;

  /// Candidate keys checked, in order, for the response message.
  final List<String> messageKeys;

  /// Candidate keys checked, in order, for a status code embedded in the
  /// response body itself (as opposed to the HTTP status code).
  final List<String> statusCodeKeys;

  /// Candidate keys checked, in order, for the actual payload/data.
  final List<String> dataKeys;

  /// Creates a key map. The defaults cover the most common backend
  /// conventions, so most apps only need to override a subset.
  const SmartApiKeyMap({
    this.successKeys = const ['success', 'status', 'ok'],
    this.successValues = const [true, 1, '1', 200, 'success', 'true'],
    this.messageKeys = const ['message', 'msg', 'error'],
    this.statusCodeKeys = const ['status_code', 'statusCode', 'code'],
    this.dataKeys = const ['data', 'body', 'result', 'payload'],
  });
}

/// The parsed, normalized shape of a raw JSON response body, produced by
/// either [SmartApiEnvelope.defaultParse] or a custom
/// `SmartApiConfig.responseParser`.
class SmartApiEnvelope {
  /// Whether the backend considered this request successful.
  final bool success;

  /// A human-readable message extracted from the response, if any.
  final String message;

  /// A status code embedded in the response body, if any (distinct from
  /// the HTTP status code).
  final int? statusCode;

  /// The raw, un-typed payload extracted from the response body.
  final dynamic data;

  /// Creates an envelope directly. Most callers get one back from
  /// [SmartApiEnvelope.defaultParse] rather than constructing it by hand.
  const SmartApiEnvelope({
    required this.success,
    this.message = "",
    this.statusCode,
    this.data,
  });

  /// The default response parser, used when no custom
  /// `SmartApiConfig.responseParser` is set. Reads keys according to
  /// [SmartApiConfigKeyMapHolder.keyMap] (set via
  /// `SmartApiConfig.init(keyMap: ...)`).
  factory SmartApiEnvelope.defaultParse(dynamic json) {
    final km = SmartApiConfigKeyMapHolder.keyMap;
    if (json is! Map) {
      return SmartApiEnvelope(success: false, message: json?.toString() ?? "");
    }

    dynamic successRaw;
    for (final k in km.successKeys) {
      if (json.containsKey(k)) {
        successRaw = json[k];
        break;
      }
    }
    final success = km.successValues.contains(successRaw);

    String message = "";
    for (final k in km.messageKeys) {
      if (json[k] != null) {
        message = json[k].toString();
        break;
      }
    }

    int? statusCode;
    for (final k in km.statusCodeKeys) {
      if (json[k] != null) {
        statusCode = json[k] is int ? json[k] as int : int.tryParse(json[k].toString());
        break;
      }
    }

    dynamic data;
    for (final k in km.dataKeys) {
      if (json.containsKey(k)) {
        data = json[k];
        break;
      }
    }

    return SmartApiEnvelope(success: success, message: message, statusCode: statusCode, data: data);
  }
}

/// Internal holder so [SmartApiEnvelope.defaultParse] can read the
/// currently configured [SmartApiKeyMap] without importing
/// `smart_api_config.dart` (which would create a import cycle).
class SmartApiConfigKeyMapHolder {
  /// The active key map, kept in sync by `SmartApiConfig.init`.
  static SmartApiKeyMap keyMap = const SmartApiKeyMap();
}

/// The typed result handed back from every `SmartApiClient` call.
///
/// Check [success] first; when it's `true`, [data] is populated (typed as
/// `T` if you passed a `fromJson` converter). When it's `false`, use
/// [message] for a user-facing error and [statusCode]/[raw] for
/// debugging.
class SmartApiResponse<T> {
  /// Whether the call succeeded, per [SmartApiEnvelope.success] (or your
  /// custom `responseParser`).
  final bool success;

  /// A human-readable message — populated on failure, and on success only
  /// if your backend includes one.
  final String message;

  /// The HTTP status code of the response, when available.
  final int? statusCode;

  /// The typed payload, converted with `fromJson` if one was supplied.
  /// Null when [success] is `false` or the backend returned no data.
  final T? data;

  /// The raw, un-typed response body, useful for debugging or for
  /// reading fields your `fromJson` converter doesn't cover.
  final dynamic raw;

  /// Creates a response directly. You'll normally receive one from
  /// `SmartApiClient.instance.get/post/put/delete` rather than
  /// constructing it yourself.
  const SmartApiResponse({
    required this.success,
    this.message = "",
    this.statusCode,
    this.data,
    this.raw,
  });
}
