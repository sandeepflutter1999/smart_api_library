/// Dynamic Dio wrapper for Flutter — auto raw/multipart detection, global
/// loader/snackbar/toast hooks, session-expiry handling, no-internet
/// retry, and a connectivity-aware Socket.IO wrapper, no try/catch
/// boilerplate.
///
/// Import this single file to get the whole public API:
///
/// ```dart
/// import 'package:smart_api/smart_api.dart';
/// ```
library smart_api;

export 'smart_api_client.dart';
export 'smart_api_config.dart';
export 'smart_api_hooks.dart';
export 'smart_api_request.dart';
export 'smart_api_response.dart';
export 'smart_api_socket.dart';
export 'smart_api_toast.dart' show SmartApiToast, SmartApiToastStyle;
