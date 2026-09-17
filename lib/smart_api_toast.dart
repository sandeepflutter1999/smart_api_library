import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'smart_api_hooks.dart';

/// Visual styles supported by [SmartApiToast].
///
/// Every style is rendered by the same widget tree — see
/// [SmartApiToast.show] — driven by a small per-style config table, so
/// adding a new look never means copy-pasting a whole layout.
enum SmartApiToastStyle {
  /// Plain dark pill, slides in from the top.
  info,

  /// Frosted "glass" card with a green check icon.
  success,

  /// Frosted "glass" card with a red icon and a short shake animation.
  error,

  /// Frosted "glass" card with an amber warning icon.
  warning,

  /// Frosted "glass" pill that slides in from the right.
  elite,

  /// Purple gradient pill, slides up from the bottom.
  gradient,

  /// Dark pill with a countdown timer suffix (e.g. "Arriving in 8s").
  timer,

  /// Frosted "glass" card with a photo header, for location-style updates.
  map,

  /// White card with a wave emoji, for "welcome back" style greetings.
  welcome,

  /// A running-person emoji beside the pill, slides in from the right.
  human,

  /// Dark pill whose text is revealed one character at a time.
  typewriter,
}

/// Where a toast enters the screen from.
enum _SlideFrom { top, bottom, right }

/// Declarative description of one [SmartApiToastStyle].
///
/// [SmartApiToast] holds no per-style widget code — it reads one of these
/// and builds the same layout every time, just with different colors,
/// icon, background and behaviour flags. To add a new style, add one
/// entry to [_styleConfigs] below.
class _ToastStyleConfig {
  final IconData? icon;
  final Color iconColor;
  final Color background;
  final Gradient? gradient;
  final bool glass;
  final _SlideFrom slideFrom;
  final Alignment alignment;
  final bool shakeOnEnter;
  final bool typewriter;
  final bool countdown;
  final bool humanRunner;
  final Color textColor;
  final String? emoji;
  final String? emojiLabel;

  const _ToastStyleConfig({
    this.icon,
    this.iconColor = Colors.white,
    this.background = const Color(0xFF323232),
    this.gradient,
    this.glass = false,
    this.slideFrom = _SlideFrom.top,
    this.alignment = Alignment.topCenter,
    this.shakeOnEnter = false,
    this.typewriter = false,
    this.countdown = false,
    this.humanRunner = false,
    this.textColor = Colors.white,
    this.emoji,
    this.emojiLabel,
  });
}

final Map<SmartApiToastStyle, _ToastStyleConfig> _styleConfigs = {
  SmartApiToastStyle.info: const _ToastStyleConfig(
    icon: Icons.info_outline,
  ),
  SmartApiToastStyle.success: const _ToastStyleConfig(
    icon: Icons.check_circle_rounded,
    iconColor: Color(0xFF2E7D32),
    background: Colors.white,
    glass: true,
    textColor: Colors.black87,
  ),
  SmartApiToastStyle.error: const _ToastStyleConfig(
    icon: Icons.error_outline_rounded,
    iconColor: Colors.redAccent,
    background: Colors.white,
    glass: true,
    shakeOnEnter: true,
    textColor: Colors.black87,
  ),
  SmartApiToastStyle.warning: const _ToastStyleConfig(
    icon: Icons.warning_amber_rounded,
    iconColor: Colors.orange,
    background: Colors.white,
    glass: true,
    textColor: Colors.black87,
  ),
  SmartApiToastStyle.elite: const _ToastStyleConfig(
    background: Colors.white,
    glass: true,
    slideFrom: _SlideFrom.right,
    textColor: Colors.black,
  ),
  SmartApiToastStyle.gradient: const _ToastStyleConfig(
    gradient: LinearGradient(
      colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    slideFrom: _SlideFrom.bottom,
    alignment: Alignment.bottomCenter,
  ),
  SmartApiToastStyle.timer: const _ToastStyleConfig(
    icon: Icons.timer_outlined,
    iconColor: Colors.orangeAccent,
    background: Color(0xFF263238),
    countdown: true,
  ),
  SmartApiToastStyle.map: const _ToastStyleConfig(
    icon: Icons.navigation,
    iconColor: Colors.blue,
    background: Colors.white,
    glass: true,
    textColor: Colors.black87,
  ),
  SmartApiToastStyle.welcome: const _ToastStyleConfig(
    background: Colors.white,
    iconColor: Colors.pinkAccent,
    textColor: Colors.black87,
    emoji: '👋',
    emojiLabel: 'Welcome Back!',
  ),
  SmartApiToastStyle.human: const _ToastStyleConfig(
    background: Color(0xFFFF9800),
    slideFrom: _SlideFrom.right,
    humanRunner: true,
  ),
  SmartApiToastStyle.typewriter: const _ToastStyleConfig(
    background: Color(0xFF333333),
    typewriter: true,
  ),
};

/// A single-file, dependency-free toast/snackbar overlay for
/// `smart_api`.
///
/// Because the whole point of `SmartApiHooks.showMessage` is to avoid
/// forcing any particular UI package on you, this widget is entirely
/// optional — wire it up like so:
///
/// ```dart
/// SmartApiHooks.showMessage = (msg, {type}) => SmartApiToast.show(
///   navigatorKey.currentContext!,
///   msg,
///   style: SmartApiToast.styleForMsgType(type),
/// );
/// ```
///
/// Only one toast is shown at a time — calling [show] again replaces
/// whatever is currently on screen.
class SmartApiToast {
  SmartApiToast._();

  static OverlayEntry? _current;

  /// Maps a [SmartApiMsgType] (from [SmartApiHooks.showMessage]) to a
  /// sensible default [SmartApiToastStyle].
  static SmartApiToastStyle styleForMsgType(SmartApiMsgType? type) {
    switch (type) {
      case SmartApiMsgType.success:
        return SmartApiToastStyle.success;
      case SmartApiMsgType.error:
        return SmartApiToastStyle.error;
      case SmartApiMsgType.warning:
        return SmartApiToastStyle.warning;
      case SmartApiMsgType.info:
      case null:
        return SmartApiToastStyle.info;
    }
  }

  /// Shows [message] in the given [style] (default
  /// [SmartApiToastStyle.info]) for [duration] (default 3.5 seconds).
  ///
  /// Requires a [context] with an [Overlay] above it (any context under
  /// a `MaterialApp`/`Navigator` works).
  static void show(
    BuildContext context,
    String message, {
    SmartApiToastStyle style = SmartApiToastStyle.info,
    Duration duration = const Duration(milliseconds: 3500),
  }) {
    final overlay = Overlay.of(context);
    _current?.remove();
    _current = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _SmartApiToastWidget(
        message: message,
        config: _styleConfigs[style] ?? const _ToastStyleConfig(),
        duration: duration,
        onDismiss: () {
          if (_current == entry) {
            entry.remove();
            _current = null;
          }
        },
      ),
    );

    _current = entry;
    overlay.insert(entry);
  }

  /// Removes any toast currently on screen, if one is showing.
  static void hide() {
    _current?.remove();
    _current = null;
  }
}

