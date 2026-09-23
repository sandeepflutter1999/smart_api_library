/// A simple no-argument callback, used for loader show/hide and retry hooks.
typedef VoidCb = void Function();

/// The kind of message being shown via [SmartApiHooks.showMessage].
///
/// Use this to pick a color/icon in your own UI (or in [SmartApiToast])
/// without `smart_api` ever importing a concrete UI package.
enum SmartApiMsgType { success, error, info, warning }

/// Signature for [SmartApiHooks.showMessage]: a plain string message plus
/// an optional [SmartApiMsgType] describing how it should look.
typedef MessageCb = void Function(String message, {SmartApiMsgType? type});

/// Global UI hooks that [SmartApiClient] fires instead of depending on any
/// concrete loader/snackbar/toast package.
///
/// Wire these once in `main()` (see the package README), and every call
/// made through `SmartApiClient.instance` will drive your app's own
/// loading indicator, message UI, session-expiry navigation and
/// no-internet retry flow automatically.
class SmartApiHooks {
  /// Called right before a request starts (when `showLoader` is true).
  static VoidCb? showLoader;

  /// Called after a request finishes (success or failure).
  static VoidCb? hideLoader;

  /// Called with a user-facing message whenever a request fails, or
  /// whenever you want to surface a message yourself.
  static MessageCb? showMessage;

  /// Called when a request comes back with a 401/403 status code, so you
  /// can navigate to your sign-in screen and clear any stored session.
  static VoidCb? onSessionExpired;

  /// Called when a request fails because there's no internet connection.
  /// The supplied [VoidCb] is a retry callback — call it to re-fire the
  /// exact request that failed.
  static void Function(VoidCb retry)? onNoInternet;

  /// Override the built-in connectivity check used before every request.
  ///
  /// Mainly useful for tests/demos that want to simulate being offline;
  /// leave this null to use the default `InternetAddress.lookup` check.
  static Future<bool> Function()? hasNetworkOverride;
}
