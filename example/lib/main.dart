import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:smart_api/smart_api.dart';

final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  SmartApiConfig.init(
    baseUrl: "https://reqres.in/api",
    headerBuilder: () => {"x-api-key": "reqres-free-v1"},
    responseParser: (json) {
      if (json is Map && json['error'] != null) {
        return SmartApiEnvelope(success: false, message: json['error'].toString());
      }
      return SmartApiEnvelope(success: true, data: json);
    },
  );

  SmartApiHooks.showLoader = () => isLoadingNotifier.value = true;
  SmartApiHooks.hideLoader = () => isLoadingNotifier.value = false;

  // Uses the package's own built-in SmartApiToast instead of a SnackBar —
  // no extra toast dependency needed.
  SmartApiHooks.showMessage = (msg, {type}) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      SmartApiToast.show(context, msg, style: SmartApiToast.styleForMsgType(type));
    }
  };

  SmartApiHooks.onSessionExpired = () {
    messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text("🔒 Session expired — onSessionExpired hook fired")),
    );
  };

  SmartApiHooks.onNoInternet = (retry) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text("📡 No internet — tap RETRY"),
        action: SnackBarAction(label: "RETRY", onPressed: retry),
        duration: const Duration(seconds: 10),
      ),
    );
  };

  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      title: 'smart_api demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  String _output = "Tap a button to fire a real request.";

  void _show(SmartApiResponse res) {
    setState(() {
      _output = res.success
          ? const JsonEncoder.withIndent('  ').convert(res.data)
          : "❌ ${res.message}";
    });
  }

  Future<void> _getUsers() async {
    final res = await SmartApiClient.instance.get("/users", params: {"page": 1});
    _show(res);
  }

  Future<void> _createUser() async {
    final res = await SmartApiClient.instance.post(
      "/users",
      body: {"name": "Sandeep", "job": "Flutter Developer"},
    );
    _show(res);
  }

  Future<void> _simulateNoInternetThenRetry() async {
    var firstCheck = true;
    SmartApiHooks.hasNetworkOverride = () async {
      if (firstCheck) {
        firstCheck = false;
        return false;
      }
      return true;
    };
    final res = await SmartApiClient.instance.get("/users", params: {"page": 2});
    SmartApiHooks.hasNetworkOverride = null;
    _show(res);
  }

  Future<void> _simulateSessionExpired() async {
    final res = await SmartApiClient.instance.get("https://httpstat.us/401");
    _show(res);
  }

  int _toastStyleIndex = 0;

  void _cycleToast() {
    final styles = SmartApiToastStyle.values;
    final style = styles[_toastStyleIndex % styles.length];
    _toastStyleIndex++;
    SmartApiToast.show(context, "Style: ${style.name}", style: style);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('smart_api — live demo')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(onPressed: _getUsers, child: const Text('GET /users')),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _createUser, child: const Text('POST /users (create)')),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _simulateNoInternetThenRetry,
                  child: const Text('Simulate no-internet + retry'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _simulateSessionExpired,
                  child: const Text('Simulate 401 (session expired)'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _cycleToast,
                  child: const Text('Cycle SmartApiToast styles'),
                ),
                const Divider(height: 32),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(_output, style: const TextStyle(fontFamily: 'monospace')),
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: isLoadingNotifier,
            builder: (context, loading, _) => loading
                ? Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