/// Internal widget that renders whichever [_ToastStyleConfig] it's given.
/// Not part of the public API — construct toasts via [SmartApiToast.show].
class _SmartApiToastWidget extends StatefulWidget {
  final String message;
  final _ToastStyleConfig config;
  final Duration duration;
  final VoidCallback onDismiss;

  const _SmartApiToastWidget({
    required this.message,
    required this.config,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_SmartApiToastWidget> createState() => _SmartApiToastWidgetState();
}

class _SmartApiToastWidgetState extends State<_SmartApiToastWidget> with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _shake;
  late final Animation<Offset> _offset;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _shakeAnim;

  String _displayedText = '';
  Timer? _timer;
  int _secondsLeft = 10;

  @override
  void initState() {
    super.initState();
    final cfg = widget.config;

    _displayedText = cfg.typewriter ? '' : (cfg.countdown ? '${widget.message} $_secondsLeft s' : widget.message);

    _enter = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _shake = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);

    final begin = switch (cfg.slideFrom) {
      _SlideFrom.top => const Offset(0, -1.5),
      _SlideFrom.bottom => const Offset(0, 1.5),
      _SlideFrom.right => const Offset(2, 0),
    };
    _offset = Tween<Offset>(begin: begin, end: Offset.zero)
        .animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutBack));
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _enter, curve: Curves.elasticOut));
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeIn);
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(_shake);

    _enter.forward().then((_) {
      HapticFeedback.mediumImpact();
      if (cfg.typewriter) _startTypewriter();
      if (cfg.countdown) _startCountdown();
      if (cfg.shakeOnEnter) {
        HapticFeedback.vibrate();
        _shake.forward();
      }
    });

    Future.delayed(widget.duration, () {
      if (!mounted) return;
      _enter.reverse().then((_) => widget.onDismiss());
    });
  }

  void _startTypewriter() {
    var index = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (index >= widget.message.length) {
        timer.cancel();
        return;
      }
      if (mounted) setState(() => _displayedText += widget.message[index]);
      index++;
    });
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 0) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          _secondsLeft--;
          _displayedText = '${widget.message} $_secondsLeft s';
        });
      }
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _shake.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cfg.icon != null) ...[
          Icon(cfg.icon, color: cfg.iconColor, size: 26),
          const SizedBox(width: 12),
        ],
        if (cfg.emoji != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: cfg.iconColor.withOpacity(0.08), shape: BoxShape.circle),
            child: Text(cfg.emoji!, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cfg.emojiLabel != null)
                Text(
                  cfg.emojiLabel!,
                  style: TextStyle(color: cfg.iconColor, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              Text(
                _displayedText,
                style: TextStyle(color: cfg.textColor, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
        ),
        if (cfg.countdown) ...[
          const SizedBox(width: 16),
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(cfg.iconColor)),
          ),
        ],
      ],
    );

    final card = Container(
      constraints: const BoxConstraints(maxWidth: 400, minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: cfg.gradient == null ? cfg.background.withOpacity(cfg.glass ? 0.55 : 1) : null,
        gradient: cfg.gradient,
        borderRadius: BorderRadius.circular(18),
        border: cfg.glass ? Border.all(color: Colors.white.withOpacity(0.4), width: 1.2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: content,
    );

    final glassWrapped = cfg.glass
        ? ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: card),
          )
        : card;

    Widget body = SlideTransition(
      position: _offset,
      child: ScaleTransition(
        scale: _scale,
        child: FadeTransition(opacity: _fade, child: Material(color: Colors.transparent, child: glassWrapped)),
      ),
    );

    if (cfg.shakeOnEnter) {
      body = AnimatedBuilder(
        animation: _shakeAnim,
        builder: (_, child) => Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
        child: body,
      );
    }

    if (cfg.humanRunner) {
      body = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏃', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Flexible(child: body),
        ],
      );
    }

    return SafeArea(
      child: Align(
        alignment: cfg.alignment,
        child: Padding(padding: const EdgeInsets.all(20), child: body),
      ),
    );
  }
}
