import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Global hooks for [SmartApiSocket] — same philosophy as [SmartApiHooks]:
/// the package never hard-codes a specific auth/push/session package, so
/// wire in whatever your app uses.
class SmartApiSocketHooks {
  /// Called right after the socket connects, to build the payload emitted
  /// as the "handshake" event (see [SmartApiSocket.init]'s
  /// `handshakeEvent`) — e.g. `{"id": userId, "device_token": fcmToken}`.
  ///
  /// Return an empty map to skip emitting a handshake for this connection
  /// (useful before the user is logged in). Async is supported, so you can
  /// await a push-notification token or a value from local storage here.
  static FutureOr<Map<String, dynamic>> Function()? buildHandshakePayload;

  /// Fired when the socket connects (before the handshake is sent).
  static void Function()? onConnected;

  /// Fired when the socket disconnects.
  static void Function()? onDisconnected;

  /// Fired when a connection attempt fails.
  static void Function(dynamic error)? onConnectError;

  /// Fired when the server acknowledges the handshake event (see
  /// [SmartApiSocket.init]'s `handshakeAckEvent`).
  static void Function(dynamic data)? onHandshakeAck;
}

/// A single, app-wide Socket.IO wrapper in the same spirit as
/// [SmartApiClient]: configure it once via [init], wire up
/// [SmartApiSocketHooks], and get connectivity-aware auto-reconnect plus a
/// handshake/acknowledgement flow for free — no per-project socket
/// boilerplate.
class SmartApiSocket {
  SmartApiSocket._internal();

  /// The shared, lazily-created singleton instance.
  static final SmartApiSocket instance = SmartApiSocket._internal();

  io.Socket? _socket;
  String? _handshakeEvent;
  String? _handshakeAckEvent;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Whether the transport-level socket connection is currently up.
  bool isConnected = false;

  /// Whether the handshake event (if any) has been acknowledged by the
  /// server on the current connection.
  bool isHandshakeComplete = false;

  /// Creates and connects the socket to [url].
  ///
  /// - [handshakeEvent]: event emitted right after connecting, with the
  ///   payload from [SmartApiSocketHooks.buildHandshakePayload]. Leave null
  ///   if your server doesn't need a post-connect handshake.
  /// - [handshakeAckEvent]: event the server emits back to acknowledge the
  ///   handshake. Defaults to the same name as [handshakeEvent].
  /// - [transports], [reconnectionAttempts], [reconnectionDelay]: passed
  ///   straight through to `socket_io_client`'s `OptionBuilder`.
  /// - [extraHeaders]: extra headers/options for the underlying engine.io
  ///   connection (defaults to `{'forceNew': 'true'}`, matching typical
  ///   Flutter socket setups).
  /// - [listenToConnectivity]: when true (default), the socket
  ///   auto-reconnects as soon as `connectivity_plus` reports the network
  ///   is back, and [isConnected]/[isHandshakeComplete] are reset to false
  ///   while offline.
  void init({
    required String url,
    String? handshakeEvent,
    String? handshakeAckEvent,
    List<String> transports = const ['websocket'],
    int reconnectionAttempts = 15,
    int reconnectionDelay = 2000,
    Map<String, dynamic>? extraHeaders,
    bool listenToConnectivity = true,
  }) {
    _handshakeEvent = handshakeEvent;
    _handshakeAckEvent = handshakeAckEvent ?? handshakeEvent;

    _socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(transports)
          .enableAutoConnect()
          .setReconnectionAttempts(reconnectionAttempts)
          .setReconnectionDelay(reconnectionDelay)
          .setExtraHeaders(extraHeaders ?? {'forceNew': 'true'})
          .build(),
    );

    _bindCoreListeners();

    if (listenToConnectivity) _startListeningToNetwork();
  }

  void _bindCoreListeners() {
    _socket?.onConnect((_) {
      isConnected = true;
      debugPrint("SmartApiSocket: connected ✅");
      SmartApiSocketHooks.onConnected?.call();
      _sendHandshake();
    });

    _socket?.onDisconnect((_) {
      isConnected = false;
      isHandshakeComplete = false;
      debugPrint("SmartApiSocket: disconnected ❌");
      SmartApiSocketHooks.onDisconnected?.call();
    });

    _socket?.onConnectError((data) {
      isConnected = false;
      debugPrint("SmartApiSocket: connect error -> $data");
      SmartApiSocketHooks.onConnectError?.call(data);
    });

    final ackEvent = _handshakeAckEvent;
    if (ackEvent != null) {
      _socket?.on(ackEvent, (data) {
        isHandshakeComplete = true;
        debugPrint("SmartApiSocket: handshake acknowledged ($ackEvent)");
        SmartApiSocketHooks.onHandshakeAck?.call(data);
      });
    }
  }

  Future<void> _sendHandshake() async {
    final event = _handshakeEvent;
    if (event == null || _socket?.connected != true) return;

    final builder = SmartApiSocketHooks.buildHandshakePayload;
    final payload = builder != null ? await builder() : const <String, dynamic>{};
    if (payload.isEmpty) return;

    _socket?.emit(event, payload);
    debugPrint("SmartApiSocket: handshake emitted ($event) -> $payload");
  }

  /// Re-sends the handshake manually — e.g. call this right after login,
  /// once [SmartApiSocketHooks.buildHandshakePayload] has a real user id
  /// to return.
  Future<void> resendHandshake() => _sendHandshake();

  void _startListeningToNetwork() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);

      if (hasConnection) {
        if (_socket?.connected != true) {
          debugPrint("SmartApiSocket: network back, reconnecting...");
          _socket?.connect();
        }
      } else {
        isConnected = false;
        isHandshakeComplete = false;
        debugPrint("SmartApiSocket: offline");
      }
    });
  }

  /// Registers a listener for a custom [event].
  void on(String event, void Function(dynamic data) handler) => _socket?.on(event, handler);

  /// Removes listener(s) for [event] — all of them, or just [handler] if
  /// one was given (see `socket_io_client`'s `Socket.off`).
  void off(String event, [void Function(dynamic data)? handler]) => _socket?.off(event, handler);

  /// Emits a custom [event], optionally with [data]. No-ops (with a debug
  /// log) if the socket isn't currently connected.
  void emit(String event, [dynamic data]) {
    if (_socket?.connected != true) {
      debugPrint("SmartApiSocket: emit(\"$event\") skipped — not connected");
      return;
    }
    _socket?.emit(event, data);
  }

  /// Manually (re)connects the socket.
  void connect() => _socket?.connect();

  /// Manually disconnects the socket (auto-reconnect via connectivity
  /// changes still applies unless you also call [dispose]).
  void disconnect() => _socket?.disconnect();

  /// The underlying `socket_io_client` [io.Socket], for anything this
  /// wrapper doesn't expose directly (rooms, ack callbacks, binary events,
  /// etc.).
  io.Socket? get raw => _socket;

  /// Cancels the connectivity listener and disposes the socket entirely.
  /// Call [init] again to start a fresh connection afterwards.
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _socket?.dispose();
    isConnected = false;
    isHandshakeComplete = false;
  }
}
