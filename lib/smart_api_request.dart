/// The HTTP verb a [SmartApiRequest] should use.
enum ApiMethod { get, post, put, patch, delete }

/// Describes a single file to attach to a multipart request.
///
/// Prefer the [SmartApiFile.single] and [SmartApiFile.list] factories over
/// the default constructor when binding files to explicit form-field keys
/// (e.g. `license_front`, `license_back`, `selfie`).
class SmartApiFile {
  /// The multipart form-field name this file is sent under.
  final String key;

  /// Local filesystem path of the file to upload.
  final String path;

  /// Optional override for the filename sent to the server. Defaults to
  /// the last path segment of [path] when omitted.
  final String? fileName;

  /// Creates a file binding directly. Most callers should use
  /// [SmartApiFile.single] or [SmartApiFile.list] instead.
  const SmartApiFile({required this.key, required this.path, this.fileName});

  /// A single file under a custom form-field [key], e.g.
  /// `SmartApiFile.single(key: "image", path: path)`.
  factory SmartApiFile.single({required String key, required String path, String? fileName}) =>
      SmartApiFile(key: key, path: path, fileName: fileName);

  /// Multiple files grouped under the same form-field [key], e.g.
  /// `SmartApiFile.list(key: "images", paths: [p1, p2, p3])`.
  static List<SmartApiFile> list({required String key, required List<String> paths}) =>
      paths.map((p) => SmartApiFile(key: key, path: p)).toList();
}

/// A fully-described API call, consumed by `SmartApiClient.call`.
///
/// You normally won't construct this directly — the `get`/`post`/`put`/
/// `delete` helpers on `SmartApiClient` build one for you — but it's
/// public so you can compose your own request pipeline if needed.
class SmartApiRequest {
  /// The endpoint to call. Either a path appended to `SmartApiConfig.baseUrl`
  /// (e.g. `/api/login`) or a full `http(s)://` URL.
  final String endpoint;

  /// The HTTP verb to use. Defaults to [ApiMethod.get].
  final ApiMethod method;

  /// Request body. A plain `Map` is sent as JSON unless it contains a
  /// `File`/local file path (auto-detected) or [files] is also set, in
  /// which case it's sent as multipart form data.
  final dynamic body;

  /// Explicit file bindings. Passing this always forces multipart mode,
  /// regardless of [autoDetectFiles].
  final List<SmartApiFile>? files;

  /// Query parameters appended to the URL, supported on every HTTP
  /// method (not just GET).
  final Map<String, dynamic>? queryParams;

  /// Per-request override for `SmartApiConfig.autoDetectFiles`.
  final bool? autoDetectFiles;

  /// Forces the body to be sent as multipart form data even if no file
  /// is detected.
  final bool forceMultipart;

  /// Forces the body to be sent as-is (raw), skipping file detection.
  final bool forceRaw;

  /// Whether `SmartApiHooks.showLoader`/`hideLoader` should fire for this
  /// request. Defaults to `true`.
  final bool showLoader;

  /// Extra headers merged on top of `SmartApiConfig.headerBuilder`'s
  /// result for this request only.
  final Map<String, dynamic>? extraHeaders;

  /// Creates a request. See the field docs above for defaults.
  const SmartApiRequest({
    required this.endpoint,
    this.method = ApiMethod.get,
    this.body,
    this.files,
    this.queryParams,
    this.autoDetectFiles,
    this.forceMultipart = false,
    this.forceRaw = false,
    this.showLoader = true,
    this.extraHeaders,
  });
}
