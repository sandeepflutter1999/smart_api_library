# Changelog

## 1.1.1

- Added `SmartApiSocket`: a connectivity-aware Socket.IO wrapper
  (`socket_io_client` + `connectivity_plus`) with the same hook-driven
  philosophy as `SmartApiClient` — global `SmartApiSocketHooks` for
  connect/disconnect/handshake events, auto-reconnect on network
  changes, and no per-project socket boilerplate.
- Added `forceRaw` to `SmartApiClient.post`/`put` so a body can be sent
  exactly as given (string/XML/pre-encoded payload), skipping the
  JSON-map/multipart handling entirely.

## 1.0.5

- Added `SmartApiToast`: a built-in, config-driven toast/snackbar widget
  (success, error, warning, info, glass, gradient, timer, map, welcome,
  human-runner and typewriter styles) so `SmartApiHooks.showMessage` no
  longer needs a third-party toast package.
- Moved the runnable demo out of `lib/` and into `example/lib/main.dart`
  so the package ships a proper pub.dev example.
- Removed generated Flutter asset bindings (`lib/generated/`) that were
  never part of the public API and were dragging down documentation
  coverage.
- Added dartdoc comments across the public API (`SmartApiClient`,
  `SmartApiConfig`, `SmartApiHooks`, `SmartApiRequest`, `SmartApiFile`,
  `SmartApiResponse`, `SmartApiEnvelope`, `SmartApiKeyMap`).
- Added a `smart_api.dart` barrel file so the whole package can be
  imported with a single `import 'package:smart_api/smart_api.dart';`.

## 1.0.1

- Fixed `pubspec.yaml`: shortened `description` to fit pub.dev's 60–180character limit and added `homepage`/`repository`/`issue_tracker`
  fields.

## 1.0.0

- Initial release.
- Auto multipart/raw detection for request bodies.
- Explicit `SmartApiFile` support for single/multiple file uploads with
  custom form-field keys.
- Fully configurable response parsing via `SmartApiKeyMap` or a custom
  `responseParser`.
- Global UI hooks (`SmartApiHooks`) for loaders, snackbars, session
  expiry, and no-internet retry.
- Query params supported on every HTTP method, not just GET.
