import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/audio/interaction_audio.dart';

class InteractionEffects {
  static Offset? lastTap;
  static Future<void> load() => InteractionAudio.initialize();
  static bool animate(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context);
  static void pulse() {
    HapticFeedback.selectionClick().catchError((_) {});
    unawaited(InteractionAudio.tap());
  }
}

/// One accepted press, one subtle pulse. Async actions show busy state and
/// reject duplicate presses; scrolling cards activate only after a real tap.
class FeedbackTap extends StatefulWidget {
  const FeedbackTap(
      {super.key,
      required this.onTap,
      required this.child,
      this.immediate = false,
      this.borderRadius,
      this.customBorder});
  final FutureOr<void> Function()? onTap;
  final Widget child;
  final bool immediate;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  @override
  State<FeedbackTap> createState() => _FeedbackTapState();
}

class _FeedbackTapState extends State<FeedbackTap> {
  Timer? _release;
  bool _pressed = false;
  bool _busy = false;
  int? _pointer;
  Future<void> _activate() async {
    if (_busy || widget.onTap == null) return;
    InteractionEffects.pulse();
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      InteractionEffects.lastTap =
          box.localToGlobal(box.size.center(Offset.zero));
    }
    setState(() => _pressed = true);
    _release?.cancel();
    _release = Timer(const Duration(milliseconds: 130), () {
      if (mounted) setState(() => _pressed = false);
    });
    try {
      final result = widget.onTap!();
      if (result is Future) {
        if (mounted) setState(() => _busy = true);
        await result;
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _release?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null && !_busy;
    final visual = AnimatedScale(
      scale: _pressed && InteractionEffects.animate(context) ? .96 : 1,
      duration: const Duration(milliseconds: 90),
      child: Stack(alignment: Alignment.center, children: [
        Opacity(opacity: _busy ? .45 : 1, child: widget.child),
        if (_busy)
          const Positioned.fill(
              child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2)))),
      ]),
    );
    if (!widget.immediate) {
      return InkWell(
        borderRadius: widget.borderRadius,
        customBorder: widget.customBorder,
        enableFeedback: false,
        onTap: active ? _activate : null,
        onHighlightChanged: (value) {
          if (mounted) setState(() => _pressed = value);
        },
        child: visual,
      );
    }
    return Semantics(
        button: true,
        enabled: active,
        onTap: active ? _activate : null,
        child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: active
                ? (event) {
                    if (_pointer != null) return;
                    _pointer = event.pointer;
                    _activate();
                  }
                : null,
            onPointerUp: (event) {
              if (_pointer == event.pointer) _pointer = null;
            },
            onPointerCancel: (event) {
              if (_pointer == event.pointer) _pointer = null;
            },
            child: visual));
  }
}

class RewardStars extends StatelessWidget {
  const RewardStars({super.key, required this.count});
  final int count;
  static final destination = GlobalKey();
  static void fly(BuildContext context) {
    if (!InteractionEffects.animate(context)) return;
    final target = destination.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context);
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    if (target == null || overlay == null || overlayBox == null) return;
    final end = overlayBox
        .globalToLocal(target.localToGlobal(target.size.center(Offset.zero)));
    final start = overlayBox.globalToLocal(
        InteractionEffects.lastTap ?? target.localToGlobal(Offset.zero));
    late OverlayEntry entry;
    entry = OverlayEntry(
        builder: (_) => IgnorePointer(
                child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 650),
              onEnd: () => entry.remove(),
              builder: (_, t, __) => Stack(children: [
                Positioned(
                    left: start.dx + (end.dx - start.dx) * t - 15,
                    top: start.dy +
                        (end.dy - start.dy) * t -
                        15 -
                        60 * 4 * t * (1 - t),
                    child: const Icon(Icons.star_rounded,
                        color: Color(0xFFFFB623), size: 30))
              ]),
            )));
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) =>
      Row(key: destination, mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_rounded, color: Color(0xFFFFB623), size: 24),
        const SizedBox(width: 4),
        Text('$count', style: const TextStyle(fontWeight: FontWeight.w800)),
      ]);
}
