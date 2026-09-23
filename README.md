# smart_api

Your previous `BaseClient` + `ApiProvider` pattern worked, but required writing the same 15-line `try/catch` block for every new project. This package centralizes that logic once, making it fully reusable across all your projects.

## Solves

- **Raw vs. multipart confusion** — Send a plain `Map`; if it contains a `File` or a valid local file path, the package automatically creates `FormData` and converts it to a `MultipartFile`. HTTP URL strings or plain text remain raw JSON. No manual conversions required.
- **Dynamic UI hooks (Loader / Snackbar / Toast)** — Zero hard-coded UI packages (GetX, Fluttertoast, custom widgets, etc.). Set your handlers once inside `SmartApiHooks`, and every call uses them automatically. A built-in, dependency-free `SmartApiToast` is included if you don't want to reach for a third-party toast package at all.
- **Centrally handled status codes** — 401/403 (session expired), timeouts, connection errors, and generic server errors are handled in one place instead of being rewritten across every API call.
- **No-internet retry flow** — The `onNoInternet(retry)` hook receives a retry callback. Simply call `retry()` from your "No Internet" screen to re-fire the exact failed request.
- **One line per call** — `SmartApiClient.instance.post(...)` — No `ApiRequest`, no `RequestType`, and no repetitive `DataResponse.fromJson` boilerplate.

## Setup (once, in main.dart)

```dart
import 'package:smart_api/smart_api.dart';

SmartApiConfig.init(
  baseUrl: "https://api.example.com",
  headerBuilder: () => {"Authorization": "Bearer $token"},
);

SmartApiHooks.showLoader = Utils.showLoading;
SmartApiHooks.hideLoader = Utils.hideLoading;
SmartApiHooks.showMessage = (msg, {type}) => Utils.showAlert(message: msg);
SmartApiHooks.onSessionExpired = () => Get.offAllNamed(AppRoutes.signIn);
SmartApiHooks.onNoInternet = (retry) => Get.to(() => NoInternetPage(onRetry: retry));
```

## Call an API

```dart
final res = await SmartApiClient.instance.post<UserModel>(
  "/api/login",
  body: {"email": email, "password": password},
  fromJson: (json) => UserModel.fromJson(json),
);

if (res.success) {
  // res.data is already typed as UserModel
} else {
  Utils.showAlert(message: res.message);
}
```

File upload — no separate `handleMultipartRequest` needed:

```dart
await SmartApiClient.instance.put("/api/editProfile", body: {
  "name": name,
  "image": pickedImage.path, // auto-detected and converted to multipart
});
```

See `example/lib/main.dart` for a full, runnable demo (GET/POST calls, no-internet retry, and session-expiry handling against a free test API).

## Backend response shape differs per project?

Two levels of control:

**1. Just rename keys (most cases)** — no custom parser required:

```dart
SmartApiConfig.init(
  baseUrl: "...",
  keyMap: const SmartApiKeyMap(
    successKeys: ['ok'],
    successValues: [true],
    messageKeys: ['msg'],
    dataKeys: ['payload'],
  ),
);
```

**2. Fully custom shape** (nested envelopes, etc.) — write a custom response parser:

```dart
SmartApiConfig.init(
  baseUrl: "...",
  responseParser: (json) => SmartApiEnvelope(
    success: json['meta']['ok'] == true,
    message: json['meta']['msg'] ?? '',
    data: json['payload'],
  ),
);
```

## File uploads — auto or explicit, single or multiple, custom key names

By default (`autoDetectFiles: true`), any `File` or valid local file path inside `body` is auto-converted to multipart. Disable it globally or per request to use explicit file bindings:

```dart
// Single image with a custom field name:
files: [SmartApiFile.single(key: "image", path: path)]

// Multiple images under the same field:
files: SmartApiFile.list(key: "images", paths: [p1, p2, p3])

// Different keys per file (e.g., front/back ID + selfie):
files: [
  SmartApiFile.single(key: "license_front", path: frontPath),
  SmartApiFile.single(key: "license_back", path: backPath),
  SmartApiFile.single(key: "profile_image", path: selfiePath),
]
```

Passing `files` always forces multipart mode, regardless of the `autoDetectFiles` setting. Standard text fields can still be passed in `body` alongside files.

## Sending a raw body (skip JSON-map / multipart handling)

By default a `Map` body is inspected for files and sent as JSON. If your
endpoint expects something else — a pre-encoded JSON string, XML, plain
text, etc. — pass `forceRaw: true` and `body` is sent exactly as given,
skipping file detection entirely:

```dart
await SmartApiClient.instance.post(
  "/api/webhook",
  body: '{"already":"encoded"}', // or any non-Map payload
  forceRaw: true,
);
```

`forceRaw` is available on both `post` and `put`.

## Query params on any method, not just GET

```dart
SmartApiClient.instance.post(
  "/api/roomSearch",
  body: data,                 // JSON or multipart body
  queryParams: {"id": roomId} // Appends ?id=... regardless of HTTP method
);
```

## Built-in toast/snackbar — `SmartApiToast`

No third-party toast package required. Sixteen-style-worth of look-and-feel
is driven by one small config table instead of copy-pasted widgets, so
picking a style is just an enum value:

```dart
SmartApiHooks.showMessage = (msg, {type}) => SmartApiToast.show(
  navigatorKey.currentContext!,
  msg,
  style: SmartApiToast.styleForMsgType(type), // or any SmartApiToastStyle directly
);
```

Available styles: `info`, `success`, `error`, `warning`, `elite`, `gradient`,
`timer`, `map`, `welcome`, `human`, `typewriter`.

## Realtime — `SmartApiSocket`

A connectivity-aware Socket.IO wrapper with the same philosophy as
`SmartApiClient`: configure it once, wire up `SmartApiSocketHooks`, and get
auto-reconnect + a handshake/acknowledgement flow for free. Nothing app-
specific (auth, push tokens, local DB) is hard-coded — you supply that via
hooks, same as `SmartApiHooks`.

**Setup (once, in main.dart):**

```dart
import 'package:smart_api/smart_api.dart';

SmartApiSocketHooks.buildHandshakePayload = () async {
  final userId = await getSavedUserId();      // however you store it
  if (userId == null) return {};              // skip handshake until logged in
  return {
    "id": userId,
    "device_token": await FirebaseMessaging.instance.getToken() ?? "",
  };
};

SmartApiSocketHooks.onConnected = () => debugPrint("socket up");
SmartApiSocketHooks.onDisconnected = () => debugPrint("socket down");
SmartApiSocketHooks.onHandshakeAck = (data) => debugPrint("handshake ok: $data");

SmartApiSocket.instance.init(
  url: "https://your-socket-server.com",
  handshakeEvent: "connect_user",     // emitted after connect
  handshakeAckEvent: "connect_user",  // event the server replies with
);
```

**Listening and emitting:**

```dart
SmartApiSocket.instance.on("new_message", (data) {
  // handle incoming event
});

SmartApiSocket.instance.emit("send_message", {"room": roomId, "text": text});
```

**After login**, once you actually have a user id to send:

```dart
await SmartApiSocket.instance.resendHandshake();
```

**Manual control / cleanup:**

```dart
SmartApiSocket.instance.connect();
SmartApiSocket.instance.disconnect();
SmartApiSocket.instance.dispose(); // stops connectivity listening too
```

`SmartApiSocket.instance.raw` gives you the underlying `socket_io_client`
`Socket` for anything not covered above (rooms, ack callbacks, etc.). See
`example/lib/main.dart` for a runnable connect/emit/listen demo.

## Future Roadmap Ideas

- Add `retryCount` to `SmartApiRequest` for automatic retries on 5xx responses.
- Add response caching (per-endpoint TTL) for list and query endpoints.
- Add a `downloadFile()` helper with progress callbacks using the same hook architecture.
# smart_api_library
# smart_api_library
# smart_api_library
